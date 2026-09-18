#!/bin/sh
set -u

ACME_FILE=${ACME_FILE:-/letsencrypt/acme.json}
ACME_RESOLVER=${ACME_RESOLVER:-letsencrypt}
CERT_DIR=${CERT_DIR:-/var/lib/stalwart/tls}
CHECK_INTERVAL=${CERT_CHECK_INTERVAL:-86400}
DOMAIN=${MAIL_DOMAIN:?MAIL_DOMAIN is required}

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

export_certificate() {
    [ -s "$ACME_FILE" ] || return 1
    tmpdir=$(mktemp -d)

    jq -er --arg resolver "$ACME_RESOLVER" --arg domain "$DOMAIN" '      .[$resolver].Certificates[]      | select(.domain.main == $domain or ((.domain.sans // []) | index($domain)))      | .certificate' "$ACME_FILE" | base64 -d > "$tmpdir/fullchain.pem" || {
        rm -rf "$tmpdir"; return 1;
    }

    jq -er --arg resolver "$ACME_RESOLVER" --arg domain "$DOMAIN" '      .[$resolver].Certificates[]      | select(.domain.main == $domain or ((.domain.sans // []) | index($domain)))      | .key' "$ACME_FILE" | base64 -d > "$tmpdir/privkey.pem" || {
        rm -rf "$tmpdir"; return 1;
    }

    openssl x509 -in "$tmpdir/fullchain.pem" -noout >/dev/null 2>&1 || {
        rm -rf "$tmpdir"; return 1;
    }
    openssl pkey -in "$tmpdir/privkey.pem" -noout >/dev/null 2>&1 || {
        rm -rf "$tmpdir"; return 1;
    }

    cert_pub=$(openssl x509 -in "$tmpdir/fullchain.pem" -pubkey -noout       | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1)
    key_pub=$(openssl pkey -in "$tmpdir/privkey.pem" -pubout -outform DER 2>/dev/null       | sha256sum | cut -d' ' -f1)
    [ "$cert_pub" = "$key_pub" ] || {
        log "certificate and private key do not match"
        rm -rf "$tmpdir"; return 1;
    }

    new_hash=$(cat "$tmpdir/fullchain.pem" "$tmpdir/privkey.pem"       | sha256sum | cut -d' ' -f1)
    old_hash=$(cat "$CERT_DIR/.acme-hash" 2>/dev/null || true)

    if [ "$new_hash" != "$old_hash" ]; then
        install -m 0644 "$tmpdir/fullchain.pem" "$CERT_DIR/fullchain.pem.new"
        install -m 0600 "$tmpdir/privkey.pem" "$CERT_DIR/privkey.pem.new"
        mv -f "$CERT_DIR/fullchain.pem.new" "$CERT_DIR/fullchain.pem"
        mv -f "$CERT_DIR/privkey.pem.new" "$CERT_DIR/privkey.pem"
        chown 2000:2000 "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem"
        printf '%s\n' "$new_hash" > "$CERT_DIR/.acme-hash"
        log "installed renewed certificate for $DOMAIN; restarting container"
        rm -rf "$tmpdir"
        kill -TERM 1
        return 0
    fi

    rm -rf "$tmpdir"
}

while :; do
    export_certificate || log "certificate for $DOMAIN is not available; retrying later"
    if [ -d "$(dirname "$ACME_FILE")" ]; then
        inotifywait -q -t "$CHECK_INTERVAL"           -e close_write,create,moved_to "$(dirname "$ACME_FILE")" >/dev/null 2>&1 || true
    else
        sleep "$CHECK_INTERVAL"
    fi
done
