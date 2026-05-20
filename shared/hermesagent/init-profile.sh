#!/usr/bin/env bash
# =============================================================================
# init-profile.sh — Create internal user profiles within a Hermes container
#
# This script creates INTERNAL profiles (code, research, etc.) that live
# inside a container's /opt/data/profiles/ directory. These are NOT messaging
# platform profiles — they're for organizing different agent personas.
#
# Host mode (on Docker host):
#   ./shared/hermesagent/init-profile.sh <profile-name>
#
# Container mode (inside a hermes container):
#   docker compose exec agsvcherme00 init-profile.sh <profile-name>
#
# What it does:
#   1. Seeds config.yaml, SOUL.md, and env.example → .env from the defaults
#      directory, skipping files that already exist (use --force to overwrite)
#   2. Substitutes <your-litellm-api-base>, <your-litellm-master-key>,
#      <your-firecrawl-api-url>, and <your-firecrawl-api-key> with real values
#
# Options:
#   --force   Overwrite existing profile files
# =============================================================================
set -euo pipefail

# Force a UTF-8 locale so sed/grep preserve multi-byte chars (em-dashes etc.)
# in seeded comment lines.
export LC_ALL="${LC_ALL:-C.UTF-8}"
export LANG="${LANG:-C.UTF-8}"

# ── Detect execution context ──────────────────────────────────────────────────
# /opt/hermes/defaults is baked into the image by the Dockerfile, so its
# presence is a reliable container-mode signal.
if [[ -d /opt/hermes/defaults ]]; then
    CONTEXT="container"
    DEFAULTS_DIR="/opt/hermes/defaults"
    DATA_ROOT="/opt/data"
    ENV_FILE=""
else
    CONTEXT="host"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    DEFAULTS_DIR="${SCRIPT_DIR}/default"
    DATA_ROOT=""
    ENV_FILE="${PROJECT_ROOT}/.env"
fi

# ── Python-based literal substitution ─────────────────────────────────────────
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

# ── Argument parsing ──────────────────────────────────────────────────────────
PROFILE_NAME=""
OPT_FORCE=false

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   OPT_FORCE=true; shift ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *)  PROFILE_NAME="$1"; shift ;;
    esac
done

if [[ -z "${PROFILE_NAME}" ]]; then
    echo "Error: profile name is required."
    echo "Usage: $0 <profile-name> [OPTIONS]"
    exit 1
fi

# Validate profile name (alphanumeric + hyphen/underscore only)
if ! [[ "${PROFILE_NAME}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: profile name '${PROFILE_NAME}' is invalid. Use only letters, numbers, hyphens, and underscores."
    exit 1
fi

# ── Resolve config values ─────────────────────────────────────────────────────
read_env_file() {
    local key="$1"
    [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]] || { echo ""; return; }
    grep -E "^${key}=" "${ENV_FILE}" 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^['\"]//;s/['\"]$//"
}

LITELLM_API_KEY="${LITELLM_API_KEY:-$(read_env_file LITEM_API_KEY)}"
LITELLM_API_URL="${LITELLM_API_URL:-$(read_env_file LITEM_API_URL)}"
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-$(read_env_file FCRW_API_URL)}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-${LITELLM_API_KEY}}"

LITELLM_API_URL="${LITELLM_API_URL:-http://agsvclitellm:12380/v1}"
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-http://agsvcfastcrw:12360}"

if [[ -z "${LITELLM_API_KEY}" || "${LITELLM_API_KEY}" == *"YOUR_"* || "${LITELLM_API_KEY}" == *"your-"* ]]; then
    echo "Error: LiteLLM master key is not set or still a placeholder."
    exit 1
fi

# ── Resolve profile directory ──────────────────────────────────────────────────
if [[ "${CONTEXT}" == "container" ]]; then
    PROFILE_DIR="${DATA_ROOT}/profiles/${PROFILE_NAME}"
else
    APPS_DATA_RAW="$(read_env_file APPS_DATA)"
    APPS_DATA="${APPS_DATA_RAW/#\~/${HOME}}"
    if [[ -z "${APPS_DATA}" ]]; then
        echo "Error: APPS_DATA is not set in ${ENV_FILE} (required for host execution)."
        exit 1
    fi
    # In multi-container setup, profiles go under the container's data dir
    # Use HERMES_DATA_00 or default path
    HERMES_DATA_0X="$(read_env_file HERMES_DATA_00)"
    if [[ -n "${HERMES_DATA_0X}" ]]; then
        PROFILE_DIR="${HERMES_DATA_0X}/profiles/${PROFILE_NAME}"
    else
        PROFILE_DIR="${APPS_DATA}/hermesagent/data/00/profiles/${PROFILE_NAME}"
    fi
fi
mkdir -p "${PROFILE_DIR}"

echo ""
echo "[init-profile] Context   : ${CONTEXT}"
echo "[init-profile] Profile   : ${PROFILE_NAME}"
echo "[init-profile] Directory: ${PROFILE_DIR}"
echo ""

# ── Seed default files ────────────────────────────────────────────────────────
seed_file() {
    local src="$1"
    local dest="$2"
    if [[ -e "${dest}" && "${OPT_FORCE}" == false ]]; then
        echo "[init-profile] SKIP (exists, use --force to overwrite): $(basename "${dest}")"
        return
    fi
    cp "${src}" "${dest}"
    echo "[init-profile] Seeded: $(basename "${dest}")"
}

seed_file "${DEFAULTS_DIR}/config.yaml"  "${PROFILE_DIR}/config.yaml"
seed_file "${DEFAULTS_DIR}/env.example"  "${PROFILE_DIR}/.env"
seed_file "${DEFAULTS_DIR}/SOUL.md"       "${PROFILE_DIR}/SOUL.md"

# ── Substitute API key + base URL placeholders ────────────────────────────────
for f in "${PROFILE_DIR}/config.yaml" "${PROFILE_DIR}/.env"; do
    [[ -f "${f}" ]] || continue
    substitute_in_file "<your-litellm-api-base>"   "${LITELLM_API_URL}"   "${f}"
    substitute_in_file "<your-litellm-master-key>" "${LITELLM_API_KEY}"   "${f}"
    substitute_in_file "<your-firecrawl-api-url>"  "${FIRECRAWL_API_URL}"  "${f}"
    substitute_in_file "<your-firecrawl-api-key>"  "${FIRECRAWL_API_KEY}"  "${f}"
done
echo "[init-profile] Substituted LiteLLM + FastCRW base URLs and API keys"

# ── Next steps ────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────"
echo " Internal profile '${PROFILE_NAME}' created at:"
echo "   ${PROFILE_DIR}/"
echo ""
echo " Files:"
for f in config.yaml .env SOUL.md; do
    [[ -f "${PROFILE_DIR}/${f}" ]] && echo "   ✓ ${f}" || echo "   ✗ ${f} (missing)"
done
echo ""
echo " Next steps:"
step=1
echo "  ${step}. Personalise SOUL.md for this profile's identity:"
echo "     nano ${PROFILE_DIR}/SOUL.md"
step=$((step+1))
echo "  ${step}. Switch to this profile in the Workspace UI or CLI:"
echo "     docker compose exec agsvcherme00 hermes profile use ${PROFILE_NAME}"
step=$((step+1))
echo "  ${step}. List all profiles:"
echo "     docker compose exec agsvcherme00 hermes profile list"
echo "────────────────────────────────────────────────────────────"
echo ""