#!/bin/sh
set -eu

if [ "$(id -u)" != "0" ]; then
    echo "[stalwart] FATAL: entrypoint must start as root: it chowns the data volume and renders /etc/stalwart/config.json before dropping to uid/gid 2000. Remove 'USER stalwart' from the image or any user: override in compose." >&2
    exit 1
fi

DATA_DIR=/var/lib/stalwart
CERT_DIR="$DATA_DIR/tls"
CONFIG_FILE=/etc/stalwart/config.json

: "${STALWART_DB_HOST:?STALWART_DB_HOST is required}"
: "${STALWART_DB_NAME:?STALWART_DB_NAME is required}"
: "${STALWART_DB_USER:?STALWART_DB_USER is required}"
: "${STALWART_DB_PASSWORD:?STALWART_DB_PASSWORD is required}"

# /var/log/stalwart is where Stalwart's built-in default Log tracer writes
# (daily-rotated stalwart.log.<date>); it must exist and be writable by uid 2000.
mkdir -p "$DATA_DIR" "$CERT_DIR" /etc/stalwart /var/log/stalwart "$DATA_DIR/logs"
chown -R 2000:2000 "$DATA_DIR" /var/log/stalwart

# Render the bootstrap configuration (the DataStore object) on every start;
# Stalwart reads it via --config. The password is referenced by environment
# variable name so no secret is written to disk.
jq -n \
    --arg host "$STALWART_DB_HOST" \
    --argjson port "${STALWART_DB_PORT:-5432}" \
    --arg database "$STALWART_DB_NAME" \
    --arg user "$STALWART_DB_USER" \
    '{
        "@type":"PostgreSql",
        "timeout":15000,
        "useTls":false,
        "allowInvalidCerts":true,
        "poolMaxConnections":10,
        "poolRecyclingMethod":"fast",
        "readReplicas":{},
        "host":$host,
        "port": ($port | tonumber),
        "database":$database,
        "authUsername":$user,
        "authSecret":{
            "@type":"EnvironmentVariable",
            "variableName":"STALWART_DB_PASSWORD"
        },
        "options":null
    }' > "$CONFIG_FILE"
chown 2000:2000 "$CONFIG_FILE"

# Recovery admin: guarantees access to https://${EMAIL_HOST}/admin even when
# the configured directory (LDAP) is broken. Empty STALWART_ADMIN_PASS skips it.
if [ -n "${STALWART_ADMIN_USER:-}" ] && [ -n "${STALWART_ADMIN_PASS:-}" ]; then
    export STALWART_RECOVERY_ADMIN="${STALWART_ADMIN_USER}:${STALWART_ADMIN_PASS}"
fi

# Allow the first boot to complete before Traefik has issued the public cert.
if [ ! -s "$CERT_DIR/fullchain.pem" ] || [ ! -s "$CERT_DIR/privkey.pem" ]; then
    echo "[stalwart] creating temporary bootstrap certificate for ${MAIL_DOMAIN}"
    openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
      -subj "/CN=${MAIL_DOMAIN}" \
      -addext "subjectAltName=DNS:${MAIL_DOMAIN}" \
      -keyout "$CERT_DIR/privkey.pem" \
      -out "$CERT_DIR/fullchain.pem"
    chmod 0600 "$CERT_DIR/privkey.pem"
    chmod 0644 "$CERT_DIR/fullchain.pem"
    chown 2000:2000 "$CERT_DIR/privkey.pem" "$CERT_DIR/fullchain.pem"
fi

/usr/local/bin/acme-export.sh &
watcher_pid=$!
trap 'kill "$watcher_pid" 2>/dev/null || true' EXIT INT TERM

exec setpriv --reuid=2000 --regid=2000 --clear-groups -- \
    /usr/local/bin/stalwart --config /etc/stalwart/config.json "$@"
