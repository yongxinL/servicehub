# Stalwart Mail Server — ServiceHub

> All-in-one mail & collaboration server: SMTP, JMAP, IMAP, CalDAV, CardDAV and WebDAV in a single Rust binary.

## Overview

[Stalwart](https://github.com/stalwartlabs/stalwart) is the email server of the ServiceHub email domain (`emsvc`). It handles server-to-server and submission SMTP, IMAP and JMAP, and serves the web admin UI and API over HTTP. Bulwark webmail ([`../bulwark/README.md`](../bulwark/README.md)) talks to Stalwart via JMAP. The service is defined by `emsvcmailsrv` in [`compose/emsvc.yml`](../../compose/emsvc.yml) and built from [`Dockerfile`](Dockerfile) (`FROM stalwartlabs/stalwart:${IMAGE_TAG}`).

## Service details

| Detail | Value |
|---|---|
| Service name | `emsvcmailsrv` |
| Image tag | `v0.16` (build arg `IMAGE_TAG`) |
| Web admin / API / JMAP (HTTP) | 8080, routed by Traefik at `https://${EMAIL_HOST}` |
| SMTP server-to-server, STARTTLS | 25 (published to the host) |
| SMTP submission, implicit TLS | 465 (published to the host) |
| SMTP submission, STARTTLS | 587 (published to the host) |
| IMAP, implicit TLS | 993 (published to the host) |
| Optional listeners | 110, 143, 995, 4190 (commented out in the compose file) |
| Internal HTTPS listener | 443 (not published — used by Bulwark over the Docker network) |
| Health check | `curl -fsS http://localhost:8080/healthz` every 30 s |
| Depends on | `routetraefik` (healthy) — Traefik must issue the public certificate first |
| Depended on by | `emsvcwebmail` (healthy) |
| Data persistence | `${APPS_DATA}/mailbox/stalwart` (mounted at `/var/lib/stalwart`) |
| Certificates | `${APPS_DATA}/certs` (mounted read-only at `/letsencrypt`) |

## Traefik routing

Incoming HTTPS requests for `${EMAIL_HOST}` are routed to the internal HTTP port 8080 by Traefik, which terminates TLS. The router has an IP allow-list middleware (`emsvcmailsrv-whitelist`) built from `${TRUSTED_IP}`, so the web admin UI is only reachable from trusted networks.

## TLS certificates

Certificates come from the shared Traefik ACME store — Stalwart does not run its own ACME client:

1. On first boot, before any public certificate exists, [`entrypoint.sh`](entrypoint.sh) generates a 2-day bootstrap self-signed certificate for `${MAIL_DOMAIN}` so the server can start.
2. [`acme-export.sh`](acme-export.sh) runs as a background watcher: every `${CERT_CHECK_INTERVAL}` seconds (and on `acme.json` changes via `inotifywait`) it:
   - extracts the fullchain and key for `${MAIL_DOMAIN}` from `/letsencrypt/acme.json` under the `${CERTRESOLVER}` resolver,
   - validates them with `openssl` and checks cert/key match,
   - on change, installs them into `/var/lib/stalwart/tls/` and restarts the server.

This mirrors how the deploy workflow restores `acme.json` from the `*_B64ENC_ACME` Forgejo Actions secret.

## Configuration (env)

| Variable | Purpose |
|---|---|
| `TIME_ZONE` | Container timezone |
| `EMAIL_HOST` | Mail server hostname; container `hostname`, Stalwart `MAIL_DOMAIN` and public URL |
| `CERTRESOLVER` | Which key of `acme.json` to read (`letsencrypt` or empty for self-signed staging) |
| `CERT_CHECK_INTERVAL` | Certificate re-check interval (default `86400`) |

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/lib/stalwart` | `${APPS_DATA}/mailbox/stalwart` | SQLite store, blobs, TLS key material and first-boot-generated config |
| `/letsencrypt` | `${APPS_DATA}/certs` | Traefik's shared `acme.json` (read-only `acme-export.sh`) |

On first boot Stalwart generates its own configuration under `/var/lib/stalwart`; manage settings through the web admin afterwards.

## First boot

1. `docker compose up -d emsvcmailsrv`
2. Open `https://${EMAIL_HOST}` (from a trusted IP) and create the admin account.
3. Create mailbox accounts; other stack components send mail using `${EMAIL_USER}` / `${EMAIL_PASS}` over port `${EMAIL_PORT}` (see [Root README — Email](../../README.md#configuration)).

For external clients to reach ports 25/465/587/993, DNS `MX`/`A` records for `${EMAIL_HOST}` must point at the host.

## Operations

```bash
# Start / restart
docker compose up -d emsvcmailsrv

# Follow logs
docker compose logs -f emsvcmailsrv

# Inspect the exported certificate state
ls -l ${APPS_DATA}/mailbox/stalwart/tls/
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build — upstream image + curl/jq/inotify-tools for the cert watch tooling |
| [`config.json`](config.json) | Minimal Stalwart override (SQLite store path baked in) |
| [`entrypoint.sh`](entrypoint.sh) | Bootstrap certificate creation, drops privileges to uid/gid 2000, starts the export watcher |
| [`acme-export.sh`](acme-export.sh) | Extracts and installs the public certificate from Traefik's `acme.json` |

## See also

- [Bulwark Webmail](../bulwark/README.md) — JMAP webmail client for this server
- [Traefik](../traefik/README.md) — edge routing and TLS termination
- [Root README — Email stack](../../README.md#email-stack-emsvc)
