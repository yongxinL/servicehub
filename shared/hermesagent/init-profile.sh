#!/usr/bin/env bash
# =============================================================================
# init-profile.sh — Bootstrap a Hermes Agent profile directory
#
# Runs in two modes (auto-detected):
#
#   Host mode — invoked from the ServiceHub project root on the host:
#     ./shared/hermesagent/init-profile.sh <profile-name> [OPTIONS]
#   Reads LITEM_APIKEY, LITEM_APIBASE, FCRW_APIURL, APPS_DATA from the root
#   .env and writes the profile to ${APPS_DATA}/hermesagent/profiles/<name>/.
#
#   Container mode — invoked inside the agsvchermagt container:
#     docker compose exec agsvchermagt init-profile.sh <profile-name> [OPTIONS]
#   Reads LITELLM_API_KEY, LITELLM_API_BASE, FIRECRAWL_API_URL, FIRECRAWL_API_KEY
#   from process env (populated by compose/agent.yml) and writes the profile to
#   /opt/data/profiles/<name>/.
#
# Detection: presence of /opt/hermes-defaults (baked into the image by the
# Dockerfile) marks container mode. Anything else is treated as host mode.
#
# What it does:
#   1. Seeds config.yaml, SOUL.md, and env.example → .env from the defaults
#      directory, skipping files that already exist (use --force to overwrite)
#   2. Substitutes <your-litellm-api-base>, <your-litellm-master-key>,
#      <your-firecrawl-api-url>, and <your-firecrawl-api-key> with real values
#   3. Optionally sets api_server.port, Discord and WhatsApp credentials
#
# Options:
#   --port <n>                api_server.port in config.yaml (e.g. 8643)
#   --discord-token <token>   DISCORD_BOT_TOKEN for this profile's bot
#   --discord-user <id>       DISCORD_ALLOWED_USERS (comma-separated user IDs)
#   --whatsapp-number <n>     WHATSAPP_ALLOWED_USERS (country-code + number, no +)
#                             e.g. 61412123456 for +61 412 123 456
#   --force                   Overwrite existing profile files
#
# Examples:
#   # Host — minimal, fill tokens later
#   ./shared/hermesagent/init-profile.sh alice --port 8643
#
#   # Host — full setup in one command
#   ./shared/hermesagent/init-profile.sh alice \
#     --port 8643 \
#     --discord-token "Bot.Token.Here" \
#     --discord-user "123456789012345678" \
#     --whatsapp-number "61412123456"
#
#   # Container — full setup, same flags
#   docker compose exec agsvchermagt init-profile.sh bob \
#     --port 8644 --discord-token "AnotherBot.Token" \
#     --discord-user "987654321098765432" --whatsapp-number "61487654321"
# =============================================================================
set -euo pipefail

# ── Detect execution context ──────────────────────────────────────────────────
# /opt/hermes-defaults is baked into the image by the Dockerfile, so its
# presence is a reliable container-mode signal.
if [[ -d /opt/hermes-defaults ]]; then
    CONTEXT="container"
    DEFAULTS_DIR="/opt/hermes-defaults"
    DATA_ROOT="/opt/data"
    ENV_FILE=""
else
    CONTEXT="host"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    DEFAULTS_DIR="${SCRIPT_DIR}/default"
    DATA_ROOT=""   # resolved below from APPS_DATA
    ENV_FILE="${PROJECT_ROOT}/.env"
fi

# ── Portable sed -i (BSD/macOS vs GNU/Linux) ──────────────────────────────────
sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ── Argument parsing ──────────────────────────────────────────────────────────
PROFILE_NAME=""
OPT_PORT=""
OPT_DISCORD_TOKEN=""
OPT_DISCORD_USER=""
OPT_WHATSAPP_NUMBER=""
OPT_FORCE=false

usage() {
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)             OPT_PORT="$2";             shift 2 ;;
        --discord-token)    OPT_DISCORD_TOKEN="$2";    shift 2 ;;
        --discord-user)     OPT_DISCORD_USER="$2";     shift 2 ;;
        --whatsapp-number)  OPT_WHATSAPP_NUMBER="$2";  shift 2 ;;
        --force)            OPT_FORCE=true;             shift ;;
        -h|--help)          usage ;;
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
# Precedence: process env (container-side names) → root .env (host-side names)
# → in-stack defaults. read_env_file silently returns "" if the .env file is
# missing, which is the normal case in container mode.
read_env_file() {
    local key="$1"
    [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]] || { echo ""; return; }
    grep -E "^${key}=" "${ENV_FILE}" 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^['\"]//;s/['\"]$//"
}

