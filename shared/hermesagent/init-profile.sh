#!/usr/bin/env bash
# =============================================================================
# init-profile.sh — Bootstrap a Hermes Agent profile directory on the host
#
# Run from the ServiceHub project root:
#   ./shared/hermesagent/init-profile.sh <profile-name> [OPTIONS]
#
# What it does:
#   1. Reads LITEM_APIKEY and APPS_DATA from the root .env
#   2. Creates ${APPS_DATA}/hermesagent/profiles/<name>/ on the host
#   3. Copies config.yaml, SOUL.md, and env.example → .env from
#      shared/hermesagent/default/, skipping files that already exist
#      (use --force to overwrite)
#   4. Substitutes <your-litellm-master-key> and <your-firecrawl-api-key>
#      with the real values from the root .env
#   5. Optionally sets api_server.port, Discord and WhatsApp credentials
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
#   # Minimal — fill tokens later
#   ./shared/hermesagent/init-profile.sh alice --port 8643
#
#   # Full setup in one command
#   ./shared/hermesagent/init-profile.sh alice \
#     --port 8643 \
#     --discord-token "Bot.Token.Here" \
#     --discord-user "123456789012345678" \
#     --whatsapp-number "61412123456"
#
#   # Second profile
#   ./shared/hermesagent/init-profile.sh bob \
#     --port 8644 \
#     --discord-token "AnotherBot.Token" \
#     --discord-user "987654321098765432" \
#     --whatsapp-number "61487654321"
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULTS_DIR="${SCRIPT_DIR}/default"
ENV_FILE="${PROJECT_ROOT}/.env"

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

# ── Read root .env ────────────────────────────────────────────────────────────
if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Error: ${ENV_FILE} not found."
    echo "Run this script from the ServiceHub project root, or ensure .env exists."
    exit 1
fi

# Extract a variable from .env, stripping surrounding quotes
read_env() {
    local key="$1"
    grep -E "^${key}=" "${ENV_FILE}" 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^['\"]//;s/['\"]$//"
}

LITEM_APIKEY="$(read_env LITEM_APIKEY)"
APPS_DATA_RAW="$(read_env APPS_DATA)"
APPS_DATA="${APPS_DATA_RAW/#\~/${HOME}}"   # expand leading ~

if [[ -z "${LITEM_APIKEY}" || "${LITEM_APIKEY}" == *"YOUR_"* || "${LITEM_APIKEY}" == *"your-"* ]]; then
    echo "Error: LITEM_APIKEY is not set or still a placeholder in ${ENV_FILE}."
    echo "Generate one with: python3 -c \"import secrets; print(secrets.token_urlsafe(32))\""
    exit 1
fi

if [[ -z "${APPS_DATA}" ]]; then
    echo "Error: APPS_DATA is not set in ${ENV_FILE}."
    exit 1
fi

# ── Create profile directory ──────────────────────────────────────────────────
PROFILE_DIR="${APPS_DATA}/hermesagent/profiles/${PROFILE_NAME}"
mkdir -p "${PROFILE_DIR}"

echo ""
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

# ── Substitute API key placeholders ──────────────────────────────────────────
for f in "${PROFILE_DIR}/config.yaml" "${PROFILE_DIR}/.env"; do
    [[ -f "${f}" ]] || continue
    sed_inplace "s|<your-litellm-master-key>|${LITEM_APIKEY}|g" "${f}"
    sed_inplace "s|<your-firecrawl-api-key>|${LITEM_APIKEY}|g"  "${f}"
done
echo "[init-profile] Substituted API keys in config.yaml and .env"

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
