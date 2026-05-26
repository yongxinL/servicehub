#!/usr/bin/env bash
# =============================================================================
# start-gateways.sh — Hermes Agent startup: seed defaults, gateway, workspace, dashboard
#
# Runs as 'hermes' user (uid 10000, pre-exists in base image).
# tini (PID 1) handles signal forwarding and zombie reaping.
#
# Behaviour:
#   1. Seeds /opt/data from /opt/hermes/defaults/ on first run — copies only
#      files that do not already exist, never overwrites.
#   2. Gateway starts on port 12330 (container-internal).
#   3. Hermes Workspace starts on HERMES_WORKSPACE_PORT (default 12320).
#   4. Hermes Dashboard starts on HERMES_DASHBOARD_PORT (default 9119)
#      providing the enhancement API and web interface.
#
# Env vars:
#   HERMES_WORKSPACE_PORT   workspace listen port       (default: 12320)
#   HERMES_WORKSPACE_PASSWORD workspace login password (required)
#   HERMES_DASHBOARD_PORT   dashboard listen port      (default: 9119)
#
# Internal user profiles (code, research, etc.) are available via:
#   hermes profile create <name>
# These are separate from messaging platform profiles.
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
# Gateway refuses to run as root (security check).
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
WORKSPACE_PORT="${HERMES_WORKSPACE_PORT:-12320}"

WORKSPACE_PID=""
GATEWAY_PID=""
DASHBOARD_PID=""

# ---------------------------------------------------------------------------
# seed_defaults <target-dir>
# Copies every file from DEFAULTS_DIR into target-dir, skipping any file that
# already exists. Creates target-dir if needed.
# Special case: env.example is copied as .env (kept as env.example in the
# repo so it is not gitignored, renamed here for Hermes to pick up).
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
# The gateway will still start — but some features may be unavailable.
# ---------------------------------------------------------------------------
warn_placeholders() {
    local envfile="$1"
    if grep -q '<your-' "${envfile}" 2>/dev/null; then
        echo "[hermes] WARNING: ${envfile} contains unfilled placeholder values."
        echo "[hermes] Edit on the host and restart for full functionality."
    fi
}

# ---------------------------------------------------------------------------
# substitute_in_file <placeholder> <value> <file>
# Python-based literal in-place substitution. Used instead of sed so that:
#   1. multi-byte UTF-8 chars (em-dashes etc.) in unrelated comment lines are
#      not corrupted by locale-sensitive byte handling in sed,
#   2. arbitrary characters in the replacement value (slashes, pipes, ampersands,
#      backslashes) cannot break sed delimiter or backreference parsing.
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
# ---------------------------------------------------------------------------
substitute_placeholders() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        return
    fi

    if grep -q '<your-litellm-api-base>' "${file}" 2>/dev/null; then
        local litellm_base="${LITELLM_API_URL:-}"
        if [[ -n "${litellm_base}" ]]; then
            substitute_in_file "<your-litellm-api-base>" "${litellm_base}" "${file}"
            echo "[hermes] Substituted LITELLM_API_URL in ${file}"
        fi
    fi

    if grep -q '<your-litellm-master-key>' "${file}" 2>/dev/null; then
        local litellm_key="${LITELLM_API_KEY:-}"
        if [[ -n "${litellm_key}" ]]; then
            substitute_in_file "<your-litellm-master-key>" "${litellm_key}" "${file}"
            echo "[hermes] Substituted LITELLM_API_KEY in ${file}"
        fi
    fi

    if grep -q '<your-firecrawl-api-url>' "${file}" 2>/dev/null; then
        local firecrawl_url="${FIRECRAWL_API_URL:-}"
        if [[ -n "${firecrawl_url}" ]]; then
            substitute_in_file "<your-firecrawl-api-url>" "${firecrawl_url}" "${file}"
            echo "[hermes] Substituted FIRECRAWL_API_URL in ${file}"
        fi
    fi

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
# ---------------------------------------------------------------------------
seed_defaults "${DATA_DIR}"
warn_placeholders "${DATA_DIR}/.env"
substitute_placeholders "${DATA_DIR}/.env"
substitute_placeholders "${DATA_DIR}/config.yaml"

# ---------------------------------------------------------------------------
# Overlay — replay persisted /opt/hermes edits from /opt/data/overlay/
# Must run BEFORE any hermes process starts.
# ---------------------------------------------------------------------------
/usr/local/bin/apply-overlay.sh

# ---------------------------------------------------------------------------
# Gateway — single gateway per container on port 12330
# ---------------------------------------------------------------------------
echo "[hermes] Starting gateway on port 12330"
${HERMES_BIN} gateway &
GATEWAY_PID=$!

# ---------------------------------------------------------------------------
# Hermes Workspace (web UI)
# ---------------------------------------------------------------------------
WORKSPACE_DIR="/opt/lib/workspace"

if [[ ! -f "${WORKSPACE_DIR}/server-entry.js" ]]; then
    echo "[hermes] Workspace not bundled — skipping"
else
    ws_password="${HERMES_WORKSPACE_PASSWORD:-}"
    if [[ -z "${ws_password}" ]]; then
        echo "[hermes] ERROR: HERMES_WORKSPACE_PASSWORD not set. Workspace requires auth."
    else
        echo "[hermes] Starting Hermes Workspace on port ${WORKSPACE_PORT}"
        cd "${WORKSPACE_DIR}"

        HERMES_API_URL="http://localhost:12330" \
        HERMES_API_TOKEN="${API_SERVER_KEY:-}" \
        HERMES_PASSWORD="${ws_password}" \
        PORT="${WORKSPACE_PORT}" \
        HOST="0.0.0.0" \
        COOKIE_SECURE=0 \
        node --max-old-space-size=2048 server-entry.js &
        WORKSPACE_PID=$!
    fi
fi

# ---------------------------------------------------------------------------
# Hermes Dashboard — FastAPI server providing the enhancement API and web UI
# ---------------------------------------------------------------------------
DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9119}"

if command -v hermes &>/dev/null; then
    echo "[hermes] Starting Hermes Dashboard on port ${DASHBOARD_PORT}"
    hermes dashboard &
    DASHBOARD_PID=$!
else
    echo "[hermes] hermes not found in PATH — skipping Dashboard"
    DASHBOARD_PID=""
fi

# ---------------------------------------------------------------------------
# Shutdown handler
# ---------------------------------------------------------------------------
shutdown() {
    echo "[hermes] Shutting down..."
    [[ -n "${WORKSPACE_PID}" ]] && kill "${WORKSPACE_PID}" 2>/dev/null || true
    [[ -n "${GATEWAY_PID}" ]] && kill "${GATEWAY_PID}" 2>/dev/null || true
    [[ -n "${DASHBOARD_PID}" ]] && kill "${DASHBOARD_PID}" 2>/dev/null || true
    wait
    exit 0
}
trap shutdown SIGTERM SIGINT

wait
