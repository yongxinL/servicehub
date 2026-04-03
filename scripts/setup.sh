#!/bin/bash

# Setup and merge script for ServiceHub environment variables.
# - If .env does not exist: creates .env from env.example with generated secrets.
# - If .env exists: merges new variables from env.example, preserving existing values.
#
# Usage:
#   bash scripts/setup.sh                          # Setup or merge .env
#   bash scripts/setup.sh --encode <STAG|PROD>     # Output base64-encoded secrets for Gitea
#   bash scripts/setup.sh --decode <STAG|PROD>     # Restore .env from Gitea secret
#
# Options:
#   --encode <env>   Output base64-encoded .env and acme.json for specified environment
#   --decode <env>   Decode and restore .env from Gitea secret (interactive)

set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

ENV_FILE=".env"
ENV_EXAMPLE_FILE="env.example"
ACME_FILE="shared/letsencrypt/acme.json"

cd "$PROJECT_ROOT"

# Function to generate secrets and inject into .env
inject_secrets() {
    echo "Generating secrets..."

    SQLDB_PASS=$(openssl rand -hex 16 | head -c 18)
    AUTHK_PASS=$(openssl rand -base64 36 | tr -d '\n')
    AUTHK_SECRET=$(openssl rand -base64 60 | tr -d '\n')

    sed -i.bak \
        -e "s|<YOUR_STRONG_SQLDB_PASSWORD>|${SQLDB_PASS}|g" \
        -e "s|<YOUR_STRONG_AUTHENTIK_PASSWORD>|${AUTHK_PASS}|g" \
        -e "s|<YOUR_STRONG_AUTHENTIK_SECRETKEY>|${AUTHK_SECRET}|g" \
        "$ENV_FILE" && rm "${ENV_FILE}.bak"
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
        if grep -q "^${key}=" "$ENV_FILE"; then
            old_value=$(grep "^${key}=" "$ENV_FILE" | head -1 | cut -d '=' -f2-)
            if [ -n "$old_value" ]; then
                sed -i "s|^${key}=.*|${key}=${old_value}|" "$ENV_FILE.tmp"
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
    echo "  Base64-encoded secrets for Gitea"
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

    echo "Encoding .env to ${envs_file}..."
    base64 -w 0 "$ENV_FILE" > "$envs_file"

    echo "Encoding ${ACME_FILE} to ${acme_b64_file}..."
    if [ -f "$ACME_FILE" ]; then
        base64 -w 0 "$ACME_FILE" > "$acme_b64_file"
    else
        echo "# acme.json not found" > "$acme_b64_file"
        echo "Note: ${ACME_FILE} not found - file created with placeholder, skip this secret in Gitea if not needed"
    fi

    echo ""
    echo "=============================================="
    echo "  Files created:"
    echo "=============================================="
    echo ""
    echo "  ${envs_file}      -> Gitea secret: ${env}_B64ENC_ENVS"
    echo "  ${acme_b64_file}  -> Gitea secret: ${env}_B64ENC_ACME"
    echo ""
    echo "To get content for Gitea secrets, run:"
    echo "  cat ${envs_file}      # copy output to ${env}_B64ENC_ENVS"
    echo "  cat ${acme_b64_file}  # copy output to ${env}_B64ENC_ACME"
    echo ""
    echo "Or pipe directly:"
    echo "  cat ${envs_file} | xclip -selection clipboard"
    echo ""
    echo "Go to: Gitea -> Repository -> Settings -> Actions -> Secrets"
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
    read -p "Enter base64-encoded ${env}_B64ENC_ENVS content (or Ctrl+C to cancel): " -r

    if [ -n "$REPLY" ]; then
        echo "$REPLY" | base64 -d > "$ENV_FILE"
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
