#!/usr/bin/env bash
# =============================================================================
# start-gateways.sh — Hermes Agent startup: seed defaults, gateway(s), dashboard
#
# Runs as 'hermes' user (uid 10000, pre-exists in base image).
# tini (PID 1) handles signal forwarding and zombie reaping.
#
# Behaviour:
#   1. Seeds /opt/data (and per-profile dirs) from /opt/hermes/defaults/ on
#      first run — copies only files that do not already exist, never overwrites.
#   2. Default gateway always starts on port 12330 — used by cron scheduler,
#      async tasks, and Nous portal tool.
#   3. Named profiles (HERMES_AGENT_PROFILES) start alongside the default gateway
#      on ports starting at 12335. Ports are auto-assigned to avoid collisions
#      (e.g. from cloned profiles). Duplicates and 12330 conflicts are resolved.
#   4. Dashboard starts on HERMES_DASHBOARD_PORT (default 12329).
#
# Env vars:
#   HERMES_AGENT_PROFILES  space-separated profile names  (default: empty)
#   HERMES_DASHBOARD_PORT   dashboard listen port          (default: 12329)
#   HERMES_WORKSPACE_PORT   workspace listen port          (default: 12328)
#   GATEWAY_HEALTH_URL      override health check URL      (default: http://localhost:12330)
#   BASE_GATEWAY_PORT       first port for named profiles   (default: 12335)
# =============================================================================
set -euo pipefail

# Force a UTF-8 locale so sed preserves multi-byte chars (em-dashes etc.) in
# seeded comment lines. Without this, container shells with LANG=C or POSIX
# corrupt UTF-8 bytes when substitute_placeholders rewrites files in place.
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-C.UTF-8}"

# ---------------------------------------------------------------------------
# Drop to hermes user (uid 10000) if we're running as root.
# The official base image uses gosu for this — we need it here because tini
# starts as PID 1 as root, so all our child processes inherit root.
# Gateway refuses to run as root (security check), while dashboard is fine.
# ---------------------------------------------------------------------------
drop_privileges() {
    if [[ "$(id -u)" == "0" ]]; then
        echo "[hermes] Dropping root privileges (hermes user)"
        exec gosu hermes "$0" "$@"
        exit 1  # should never reach here
    fi
}
drop_privileges

DATA_DIR="/opt/data"
DEFAULTS_DIR="/opt/hermes/defaults"
HERMES_BIN="hermes"
DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-12329}"
WORKSPACE_PORT="${HERMES_WORKSPACE_PORT:-12328}"

GATEWAY_PIDS=()
WORKSPACE_PID=""

# ---------------------------------------------------------------------------
# seed_defaults <target-dir>
# Copies every file from DEFAULTS_DIR into target-dir, skipping any file that
# already exists. Creates target-dir if needed.
# Special case: env.example is copied as .env (kept as env.example in the
# repo so it is not gitignored, renamed here for Hermes to pick up).
# Placeholder substitution (<your-...> tokens) is handled separately by
# substitute_placeholders so that multi-byte UTF-8 characters (e.g. em-dashes)
# are never corrupted by locale-sensitive tools like envsubst.
# ---------------------------------------------------------------------------
seed_defaults() {
    local target="$1"
    mkdir -p "${target}"
    for src in "${DEFAULTS_DIR}"/{*,.*}; do
        # Skip shell glob non-matches and . / .. entries
        [[ -e "${src}" ]] || continue
        local fname
        fname="$(basename "${src}")"
        [[ "${fname}" == "." || "${fname}" == ".." ]] && continue
        # env.example → .env
        local dest_fname="${fname}"
        [[ "${fname}" == "env.example" ]] && dest_fname=".env"
        local dest="${target}/${dest_fname}"
        if [[ ! -e "${dest}" ]]; then
            cp "${src}" "${dest}"
            echo "[hermes] Seeded default: ${dest}"
        fi
    done
}

# ---------------------------------------------------------------------------
# warn_placeholders <env-file>
# Prints a warning if the .env file still contains unfilled <...> placeholders.
# The gateway will still start — Discord simply won't connect until tokens are set.
# ---------------------------------------------------------------------------
warn_placeholders() {
    local envfile="$1"
    if grep -q '<your-' "${envfile}" 2>/dev/null; then
        echo "[hermes] WARNING: ${envfile} contains unfilled placeholder values."
        echo "[hermes] Edit on the host and restart, or the gateway will not connect"
        echo "[hermes] to Discord/messaging platforms until tokens are filled in."
    fi
}