# Process env wins; root .env supplies upstream (LITEM_*/FCRW_*) names on host.
LITELLM_API_KEY="${LITELLM_API_KEY:-$(read_env_file LITEM_APIKEY)}"
LITELLM_API_BASE="${LITELLM_API_BASE:-$(read_env_file LITEM_APIBASE)}"
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-$(read_env_file FCRW_APIURL)}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-${LITELLM_API_KEY}}"

# In-stack defaults if neither source supplied a value
LITELLM_API_BASE="${LITELLM_API_BASE:-http://agsvclitellm:12380/v1}"
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-http://agsvcfastcrw:12360}"

if [[ -z "${LITELLM_API_KEY}" || "${LITELLM_API_KEY}" == *"YOUR_"* || "${LITELLM_API_KEY}" == *"your-"* ]]; then
    echo "Error: LiteLLM master key is not set or still a placeholder."
    if [[ "${CONTEXT}" == "container" ]]; then
        echo "  Inside container: ensure LITELLM_API_KEY is exported."
        echo "  (compose/agent.yml sets it from LITEM_APIKEY in the root .env.)"
    else
        echo "  On host: set LITEM_APIKEY in ${ENV_FILE}."
        echo "  Generate one with: python3 -c \"import secrets; print(secrets.token_urlsafe(32))\""
    fi
    exit 1
fi

# ── Resolve profile directory ─────────────────────────────────────────────────
if [[ "${CONTEXT}" == "container" ]]; then
    PROFILE_DIR="${DATA_ROOT}/profiles/${PROFILE_NAME}"
else
    APPS_DATA_RAW="$(read_env_file APPS_DATA)"
    APPS_DATA="${APPS_DATA_RAW/#\~/${HOME}}"   # expand leading ~
    if [[ -z "${APPS_DATA}" ]]; then
        echo "Error: APPS_DATA is not set in ${ENV_FILE} (required for host execution)."
        exit 1
    fi
    PROFILE_DIR="${APPS_DATA}/hermesagent/profiles/${PROFILE_NAME}"
fi
mkdir -p "${PROFILE_DIR}"

echo ""
echo "[init-profile] Context   : ${CONTEXT}"
echo "[init-profile] Profile   : ${PROFILE_NAME}"
echo "[init-profile] Directory : ${PROFILE_DIR}"
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
seed_file "${DEFAULTS_DIR}/SOUL.md"      "${PROFILE_DIR}/SOUL.md"

# ── Substitute API key + base URL placeholders ───────────────────────────────
# Mirrors the substitutions performed by start-gateways.sh at container start
# so a profile created via this script is immediately usable without a restart.
for f in "${PROFILE_DIR}/config.yaml" "${PROFILE_DIR}/.env"; do
    [[ -f "${f}" ]] || continue
    sed_inplace "s|<your-litellm-api-base>|${LITELLM_API_BASE}|g"   "${f}"
    sed_inplace "s|<your-litellm-master-key>|${LITELLM_API_KEY}|g"  "${f}"
    sed_inplace "s|<your-firecrawl-api-url>|${FIRECRAWL_API_URL}|g" "${f}"
    sed_inplace "s|<your-firecrawl-api-key>|${FIRECRAWL_API_KEY}|g" "${f}"
done
echo "[init-profile] Substituted LiteLLM + FastCRW base URLs and API keys in config.yaml and .env"

# ── api_server.port ───────────────────────────────────────────────────────────
if [[ -n "${OPT_PORT}" ]]; then
    sed_inplace "s|^  port: [0-9]*|  port: ${OPT_PORT}|" "${PROFILE_DIR}/config.yaml"
    echo "[init-profile] Set api_server.port = ${OPT_PORT}"
fi

# ── discord: block in config.yaml ────────────────────────────────────────────
# Append the discord config block if not already present
if ! grep -q '^discord:' "${PROFILE_DIR}/config.yaml" 2>/dev/null; then
    cat >> "${PROFILE_DIR}/config.yaml" << 'EOF'

