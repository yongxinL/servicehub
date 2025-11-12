#!/bin/bash

# This script automates the setup of the .env file for the ServiceHub project.
# It should be run from the project's root directory.
# It copies the .env.example file to .env and populates it with generated secrets.

set -e

# Determine the project's root directory (the parent of the script's directory)
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")

if ! command -v openssl &> /dev/null; then
    echo "Error: openssl is not installed. Please install it to generate secrets." >&2
    exit 1
fi

ENV_FILE=".env"
ENV_EXAMPLE_FILE=".env.example"
cd "$PROJECT_ROOT"
if [ ! -f "$ENV_EXAMPLE_FILE" ]; then
    echo "Error: $ENV_EXAMPLE_FILE not found. Please ensure the example file exists."
    exit 1
fi

if [ -f "$ENV_FILE" ]; then
    read -p "Warning: $ENV_FILE already exists. Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Your existing $ENV_FILE was not modified."
        exit 0
    fi
fi

echo "Creating $ENV_FILE from $ENV_EXAMPLE_FILE..."
cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"

echo "Generating and injecting secrets into $ENV_FILE..."

# Generate secrets
AUTHEN_PGPASS=$(openssl rand -base64 36 | tr -d '\n')
AUTHEN_SECRET=$(openssl rand -base64 60 | tr -d '\n')
# Generate an 18-character alphanumeric password for the main PostgreSQL user
PGRSQL_PASS=$(openssl rand -hex 16 | head -c 18)

# Use a temporary file for sed compatibility between GNU and BSD (macOS)
# The sed command replaces placeholders. Using a different delimiter like '|'
# avoids issues if generated secrets contain the default '/' character.

sed -i.bak \
    -e "s|<YOUR_STRONG_POSTGRES_PASSWORD>|${PGRSQL_PASS}|g" \
    -e "s|<GENERATE_A_RANDOM_SECRET_KEY>|${AUTHEN_SECRET}|g" \
    -e "s|<YOUR_STRONG_AUTHENTIK_ADMIN_PASSWORD>|${AUTHEN_PGPASS}|g" \
    "$ENV_FILE" && rm "${ENV_FILE}.bak"

chmod 600 "$ENV_FILE"

echo "✅ Setup complete!"
echo "$ENV_FILE has been created with new secrets."
echo "Please review $ENV_FILE to ensure all other variables are set correctly for your environment."