# ---------------------------------------------------------------------------
# substitute_in_file <placeholder> <value> <file>
# Python-based literal in-place substitution. Used instead of sed so that:
#   1. multi-byte UTF-8 chars (em-dashes etc.) in unrelated comment lines are
#      not corrupted by locale-sensitive byte handling in sed,
#   2. arbitrary characters in the replacement value (slashes, pipes, ampersands,
#      backslashes) cannot break sed delimiter or backreference parsing.
# Mirrors the python3 pattern used in scripts/setup.sh::merge_env.
# ---------------------------------------------------------------------------
substitute_in_file() {
    local placeholder="$1"
    local value="$2"
    local file="$3"
    python3 -c "
import sys
placeholder = sys.argv[1]
value = sys.argv[2]
fname = sys.argv[3]
with open(fname, 'r', encoding='utf-8') as f:
    content = f.read()
with open(fname, 'w', encoding='utf-8') as f:
    f.write(content.replace(placeholder, value))
" "$placeholder" "$value" "$file"
}

# ---------------------------------------------------------------------------
# substitute_placeholders <target-file>
# Replaces <your-litellm-api-base>, <your-litellm-master-key>,
# <your-firecrawl-api-url>, and <your-firecrawl-api-key> in the target file
# with actual environment variable values, but only when the variable is
# non-empty — leaving the placeholder intact otherwise so the user sees a
# clear signal that a value still needs to be filled in.
#
# Env vars consumed (set in compose/agent.yml from the root .env):
#   LITELLM_API_URL   ← LITEM_API_URL  (LiteLLM proxy base URL)
#   LITELLM_API_KEY    ← LITEM_API_KEY   (LiteLLM master key)
#   FIRECRAWL_API_URL  ← FCRW_API_URL    (FastCRW base URL)
#   FIRECRAWL_API_KEY  ← LITEM_API_KEY   (FastCRW auth, same key)
# ---------------------------------------------------------------------------
substitute_placeholders() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        return
    fi

    # LITELLM_API_URL for custom_providers[0].base_url and model.base_url
    if grep -q '<your-litellm-api-base>' "${file}" 2>/dev/null; then
        local litellm_base="${LITELLM_API_URL:-}"
        if [[ -n "${litellm_base}" ]]; then
            substitute_in_file "<your-litellm-api-base>" "${litellm_base}" "${file}"
            echo "[hermes] Substituted LITELLM_API_URL in ${file}"
        fi
    fi

    # LITELLM_API_KEY for custom_providers[0].api_key and model.api_key
    if grep -q '<your-litellm-master-key>' "${file}" 2>/dev/null; then
        local litellm_key="${LITELLM_API_KEY:-}"
        if [[ -n "${litellm_key}" ]]; then
            substitute_in_file "<your-litellm-master-key>" "${litellm_key}" "${file}"
            echo "[hermes] Substituted LITELLM_API_KEY in ${file}"
        fi
    fi

    # FIRECRAWL_API_URL for web.base_url
    if grep -q '<your-firecrawl-api-url>' "${file}" 2>/dev/null; then
        local firecrawl_url="${FIRECRAWL_API_URL:-}"
        if [[ -n "${firecrawl_url}" ]]; then
            substitute_in_file "<your-firecrawl-api-url>" "${firecrawl_url}" "${file}"
            echo "[hermes] Substituted FIRECRAWL_API_URL in ${file}"
        fi
    fi

    # FIRECRAWL_API_KEY for web.api_key and browser.cdp_url token
    if grep -q '<your-firecrawl-api-key>' "${file}" 2>/dev/null; then
        local firecrawl_key="${FIRECRAWL_API_KEY:-}"
        if [[ -n "${firecrawl_key}" ]]; then
            substitute_in_file "<your-firecrawl-api-key>" "${firecrawl_key}" "${file}"
            echo "[hermes] Substituted FIRECRAWL_API_KEY in ${file}"
        fi
    fi

}

# ---------------------------------------------------------------------------
# Seed the default data directory and warn about placeholders
# This always runs, even when HERMES_AGENT_PROFILES is empty.
# ---------------------------------------------------------------------------
seed_defaults "${DATA_DIR}"
warn_placeholders "${DATA_DIR}/.env"
substitute_placeholders "${DATA_DIR}/.env"
substitute_placeholders "${DATA_DIR}/config.yaml"

