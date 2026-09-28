#!/bin/sh
set -eu

DATA_DIR=/var/lib/stalwart
CERT_DIR="$DATA_DIR/tls"
CONFIG=/etc/stalwart/config.json

mkdir -p "$DATA_DIR/blobs" "$CERT_DIR"
chown -R 2000:2000 "$DATA_DIR"

# Render the PostgreSQL boot config on every start so DB credentials rotate
# without an image rebuild. Placeholders in config.json are substituted with
# the STALWART_PG_* environment variables.
sed -e "s|STALWART_PG_HOST|${STALWART_PG_HOST}|g" \
    -e "s|STALWART_PG_PORT|${STALWART_PG_PORT:-5432}|g" \
    -e "s|STALWART_PG_DBNAME|${POSTE_DBNAME}|g" \
    -e "s|STALWART_PG_USER|${STALWART_PG_USER}|g" \
    -e "s|STALWART_PG_PASS|${STALWART_PG_PASS}|g" \
    -e "s|STALWART_PG_POOL|${STALWART_PG_POOL:-10}|g" \
    /etc/stalwart/config.json.tpl > "$CONFIG"
chmod 0600 "$CONFIG" && chown 2000:2000 "$CONFIG"

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
    /usr/local/bin/stalwart --config "$CONFIG" "$@"
