#!/bin/sh
set -eu

DATA_DIR=/var/lib/stalwart
CERT_DIR="$DATA_DIR/tls"

mkdir -p "$DATA_DIR/sqlite" "$DATA_DIR/blobs" "$CERT_DIR"
chown -R 2000:2000 "$DATA_DIR"

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