# ---------------------------------------------------------------------------
# Overlay — replay persisted /opt/hermes edits from /opt/data/overlay/
# Must run BEFORE any hermes process starts. Aborts on patch conflicts so
# we never launch in a half-patched state.
# ---------------------------------------------------------------------------
/usr/local/bin/apply-overlay.sh

# Activate hermes venv so yaml module is available for config patching
if [[ -f /opt/hermes/.venv/bin/activate ]]; then
    source /opt/hermes/.venv/bin/activate
fi
HERMES_PYTHON="${HERMES_PYTHON:-/opt/hermes/.venv/bin/python3}"
export VIRTUAL_ENV="${VIRTUAL_ENV:-/opt/hermes/.venv}"
export PATH="/opt/hermes/.venv/bin:$PATH"

# ---------------------------------------------------------------------------
# Per-profile gateway — hermes -p <name> gateway
# Ports are assigned sequentially from BASE_GATEWAY_PORT so that multiple
# profiles in the same container never collide on api_server.port.
# Detects and corrects ports already in use (e.g. after a profile clone).
# ---------------------------------------------------------------------------
BASE_GATEWAY_PORT="${BASE_GATEWAY_PORT:-12335}"

find_free_port() {
    local used_ports_json
    used_ports_json=$(scan_profile_ports)
    local port="${BASE_GATEWAY_PORT}"
    while printf '%s\n' "${used_ports_json}" | grep -qx "${port}"; do
        port=$((port + 1))
    done
    echo "${port}"
}

_assign_unique_port() {
    local profile_dir="$1"
    local assigned_port="$2"
    # yaml module is in hermes venv — use the venv python
    "${HERMES_PYTHON}" - "$profile_dir/config.yaml" "$assigned_port" <<'PYEOF'
import sys, yaml, pathlib
fname, new_port = sys.argv[1], int(sys.argv[2])
with open(fname) as f:
    cfg = yaml.safe_load(f)
cfg.setdefault('api_server', {})['port'] = new_port
with open(fname, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False)
PYEOF
}

