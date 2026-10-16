#!/bin/bash

# Setup and merge script for ServiceHub environment variables.
# - If .env does not exist: creates .env from env.example with generated secrets.
# - If .env exists: merges new variables from env.example, preserving existing values.
#
# Usage:
#   bash scripts/setup.sh                          # Setup or merge .env
#   bash scripts/setup.sh --encode <STAG|PROD>     # Output base64-encoded secrets for Forgejo Actions
#   bash scripts/setup.sh --decode <STAG|PROD>     # Restore .env from an Actions secret
#
# Options:
#   --encode <env>   Output base64-encoded .env and acme.json for specified environment
#   --decode <env>   Decode and restore .env from an Actions secret (interactive)

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

ENV_FILE=".env"
ENV_EXAMPLE_FILE="env.example"

cd "$PROJECT_ROOT"

# Traefik stores ACME certificates at ${APPS_DATA}/shared/certs/acme.json
# (see compose/route.yml, which mounts that directory at /letsencrypt).
# Resolve APPS_DATA from .env, expanding a leading ~ to $HOME.
APPS_DATA=$(grep -E '^APPS_DATA=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d '=' -f2- | tr -d '"')
APPS_DATA="${APPS_DATA/#\~/$HOME}"
ACME_FILE="${APPS_DATA:-$HOME/Documents/containerd}/shared/certs/acme.json"

# Function to generate secrets and inject into .env
inject_secrets() {
    echo "Generating secrets for placeholder values..."

    DB_ADMIN_PASSWORD=$(openssl rand -hex 16 | head -c 18)
    GRAFANA_PASS=$(openssl rand -hex 16 | head -c 18)
    AUTHK_PASS=$(openssl rand -base64 36 | tr -d '\n')
    AUTHK_SECRET=$(openssl rand -base64 60 | tr -d '\n')
    LITELLM_APIKEY="sk-$(openssl rand -hex 24)"
    LITELLM_ADMPWD=$(openssl rand -base64 24 | tr -d '\n')
    RUNNER_SECRET=$(openssl rand -hex 20)
    HERMES_WORKSPACE_PASSWD_00=$(openssl rand -base64 24 | tr -d '\n')
    WEBMAIL_SESSION_SECRET=$(openssl rand -base64 32 | tr -d '\n')
    STALWART_ADMIN_PASS=$(openssl rand -base64 24 | tr -d '\n')

    # Only replace if the current value matches the placeholder (not already set)
    sed -i.bak \
        -e "s|<YOUR_STRONG_DB_ADMIN_PASSWORD>|${DB_ADMIN_PASSWORD}|g" \
        -e "s|<YOUR_STRONG_GRAFANA_PASSWORD>|${GRAFANA_PASS}|g" \
        -e "s|<YOUR_STRONG_AUTHENTIK_PASSWORD>|${AUTHK_PASS}|g" \
        -e "s|<YOUR_STRONG_AUTHENTIK_SECRETKEY>|${AUTHK_SECRET}|g" \
        -e "s|<YOUR_LITELLM_MASTER_API_KEY>|${LITELLM_APIKEY}|g" \
        -e "s|<YOUR_STRONG_LITELLM_ADMIN_PASSWORD>|${LITELLM_ADMPWD}|g" \
        -e "s|<YOUR_SOURCECODE_RUNNER_SECRET>|${RUNNER_SECRET}|g" \
        -e "s|<YOUR_HERMES_WORKSPACE_PASSWORD_00>|${HERMES_WORKSPACE_PASSWD_00}|g" \
        -e "s|<YOUR_STRONG_WEBMAIL_SESSION_SECRET>|${WEBMAIL_SESSION_SECRET}|g" \
        -e "s|<YOUR_STRONG_STALWART_ADMIN_PASSWORD>|${STALWART_ADMIN_PASS}|g" \
        "$ENV_FILE" && rm "${ENV_FILE}.bak"
}

# Function to merge env.example with existing .env
merge_env() {
    echo "Merging new variables from env.example into existing .env..."

    python3 - "$ENV_EXAMPLE_FILE" "$ENV_FILE" "$ENV_FILE.tmp" <<'PYEOF'
import re
import sys


def parse_blocks(path):
    with open(path) as handle:
        lines = handle.read().splitlines()

    blocks = []
    index = 0
    while index < len(lines):
        line = lines[index]
        match = re.match(r"(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)", line)
        if not match:
            blocks.append((None, [line]))
            index += 1
            continue

        key = match.group(1)
        value = match.group(2)
        block = [line]
        index += 1
        if value and value[0] in {"'", '"'}:
            while not quote_closed(value, value[0]):
                if index == len(lines):
                    raise ValueError(f"unterminated quoted value for {key} in {path}")
                value += "\n" + lines[index]
                block.append(lines[index])
                index += 1
        blocks.append((key, block))
    return blocks


def quote_closed(value, quote):
    escaped = False
    for char in value[1:]:
        if quote == '"' and escaped:
            escaped = False
            continue
        if quote == '"' and char == "\\":
            escaped = True
            continue
        if char == quote:
            return True
    return False


example_path, env_path, output_path = sys.argv[1:]
example_blocks = parse_blocks(example_path)
env_blocks = parse_blocks(env_path)
existing = {key: block for key, block in env_blocks if key}

lines = []
seen = set()
for key, block in example_blocks:
    if key in existing:
        lines.extend(existing[key])
        seen.add(key)
    else:
        lines.extend(block)

for key, block in env_blocks:
    if key not in seen:
        lines.extend(block)
        seen.add(key)

with open(output_path, "w") as handle:
    handle.write("\n".join(lines) + "\n")
PYEOF

    # Replace original with merged
    mv "$ENV_FILE.tmp" "$ENV_FILE"
}

# Function to encode .env and acme.json for a specific environment
encode_secrets() {
    local env=$1

    if [ -z "$env" ]; then
        echo "Error: Environment required (STAG or PROD)"
        echo "Usage: bash scripts/setup.sh --encode <STAG|PROD>"
        exit 1
    fi

    env=$(echo "$env" | tr '[:lower:]' '[:upper:]')

    if [ "$env" != "STAG" ] && [ "$env" != "PROD" ]; then
        echo "Error: Environment must be STAG or PROD"
        exit 1
    fi

    echo "=============================================="
    echo "  Base64-encoded secrets for Forgejo Actions"
    echo "  Environment: $env"
    echo "=============================================="
    echo ""

    if [ ! -f "$ENV_FILE" ]; then
        echo "Error: .env file not found. Run setup.sh first."
        exit 1
    fi

    # Output to files for easy copying
    local env_lower=$(echo "$env" | tr '[:upper:]' '[:lower:]')
    local envs_file="${env}_B64ENC_ENVS.b64"
    local acme_b64_file="${env}_B64ENC_ACME.b64"

    echo "Encoding .env to ${envs_file} (gzip compressed)..."
    gzip -c "$ENV_FILE" | base64 | tr -d '\n' > "$envs_file"

    local acme_encoded=false
    local acme_size=0
    if [ -f "$ACME_FILE" ]; then
        acme_size=$(wc -c < "$ACME_FILE")
    fi

    if [ "$acme_size" -gt 1024 ]; then
        echo "Encoding ${ACME_FILE} to ${acme_b64_file} (gzip compressed)..."
        gzip -c "$ACME_FILE" | base64 | tr -d '\n' > "$acme_b64_file"
        acme_encoded=true
    elif [ ! -f "$ACME_FILE" ]; then
        echo "Note: ${ACME_FILE} not found - skipping ACME encoding"
    else
        echo "Note: ${ACME_FILE} is empty or smaller than 1KB - skipping ACME encoding"
    fi

    echo ""
    echo "=============================================="
    echo "  Files created:"
    echo "=============================================="
    echo ""
    echo "  ${envs_file}  -> Forgejo Actions secret: ${env}_B64ENC_ENVS"
    if [ "$acme_encoded" = true ]; then
        echo "  ${acme_b64_file}  -> Forgejo Actions secret: ${env}_B64ENC_ACME"
    fi
    echo ""
    echo "To get content for Actions secrets, run:"
    echo "  cat ${envs_file}      # copy output to ${env}_B64ENC_ENVS"
    if [ "$acme_encoded" = true ]; then
        echo "  cat ${acme_b64_file}  # copy output to ${env}_B64ENC_ACME"
    else
        echo "  ${env}_B64ENC_ACME: not required - Traefik will use self-signed certificate"
    fi
    echo ""
    echo "Or pipe directly:"
    echo "  cat ${envs_file} | xclip -selection clipboard"
    echo ""
    echo "Go to: Forgejo -> Repository -> Settings -> Actions -> Secrets"
    echo ""
}

# Function to decode and restore .env from base64 (interactive)
decode_secrets() {
    local env=$1

    if [ -z "$env" ]; then
        echo "Error: Environment required (STAG or PROD)"
        echo "Usage: bash scripts/setup.sh --decode <STAG|PROD>"
        exit 1
    fi

    env=$(echo "$env" | tr '[:lower:]' '[:upper:]')

    if [ "$env" != "STAG" ] && [ "$env" != "PROD" ]; then
        echo "Error: Environment must be STAG or PROD"
        exit 1
    fi

    echo "This will OVERWRITE your current .env file!"
    echo "Environment: $env"
    # The encoded secret has no trailing newline, so `read` returns non-zero at
    # EOF; tolerate that (and an empty input) instead of aborting under `set -e`.
    IFS= read -p "Enter base64-encoded ${env}_B64ENC_ENVS content (or Ctrl+C to cancel): " -r || true

    if [ -n "$REPLY" ]; then
        echo "$REPLY" | base64 -d | gunzip > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        echo ".env restored from provided base64 content."
    fi
}

# Parse arguments
case "$1" in
    --encode)
        encode_secrets "$2"
        exit 0
        ;;
    --decode)
        decode_secrets "$2"
        exit 0
        ;;
