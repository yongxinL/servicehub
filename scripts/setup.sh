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

# Traefik stores ACME certificates at ${APPS_DATA}/certs/acme.json
# (see compose/route.yml, which mounts that directory at /letsencrypt).
# Resolve APPS_DATA from .env, expanding a leading ~ to $HOME.
APPS_DATA=$(grep -E '^APPS_DATA=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d '=' -f2- | tr -d '"')
APPS_DATA="${APPS_DATA/#\~/$HOME}"
ACME_FILE="${APPS_DATA:-$HOME/Documents/containerd}/certs/acme.json"

# Function to generate secrets and inject into .env
inject_secrets() {
    echo "Generating secrets for placeholder values..."

    SQLDB_PASS=$(openssl rand -hex 16 | head -c 18)
    GRAFANA_PASS=$(openssl rand -hex 16 | head -c 18)
    AUTHK_PASS=$(openssl rand -base64 36 | tr -d '\n')
    AUTHK_SECRET=$(openssl rand -base64 60 | tr -d '\n')
    LITELLM_APIKEY="sk-$(openssl rand -hex 24)"
    LITELLM_ADMPWD=$(openssl rand -base64 24 | tr -d '\n')
    RUNNER_SECRET=$(openssl rand -hex 20)
    HERMES_WORKSPACE_PASSWD_00=$(openssl rand -base64 24 | tr -d '\n')
    WEBMAIL_SESSION_SECRET=$(openssl rand -base64 32 | tr -d '\n')

    # Only replace if the current value matches the placeholder (not already set)
    sed -i.bak \
        -e "s|<YOUR_STRONG_SQLDB_PASSWORD>|${SQLDB_PASS}|g" \
        -e "s|<YOUR_STRONG_GRAFANA_PASSWORD>|${GRAFANA_PASS}|g" \
        -e "s|<YOUR_STRONG_AUTHENTIK_PASSWORD>|${AUTHK_PASS}|g" \
        -e "s|<YOUR_STRONG_AUTHENTIK_SECRETKEY>|${AUTHK_SECRET}|g" \
        -e "s|<YOUR_LITELLM_MASTER_API_KEY>|${LITELLM_APIKEY}|g" \
        -e "s|<YOUR_STRONG_LITELLM_ADMIN_PASSWORD>|${LITELLM_ADMPWD}|g" \
        -e "s|<YOUR_DEPOT_RUNNER_SECRET>|${RUNNER_SECRET}|g" \
        -e "s|<YOUR_HERMES_WORKSPACE_PASSWORD_00>|${HERMES_WORKSPACE_PASSWD_00}|g" \
        -e "s|<YOUR_STRONG_WEBMAIL_SESSION_SECRET>|${WEBMAIL_SESSION_SECRET}|g" \
        "$ENV_FILE" && rm "${ENV_FILE}.bak"
}

# Function to rename legacy variables that were refactored between releases.
# Must run before merge_env so that references in other values (e.g. the
# PGRSQL_DBLIST composition) are rewritten too.
migrate_env() {
    # The legacy Gitea/Woodpecker runner token no longer exists (Forgejo Actions
    # uses a shared runner secret); drop it from old .env files.
    if grep -q '^REPBUK_' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating legacy REPBUK_* variables to DEPOT_* ..."
        sed -i.bak \
            -e 's/REPBUK_DBNAME/DEPOT_DBNAME/g' \
            -e 's/REPBUK_DOMAIN/DEPOT_DOMAIN/g' \
            "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
        sed -i.bak '/^REPBUK_RUNTOKEN=/d' "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi

    # Woodpecker CI was replaced by Forgejo Actions; its secrets are obsolete.
    if grep -qE '^(GITBLD_OA_CLIENT|GITBLD_OA_SECRET|GITBLD_GRPC_SECRET|GITBLD_ADMUSR|GITBLD_DOMAIN|GITBLD_NETWORK)=' "$ENV_FILE" 2>/dev/null; then
        echo "Removing obsolete Woodpecker variables (GITBLD_OA_*, GITBLD_GRPC_SECRET, GITBLD_ADMUSR, GITBLD_DOMAIN, GITBLD_NETWORK) ..."
        sed -i.bak \
            -e '/^GITBLD_OA_CLIENT=/d' \
            -e '/^GITBLD_OA_SECRET=/d' \
            -e '/^GITBLD_GRPC_SECRET=/d' \
            -e '/^GITBLD_ADMUSR=/d' \
            -e '/^GITBLD_DOMAIN=/d' \
            -e '/^GITBLD_NETWORK=/d' \
            "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi

    # The homepage web service was renamed from wbsvc to wbapp and its variables
    # from WEBHOM_* to WBHOME_*. WBHOME_DOMAN was a typo; the canonical name is
    # WBHOME_DOMAIN. The Confluence image tag moved from WBCONF_TAG to WBHOME_TAG.
    if grep -qE '^(WEBHOM_|WBHOME_DOMAN=|WBCONF_TAG=)' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating legacy WEBHOM_* / WBHOME_DOMAN / WBCONF_TAG variables ..."
        sed -i.bak \
            -e 's/^WEBHOM_DBNAME=/WBHOME_DBNAME=/' \
            -e 's/^WEBHOM_DOMAIN=/WBHOME_DOMAIN=/' \
            -e 's/^WBHOME_DOMAN=/WBHOME_DOMAIN=/' \
            -e 's/^WBCONF_TAG=/WBHOME_TAG=/' \
            -e 's/\${WEBHOM_DBNAME}/${WBHOME_DBNAME}/g' \
            -e 's/\${WEBHOM_DOMAIN}/${WBHOME_DOMAIN}/g' \
            -e 's/\${WBHOME_DOMAN}/${WBHOME_DOMAIN}/g' \
            "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi

    # The observability compose domain was renamed from secob to obsvc; its
    # variables moved from SECOB_* to OBSVC_*.
    if grep -q '^SECOB_' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating legacy SECOB_* variables to OBSVC_* ..."
        sed -i.bak \
            -e 's/^SECOB_/OBSVC_/' \
            -e 's/\${SECOB_/${OBSVC_/g' \
            "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi
}

# Function to merge env.example with existing .env
merge_env() {
    echo "Merging new variables from env.example into existing .env..."

    # Create a temp file to store merged result
    cp "$ENV_EXAMPLE_FILE" "$ENV_FILE.tmp"

    # For each variable in the existing .env, preserve it in the new file
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        # If key exists in env.example and has a value in .env, preserve it
        if grep -q "^${key}=" "$ENV_EXAMPLE_FILE"; then
            old_value=$(grep "^${key}=" "$ENV_FILE" | head -1 | cut -d '=' -f2-)
            if [ -n "$old_value" ]; then
                # Use python3 so arbitrary characters in old_value (quotes, pipes,
                # backslashes) are never interpreted by the shell or sed.
                python3 - "$key" "$old_value" "$ENV_FILE.tmp" <<'PYEOF'
import sys, re
key, val, fname = sys.argv[1], sys.argv[2], sys.argv[3]
with open(fname) as f:
    content = f.read()
content = re.sub(r'^' + re.escape(key) + r'=.*', key + '=' + val, content, flags=re.MULTILINE)
with open(fname, 'w') as f:
    f.write(content)
PYEOF
            fi
        fi
    done < "$ENV_FILE"

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
    migrate_env
    merge_env
    inject_secrets
    echo "✅ Merge complete! .env has been updated with new variables."
fi

chmod 600 "$ENV_FILE"
echo "Please review $ENV_FILE to ensure all variables are set correctly for your environment."