# ---------------------------------------------------------------------------
# scan_profile_ports
# Reads all profile config.yaml files and the default config to collect ports
# already in use. Returns a newline-separated list of used ports on stdout.
# ---------------------------------------------------------------------------
scan_profile_ports() {
    local used_ports=()

    # Always include default gateway port
    used_ports+=("12330")

    # Scan each named profile's config.yaml
    if [[ -d "${DATA_DIR}/profiles" ]]; then
        for cfg in "${DATA_DIR}/profiles"/*/config.yaml; do
            [[ -f "${cfg}" ]] || continue
            local port
            port=$("${HERMES_PYTHON}" - "$cfg" <<'PYEOF'
import sys, yaml
with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)
port = cfg.get('api_server', {}).get('port', '')
print(port if port else '')
PYEOF
)
            port="${port// /}"
            [[ -n "${port}" ]] && used_ports+=("${port}")
        done
    fi

    printf '%s\n' "${used_ports[@]}"
}

start_profile_gateway() {
    local profile="$1"
    local profile_dir="${DATA_DIR}/profiles/${profile}"
    local assigned_port
    assigned_port=$(find_free_port)

    seed_defaults "${profile_dir}"
    warn_placeholders "${profile_dir}/.env"
    substitute_placeholders "${profile_dir}/.env"
    substitute_placeholders "${profile_dir}/config.yaml"

    # Read current port from config.yaml (may have been set by clone/clone-profile)
    local current_port
    current_port=$("${HERMES_PYTHON}" - "$profile_dir/config.yaml" <<'PYEOF'
import sys, yaml
fname = sys.argv[1]
try:
    with open(fname) as f:
        cfg = yaml.safe_load(f)
    print(str(cfg.get('api_server', {}).get('port', '')))
except Exception:
    print('')
PYEOF
)
    current_port="${current_port// /}"

    # Skip if port already matches what we'd assign (no duplicate check needed)
    # Reassign if port is the default (12330, conflicts with default gateway) or
    # if port is already used by another profile
    local needs_assign=false
    if [[ -z "${current_port}" ]]; then
        needs_assign=true
    elif [[ "${current_port}" == "12330" ]]; then
        needs_assign=true
        echo "[hermes] Profile '${profile}' uses default-gateway port 12330 — reassigning"
    elif printf '%s\n' "$(scan_profile_ports)" | grep -qx "${current_port}"; then
        needs_assign=true
        echo "[hermes] Profile '${profile}' port ${current_port} is already in use — reassigning"
    fi

    if [[ "${needs_assign}" == true ]]; then
        _assign_unique_port "$profile_dir" "$assigned_port"
        echo "[hermes] Assigned api_server.port=${assigned_port} to profile '${profile}'"
    fi

    echo "[hermes] Starting gateway for profile '${profile}' on port ${assigned_port}"
    # Set API_SERVER_PORT to match the per-profile port that start-gateways.sh
    # assigned via _assign_unique_port. Without this, the container-level env var
    # (12330) would override the config.yaml port for each profile.
    API_SERVER_PORT="${assigned_port}" ${HERMES_BIN} -p "${profile}" gateway &
    GATEWAY_PIDS+=($!)
}

# ---------------------------------------------------------------------------
# Default gateway (no profile, uses /opt/data directly)
# ---------------------------------------------------------------------------
start_default_gateway() {
    echo "[hermes] Starting default gateway"
    # API_SERVER_PORT is intentionally kept as-is (12330) for the default profile
    ${HERMES_BIN} gateway &
    GATEWAY_PIDS+=($!)
}

# ---------------------------------------------------------------------------
# Launch gateway(s)
# ---------------------------------------------------------------------------
# Default gateway always runs — needed for cron scheduler, async tasks,
# and Nous portal tool even when named profiles are configured.
start_default_gateway

if [[ -n "${HERMES_AGENT_PROFILES:-}" ]]; then
    for profile in ${HERMES_AGENT_PROFILES}; do
        start_profile_gateway "${profile}"
    done
fi

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
HEALTH_URL="${GATEWAY_HEALTH_URL:-http://localhost:12330}"
echo "[hermes] Starting dashboard on port ${DASHBOARD_PORT} (health → ${HEALTH_URL})"
GATEWAY_HEALTH_URL="${HEALTH_URL}" \
    ${HERMES_BIN} dashboard --host 0.0.0.0 --port "${DASHBOARD_PORT}" --insecure &
DASHBOARD_PID=$!

# ---------------------------------------------------------------------------
# Hermes Workspace (web UI)
# ---------------------------------------------------------------------------
WORKSPACE_DIR="/opt/lib/workspace"

start_workspace() {
    local port="$1"

    if [[ ! -f "${WORKSPACE_DIR}/server-entry.js" ]]; then
        echo "[hermes] Workspace not bundled — skipping"
        return
    fi

    echo "[hermes] Starting Hermes Workspace on port ${port}"
    cd "${WORKSPACE_DIR}"

    # Workspace connects to gateway (12330) and dashboard (12329) on localhost.
    # HERMES_WORKSPACE_PASSWORD is passed from compose (sourced from HERMES_SPACE_PASSWD).
    # Fallback to API_SERVER_KEY if not set (for migration from older configs).
    local ws_password="${HERMES_WORKSPACE_PASSWORD:-${API_SERVER_KEY:-}}"
    if [[ -z "${ws_password}" ]]; then
        echo "[hermes] ERROR: HERMES_WORKSPACE_PASSWORD not set. Workspace requires auth."
        return 1
    fi

    HERMES_API_URL="http://localhost:12330" \
    HERMES_DASHBOARD_URL="http://localhost:12329" \
    HERMES_API_TOKEN="${API_SERVER_KEY:-}" \
    HERMES_PASSWORD="${ws_password}" \
    PORT="${port}" \
    HOST="0.0.0.0" \
    COOKIE_SECURE=0 \
    node --max-old-space-size=2048 server-entry.js &
    WORKSPACE_PID=$!
}

start_workspace "${WORKSPACE_PORT}"

# ---------------------------------------------------------------------------
# Shutdown handler
# ---------------------------------------------------------------------------
shutdown() {
    echo "[hermes] Shutting down..."
    kill "${WORKSPACE_PID}" 2>/dev/null || true
    kill "${DASHBOARD_PID}" 2>/dev/null || true
    for pid in "${GATEWAY_PIDS[@]}"; do kill "${pid}" 2>/dev/null || true; done
    wait
    exit 0
}
trap shutdown SIGTERM SIGINT

wait
