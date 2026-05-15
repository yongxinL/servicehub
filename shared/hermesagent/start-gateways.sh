#!/usr/bin/env bash
# =============================================================================
# start-gateways.sh — Hermes Agent startup: seed defaults, gateway(s), dashboard
#
# Runs as 'hermes' user (uid 10000, pre-exists in base image).
# tini (PID 1) handles signal forwarding and zombie reaping.
#
# Behaviour:
#   1. Seeds /opt/data (and per-profile dirs) from /opt/hermes-defaults/ on
#      first run — copies only files that do not already exist, never overwrites.
#   2. HERMES_PROFILES empty  → single default gateway  (hermes gateway)
#      HERMES_PROFILES set    → one gateway per named profile (hermes -p <name> gateway)
#      Port per profile is set via api_server.port in each profile's config.yaml.
#   3. Dashboard starts on HERMES_DASHBOARD_PORT (default 12329).
#
# Env vars:
#   HERMES_PROFILES         space-separated profile names  (default: empty)
#   HERMES_DASHBOARD_PORT   dashboard listen port          (default: 12329)
#   GATEWAY_HEALTH_URL      override health check URL      (default: http://localhost:8642)
# =============================================================================
set -euo pipefail

DATA_DIR="/opt/data"
DEFAULTS_DIR="/opt/hermes-defaults"
HERMES_BIN="hermes"
DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-12329}"

GATEWAY_PIDS=()

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
            sed -i "s|<your-litellm-api-base>|${litellm_base}|g" "${file}"
            echo "[hermes] Substituted LITELLM_API_URL in ${file}"
        fi
    fi

    # LITELLM_API_KEY for custom_providers[0].api_key and model.api_key
    if grep -q '<your-litellm-master-key>' "${file}" 2>/dev/null; then
        local litellm_key="${LITELLM_API_KEY:-}"
        if [[ -n "${litellm_key}" ]]; then
            sed -i "s|<your-litellm-master-key>|${litellm_key}|g" "${file}"
            echo "[hermes] Substituted LITELLM_API_KEY in ${file}"
        fi
    fi

    # FIRECRAWL_API_URL for web.base_url
    if grep -q '<your-firecrawl-api-url>' "${file}" 2>/dev/null; then
        local firecrawl_url="${FIRECRAWL_API_URL:-}"
        if [[ -n "${firecrawl_url}" ]]; then
            sed -i "s|<your-firecrawl-api-url>|${firecrawl_url}|g" "${file}"
            echo "[hermes] Substituted FIRECRAWL_API_URL in ${file}"
        fi
    fi

    # FIRECRAWL_API_KEY for web.api_key and browser.cdp_url token
    if grep -q '<your-firecrawl-api-key>' "${file}" 2>/dev/null; then
        local firecrawl_key="${FIRECRAWL_API_KEY:-}"
        if [[ -n "${firecrawl_key}" ]]; then
            sed -i "s|<your-firecrawl-api-key>|${firecrawl_key}|g" "${file}"
            echo "[hermes] Substituted FIRECRAWL_API_KEY in ${file}"
        fi
    fi

}

# ---------------------------------------------------------------------------
# Seed the default data directory and warn about placeholders
# This always runs, even when HERMES_PROFILES is empty.
# ---------------------------------------------------------------------------
seed_defaults "${DATA_DIR}"
warn_placeholders "${DATA_DIR}/.env"
substitute_placeholders "${DATA_DIR}/.env"
substitute_placeholders "${DATA_DIR}/config.yaml"

# ---------------------------------------------------------------------------
# Per-profile gateway — hermes -p <name> gateway
# ---------------------------------------------------------------------------
start_profile_gateway() {
    local profile="$1"
    local profile_dir="${DATA_DIR}/profiles/${profile}"
    seed_defaults "${profile_dir}"
    warn_placeholders "${profile_dir}/.env"
    substitute_placeholders "${profile_dir}/.env"
    substitute_placeholders "${profile_dir}/config.yaml"
    echo "[hermes] Starting gateway for profile '${profile}'"
    ${HERMES_BIN} -p "${profile}" gateway &
    GATEWAY_PIDS+=($!)
}

# ---------------------------------------------------------------------------
# Default gateway (no profile, uses /opt/data directly)
# ---------------------------------------------------------------------------
start_default_gateway() {
    echo "[hermes] Starting default gateway"
    ${HERMES_BIN} gateway &
    GATEWAY_PIDS+=($!)
}

# ---------------------------------------------------------------------------
# Launch gateway(s)
# ---------------------------------------------------------------------------
if [[ -n "${HERMES_PROFILES:-}" ]]; then
    for profile in ${HERMES_PROFILES}; do
        start_profile_gateway "${profile}"
    done
fi

if [[ ${#GATEWAY_PIDS[@]} -eq 0 ]]; then
    start_default_gateway
fi

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------
HEALTH_URL="${GATEWAY_HEALTH_URL:-http://localhost:8642}"
echo "[hermes] Starting dashboard on port ${DASHBOARD_PORT} (health → ${HEALTH_URL})"
GATEWAY_HEALTH_URL="${HEALTH_URL}" \
    ${HERMES_BIN} dashboard --host 0.0.0.0 --port "${DASHBOARD_PORT}" --insecure &
DASHBOARD_PID=$!

# ---------------------------------------------------------------------------
# Shutdown handler
# ---------------------------------------------------------------------------
shutdown() {
    echo "[hermes] Shutting down..."
    kill "${DASHBOARD_PID}" 2>/dev/null || true
    for pid in "${GATEWAY_PIDS[@]}"; do kill "${pid}" 2>/dev/null || true; done
    wait
    exit 0
}
trap shutdown SIGTERM SIGINT

wait