esac

# Main logic
if [ ! -f "$ENV_FILE" ]; then
    echo "No existing .env found. Creating from env.example..."
    cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
    inject_secrets
    echo "✅ Setup complete! .env has been created with generated secrets."
else
    echo "Existing .env found. Checking for new variables from env.example..."
    merge_env
    inject_secrets
    echo "✅ Merge complete! .env has been updated with new variables."
fi

chmod 600 "$ENV_FILE"
echo "Please review $ENV_FILE to ensure all variables are set correctly for your environment."

# The live egress policy file is runtime state, so it lives under APPS_DATA
# rather than in the repository: a deploy's rsync never touches that directory
# (operator allow-domain/block-domain edits survive) and the weekly full
# archive already covers it. It sits in shared/gateway alongside the other
# cross-cutting host state. Seed it once from the repository default, migrate
# the pre-shared/gateway location if that is where it lives, then leave it
# alone — policy changes are made on the server, not in git.
# APPS_DATA is re-read here because this runs after the merge above.
APPS_DATA=$(grep -E '^APPS_DATA=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d '=' -f2- | tr -d '"')
APPS_DATA="${APPS_DATA/#\~/$HOME}"
EGRESS_GATEWAY_DIR="${APPS_DATA:+$APPS_DATA/shared/gateway}"
EGRESS_POLICY_DST="${EGRESS_GATEWAY_DIR:+$EGRESS_GATEWAY_DIR/egress-policies.conf}"
EGRESS_POLICY_LEGACY="${APPS_DATA:+$APPS_DATA/egress-policies.conf}"
if [ -n "$EGRESS_POLICY_DST" ] && [ -d "$APPS_DATA" ]; then
    if [ ! -f "$EGRESS_POLICY_DST" ] && [ -f "$EGRESS_POLICY_LEGACY" ]; then
        mkdir -p "$EGRESS_GATEWAY_DIR"
        mv "$EGRESS_POLICY_LEGACY" "$EGRESS_POLICY_DST"
        echo "Moved $EGRESS_POLICY_LEGACY -> $EGRESS_POLICY_DST"
    elif [ ! -f "$EGRESS_POLICY_DST" ] && [ -f "$SCRIPT_DIR/egress-policies.conf" ]; then
        mkdir -p "$EGRESS_GATEWAY_DIR"
        cp "$SCRIPT_DIR/egress-policies.conf" "$EGRESS_POLICY_DST"
        echo "Seeded $EGRESS_POLICY_DST from the repository default"
    fi
fi

# Regenerate the Traefik admin routers from .env (ADR-009). The file provider
# watches shared/traefik/advanced, so TRUSTED_IP, DOMAIN_NAME and the derived
# domain changes hot-reload without restarting any container. Fail loudly:
# a stale generated file would silently keep serving the old hosts.
if ! python3 "$SCRIPT_DIR/gen-admin-rules.py"; then
    echo "Error: failed to regenerate shared/traefik/advanced/admin-routers.yml" >&2
    exit 1
fi
echo "Regenerated shared/traefik/advanced/admin-routers.yml (Traefik hot-reloads it)."
