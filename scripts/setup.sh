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

# Function to rename legacy variables that were refactored between releases.
# Must run before merge_env so that references in other values (e.g. the
# POSTGRES_DATABASES composition) are rewritten too.
migrate_env() {
    # ADR-008 renamed service, domain, and database variables to business-domain
    # names and moved the databases into the svchub_* namespace. Rewrite an
    # ADR-007-era .env in one pass (variable renames first so the database-value
    # rules below match the new names).
    if grep -qE '^(AUTHN_|DEPOT_|WBHOME_|OWEBUI_|OBSVC_|POSTE_DBNAME|LITEM_|SQLDB_|PGRSQL_|MySQL_|MARIADB_DB_LIST|WBDRIVE_|WBCLOUD_)' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating ADR-008 environment variable names ..."
        sed -i.bak \
            -e 's/AUTHN_DBNAME/IDENTITY_DBNAME/g' \
            -e 's/AUTHN_DOMAIN/IDENTITY_DOMAIN/g' \
            -e 's/AUTHN_TAG/IDENTITY_TAG/g' \
            -e 's/AUTHN_PASSWD/IDENTITY_PASSWORD/g' \
            -e 's/AUTHN_SECRET/IDENTITY_SECRET/g' \
            -e 's/DEPOT_DBNAME/SOURCECODE_DBNAME/g' \
            -e 's/DEPOT_DOMAIN/SOURCECODE_DOMAIN/g' \
            -e 's/DEPOT_VTAG/SOURCECODE_TAG/g' \
            -e 's/DEPOT_RUNNER_SECRET/SOURCECODE_RUNNER_SECRET/g' \
            -e 's/DEPOT_RUNNER_VTAG/SOURCECODE_RUNNER_TAG/g' \
            -e 's/WBHOME_DBNAME/WORKSPACE_DBNAME/g' \
            -e 's/WBHOME_DOMAIN/WORKSPACE_DOMAIN/g' \
            -e 's/WBHOME_TAG/WORKSPACE_TAG/g' \
            -e 's/OWEBUI_DOMAIN/CHAT_DOMAIN/g' \
            -e 's/OBSVC_DOMAIN/OBSERVABILITY_DOMAIN/g' \
            -e 's/OBSVC_ADMUSR/OBSERVABILITY_ADMIN_USER/g' \
            -e 's/OBSVC_ADMPWD/OBSERVABILITY_ADMIN_PASSWORD/g' \
            -e 's/WEBMAIL_DOMAIN/POSTOFFICE_DOMAIN/g' \
            -e 's/POSTE_DBNAME/POSTOFFICE_DBNAME/g' \
            -e 's/WBDRIVE_DOMAIN/CLOUD_DOMAIN/g' \
            -e 's/WBDRIVE_TAG/CLOUD_TAG/g' \
            -e 's/WBDRIVE_OIDC_ISSUER/CLOUD_OIDC_ISSUER/g' \
            -e 's/WBDRIVE_OIDC_CLIENT_ID/CLOUD_OIDC_CLIENT_ID/g' \
            -e 's/WBDRIVE_INSECURE/CLOUD_INSECURE/g' \
            -e 's/\${WBCLOUD_/${CLOUD_/g' \
            -e 's/^WBCLOUD_/CLOUD_/' \
            -e 's/LITEM_API_KEY/AIGATE_API_KEY/g' \
            -e 's/LITEM_API_URL/AIGATE_API_URL/g' \
            -e 's/LITEM_ADMUSR/AIGATE_ADMIN_USER/g' \
            -e 's/LITEM_ADMPWD/AIGATE_ADMIN_PASSWORD/g' \
            -e 's/LITEM_DBNAME/AIGATE_DBNAME/g' \
            -e 's/LITEM_HPH_APIURL/AIGATE_HERMES_API_URL/g' \
            -e 's/LITEM_HPH_APIKEY/AIGATE_HERMES_API_KEY/g' \
            -e 's/LITEM_HPH_HLTURL/AIGATE_HERMES_HEALTH_URL/g' \
            -e 's/LITEM_PRM_APIBASE/AIGATE_PROVIDER_API_BASE/g' \
            -e 's/LITEM_PRM_APIKEY/AIGATE_PROVIDER_API_KEY/g' \
            -e 's/SQLDB_USER/DB_ADMIN_USER/g' \
            -e 's/SQLDB_PASS/DB_ADMIN_PASSWORD/g' \
            -e 's/MySQL_HOST/MARIADB_HOST/g' \
            -e 's/MySQL_PORT/MARIADB_PORT/g' \
            -e 's/MARIADB_DB_LIST/MARIADB_DATABASES/g' \
            -e 's/PGRSQL_HOST/POSTGRES_HOST/g' \
            -e 's/PGRSQL_PORT/POSTGRES_PORT/g' \
            -e 's/PGRSQL_DBLIST/POSTGRES_DATABASES/g' \
            -e 's/^IDENTITY_DBNAME="svchubauthtk"/IDENTITY_DBNAME="svchub_identity"/' \
            -e 's/^IDENTITY_DBNAME=svchubauthtk$/IDENTITY_DBNAME=svchub_identity/' \
            -e 's/^SOURCECODE_DBNAME="svchubsvnrep"/SOURCECODE_DBNAME="svchub_sourcecode"/' \
            -e 's/^SOURCECODE_DBNAME=svchubsvnrep$/SOURCECODE_DBNAME=svchub_sourcecode/' \
            -e 's/^WORKSPACE_DBNAME="svchubwbhome"/WORKSPACE_DBNAME="svchub_workspace"/' \
            -e 's/^WORKSPACE_DBNAME=svchubwbhome$/WORKSPACE_DBNAME=svchub_workspace/' \
            -e 's/^POSTOFFICE_DBNAME="svchubmboxdb"/POSTOFFICE_DBNAME="svchub_postoffice"/' \
            -e 's/^POSTOFFICE_DBNAME=svchubmboxdb$/POSTOFFICE_DBNAME=svchub_postoffice/' \
            -e 's/^AIGATE_DBNAME="litellm"/AIGATE_DBNAME="svchub_aigateway"/' \
            -e 's/^AIGATE_DBNAME=litellm$/AIGATE_DBNAME=svchub_aigateway/' \
            "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi

    # The legacy Gitea/Woodpecker runner token no longer exists (Forgejo Actions
    # uses a shared runner secret); drop it from old .env files.
    if grep -q '^REPBUK_' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating legacy REPBUK_* variables to SOURCECODE_* ..."
        sed -i.bak \
            -e 's/REPBUK_DBNAME/SOURCECODE_DBNAME/g' \
            -e 's/REPBUK_DOMAIN/SOURCECODE_DOMAIN/g' \
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
    # WORKSPACE_DOMAIN. The Confluence image tag moved from WBCONF_TAG to WORKSPACE_TAG.
    if grep -qE '^(WEBHOM_|WBHOME_DOMAN=|WBCONF_TAG=)' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating legacy WEBHOM_* / WBHOME_DOMAN / WBCONF_TAG variables ..."
        sed -i.bak \
            -e 's/^WEBHOM_DBNAME=/WORKSPACE_DBNAME=/' \
            -e 's/^WEBHOM_DOMAIN=/WORKSPACE_DOMAIN=/' \
            -e 's/^WBHOME_DOMAN=/WORKSPACE_DOMAIN=/' \
            -e 's/^WBCONF_TAG=/WORKSPACE_TAG=/' \
            -e 's/\${WEBHOM_DBNAME}/${WORKSPACE_DBNAME}/g' \
            -e 's/\${WEBHOM_DOMAIN}/${WORKSPACE_DOMAIN}/g' \
            -e 's/\${WBHOME_DOMAN}/${WORKSPACE_DOMAIN}/g' \
            "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    fi

    # The observability compose domain was renamed from secob to obsvc (ADR-007),
    # then to obsvce with OBSERVABILITY_* variables (ADR-008).
    if grep -q '^SECOB_' "$ENV_FILE" 2>/dev/null; then
        echo "Migrating legacy SECOB_* variables to OBSERVABILITY_* ..."
        sed -i.bak \
            -e 's/^SECOB_DOMAIN=/OBSERVABILITY_DOMAIN=/' \
            -e 's/^SECOB_ADMUSR=/OBSERVABILITY_ADMIN_USER=/' \
            -e 's/^SECOB_ADMPWD=/OBSERVABILITY_ADMIN_PASSWORD=/' \
            -e 's/\${SECOB_DOMAIN}/${OBSERVABILITY_DOMAIN}/g' \
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