# ---------------------------------------------------------------------------
# Discord gateway behaviour
# ---------------------------------------------------------------------------
discord:
  require_mention: true    # require @mention in server channels (DMs always work)
  auto_thread: true        # each conversation gets its own thread
  reactions: true          # add reaction indicators while processing
  allow_mentions:
    everyone: false        # never let the bot ping @everyone
    roles: false           # never let the bot ping @role
    users: true
    replied_user: true
EOF
    echo "[init-profile] Added discord: config block to config.yaml"
fi

# ── Messaging credentials in .env ─────────────────────────────────────────────
ENV_ADDITIONS=""

if [[ -n "${OPT_DISCORD_TOKEN}" || -n "${OPT_DISCORD_USER}" ]]; then
    ENV_ADDITIONS+=$'\n# Discord\n'
    [[ -n "${OPT_DISCORD_TOKEN}" ]] && ENV_ADDITIONS+="DISCORD_BOT_TOKEN=${OPT_DISCORD_TOKEN}"$'\n'
    [[ -n "${OPT_DISCORD_USER}" ]]  && ENV_ADDITIONS+="DISCORD_ALLOWED_USERS=${OPT_DISCORD_USER}"$'\n'
fi

if [[ -n "${OPT_WHATSAPP_NUMBER}" ]]; then
    ENV_ADDITIONS+=$'\n# WhatsApp (bot mode — dedicated number)\n'
    ENV_ADDITIONS+="WHATSAPP_ENABLED=true"$'\n'
    ENV_ADDITIONS+="WHATSAPP_MODE=bot"$'\n'
    ENV_ADDITIONS+="WHATSAPP_ALLOWED_USERS=${OPT_WHATSAPP_NUMBER}"$'\n'
fi

if [[ -n "${ENV_ADDITIONS}" ]]; then
    printf '%s' "${ENV_ADDITIONS}" >> "${PROFILE_DIR}/.env"
    [[ -n "${OPT_DISCORD_TOKEN}" ]]    && echo "[init-profile] Added DISCORD_BOT_TOKEN"
    [[ -n "${OPT_DISCORD_USER}" ]]     && echo "[init-profile] Added DISCORD_ALLOWED_USERS=${OPT_DISCORD_USER}"
    [[ -n "${OPT_WHATSAPP_NUMBER}" ]]  && echo "[init-profile] Added WHATSAPP_ALLOWED_USERS=${OPT_WHATSAPP_NUMBER}"
fi

# ── Next steps ────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────"
echo " Profile '${PROFILE_NAME}' initialised at:"
echo "   ${PROFILE_DIR}/"
echo ""
echo " Files:"
for f in config.yaml .env SOUL.md; do
    [[ -f "${PROFILE_DIR}/${f}" ]] && echo "   ✓ ${f}" || echo "   ✗ ${f} (missing)"
done
echo ""
echo " Next steps:"
step=1
echo "  ${step}. Personalise SOUL.md to give ${PROFILE_NAME} a unique identity:"
echo "     nano ${PROFILE_DIR}/SOUL.md"
step=$((step+1))
[[ -z "${OPT_PORT}" ]] && {
    echo "  ${step}. Set a unique api_server.port in config.yaml (8643, 8644, …):"
    echo "     nano ${PROFILE_DIR}/config.yaml"
    step=$((step+1))
}
[[ -z "${OPT_DISCORD_TOKEN}" ]] && {
    echo "  ${step}. Add DISCORD_BOT_TOKEN to .env (create bot at discord.com/developers):"
    echo "     nano ${PROFILE_DIR}/.env"
    step=$((step+1))
}
[[ -z "${OPT_WHATSAPP_NUMBER}" ]] && {
    echo "  ${step}. Add WHATSAPP_ENABLED, WHATSAPP_MODE, WHATSAPP_ALLOWED_USERS to .env"
    step=$((step+1))
}
echo "  ${step}. Add '${PROFILE_NAME}' to HERMES_PROFILES in the root .env:"
echo "     HERMES_PROFILES=\"... ${PROFILE_NAME}\""
step=$((step+1))
echo "  ${step}. Restart and run the interactive setup wizard:"
echo "     docker compose restart agsvchermagt"
echo "     docker compose exec -it agsvchermagt ${PROFILE_NAME} setup"
step=$((step+1))
echo "  ${step}. Pair WhatsApp (run the wizard inside the container):"
echo "     docker compose exec -it agsvchermagt hermes -p ${PROFILE_NAME} whatsapp"
echo "────────────────────────────────────────────────────────────"
echo ""
