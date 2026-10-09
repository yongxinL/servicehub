# Traefik — ServiceHub

> Edge reverse proxy and TLS terminator: the single entry point for every inbound request.

## Overview

[Traefik v3](https://traefik.io/) is the edge router for the whole stack. It listens on ports 80/443, forces the HTTP → HTTPS redirect, discovers the rest of the stack through Docker container labels, and terminates TLS with either Let's Encrypt (production) or a self-signed certificate (staging).

It is defined by the `routetraefik` service in [`compose/route.yml`](../../compose/route.yml) and built from the [`shared/traefik/Dockerfile`](../../shared/traefik/Dockerfile) (`FROM traefik:latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `routetraefik` |
| Compose file | `compose/route.yml` |
| Image | built locally from `shared/traefik/` |
| HTTP port | 80 (redirects to HTTPS) |
| HTTPS port | 443 |
| Dashboard | `https://${TRAEFIK_DOMAIN}` |
| Dashboard auth | HTTP basic auth (`dashboard-auth`) + IP allowlist (`dashboard-whitelist`) + `secure-chain` |
| TLS (prod) | Let's Encrypt via ACME TLS challenge |
| TLS (stag) | Self-signed certificate from `advanced/selfsigncert/` |
| ACME store | `${APPS_DATA}/shared/certs/acme.json` (mounted at `/letsencrypt`) |
| Config directory | `/traefik/config/advanced` (mounted read-only from `shared/traefik/advanced/`) |
| Health check | `traefik healthcheck --ping` every 60 s |
| Logs | Access logs in JSON format (consumed by Grafana Alloy → VictoriaLogs) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `TRAEFIK_DOMAIN` | Hostname for the Traefik dashboard (e.g. `traefik.example.com`) |
| `TRAEFIK_ACMEMAIL` | Email registered with Let's Encrypt for renewal notices |
| `TRAEFIK_BAAUTH` | Dashboard basic-auth pair in htpasswd format (`user:$apr1$...`) |
| `CERTRESOLVER` | `letsencrypt` for ACME, empty for the self-signed certificate |
| `TRUSTED_IP` | CIDR ranges trusted for forwarded headers (`X-Forwarded-For`) and the dashboard IP allowlist |
| `APPS_DATA` | Host path mounted at `/letsencrypt` for the ACME store |
| `TIME_ZONE` | Container timezone |

### Dashboard basic auth and admin access rules

Generate the `TRAEFIK_BAAUTH` value with `htpasswd` and paste it into `.env` (legacy `\$`-escaped values are understood by the generator):

```bash
echo $(htpasswd -nb admin "your-password")
```

The admin access rules are **not** compose labels. `scripts/setup.sh` runs [`scripts/gen-admin-rules.py`](../../scripts/gen-admin-rules.py), which writes `advanced/admin-routers.yml` from `.env` (`DOMAIN_NAME` via the `${DOMAIN_NAME}`-derived `TRAEFIK_DOMAIN`, `EMAIL_HOST` and `IDENTITY_DOMAIN`, plus `TRUSTED_IP`, `CERTRESOLVER`, `TRAEFIK_BAAUTH`). Traefik's file provider watches the directory (`--providers.file.watch=true`) and hot-reloads within seconds — changing trusted IPs or the domain never restarts a container. The generated file is git-ignored because it embeds the basic-auth hash.

> **Changing `DOMAIN_NAME`:** edit `DOMAIN_NAME` in `.env` and run `bash scripts/setup.sh` — the generator re-resolves the Host rules and reports the hosts it wrote (e.g. `dashboard=traefik.example.com`). This only works while `TRAEFIK_DOMAIN` / `EMAIL_HOST` / `IDENTITY_DOMAIN` keep their `...${DOMAIN_NAME}` reference form; a literal value (e.g. `traefik.old.example`) does not move with the domain, and the generator prints a note when it detects one.

The dashboard (and the Stalwart admin paths, which follow the same pattern) is protected by two routers (ADR-009):

| Router | Rule | Priority | Middleware chain |
|---|---|---|---|
| `dashboard` | `Host` **and** trusted `ClientIP(...)` ranges | 300 | `secure-chain` -> `dashboard-whitelist` -> `dashboard-auth` |
| `dashboard-untrusted` | `Host` only (any other client) | 100 | `secure-chain` -> `dashboard-login-redirect` |

- `secure-chain` — security headers + rate limit (see [Security middlewares](#security-middlewares))
- `dashboard-whitelist` — `ipallowlist` restricted to `TRUSTED_IP` (defence in depth behind the `ClientIP` rule)
- `dashboard-auth` — `basicauth` using `TRAEFIK_BAAUTH`
- `dashboard-login-redirect` — `redirectregex` sending unauthorised clients to `https://${IDENTITY_DOMAIN}` instead of an HTTP 403; it short-circuits before the service is reached and grants no access

> **Changing trusted IPs:** edit `TRUSTED_IP` in `.env`, then run `bash scripts/setup.sh` (or `python3 scripts/gen-admin-rules.py` alone) — Traefik reloads without a restart. If `TRUSTED_IP` is empty the trusted admin routers are omitted entirely, so admin endpoints only redirect (fail closed). The entrypoint `forwardedHeaders.trustedIPs=${TRUSTED_IP}` flag is static Traefik configuration and only refreshes when `routetraefik` is next recreated.

> **One-time for this change:** the first deploy recreates `routetraefik` once to enable file watching and drop the old label-based admin routers; every change after that is hot-reloaded.

> **Note:** The IP allowlist and Authentik forward-auth are mutually exclusive. When you enable `authentik-forwardauth@file`, drop `dashboard-whitelist` from the chain in `scripts/gen-admin-rules.py` and regenerate.

## Routing

Services opt into routing by setting Docker labels; `--providers.docker.exposedbydefault=false` means nothing is published unless it declares `traefik.enable=true`. A typical service exposes a router (host rule, entrypoint `websecure`, TLS + certresolver) and a service (container port), for example:

```yaml
labels:
    - "traefik.enable=true"
    - "traefik.http.routers.myapp.entrypoints=websecure"
    - "traefik.http.routers.myapp.rule=Host(`${MYAPP_DOMAIN}`)"
    - "traefik.http.routers.myapp.tls=true"
    # Rate limit + security headers — required on every router
    - "traefik.http.routers.myapp.middlewares=secure-chain@file"
    - "traefik.http.routers.myapp.tls.certresolver=${CERTRESOLVER}"
    - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

**Every `websecure` router must include `secure-chain`** as the first middleware (all stack routers do — dashboards, IdP, git, wiki, webmail, chat, observability). It is the stack-wide baseline; extra middlewares (IP allowlist, forward-auth, compress) follow it in the chain.

### Long transfers and encoded paths

`compose/route.yml` sets the `websecure` responding read and write timeouts to 12 hours so large uploads and downloads are not cut off by Traefik. The idle timeout remains 3 minutes. It also enables encoded slash, question-mark, and percent characters for WebDAV and oCIS path handling.

These are entry-point-wide settings. Review their impact on slow clients and connection retention before changing them, and rebuild `routetraefik` after modifying `compose/route.yml`.

## TLS

### Production — Let's Encrypt

`CERTRESOLVER=letsencrypt` activates the ACME resolver (TLS challenge). Certificates are stored in `${APPS_DATA}/shared/certs/acme.json`. Traefik creates the file on first successful issuance; make sure its permissions are locked down afterwards:

```bash
chmod 600 ${APPS_DATA}/shared/certs/acme.json
```

On remote deploys the file is restored from the `PROD_B64ENC_ACME` Forgejo Actions secret — see the root [Deployment guide](../operations/DEPLOYMENT.md).

### Staging — self-signed

Set `CERTRESOLVER=` (empty) so routers fall back to the default certificate. The certificate files live in [`advanced/selfsigncert/`](../../shared/traefik/advanced/selfsigncert/) and are referenced by [`advanced/certificates.yml`](../../shared/traefik/advanced/certificates.yml):

```yaml
tls:
    stores:
        default:
            defaultCertificate:
                certFile: /traefik/config/advanced/selfsigncert/selfcert.pem
                keyFile: /traefik/config/advanced/selfsigncert/selfcert.key
```

The cert/key/CA files are encrypted with **git-crypt** before being committed. See the root [Managing Encrypted Files](../operations/DEVELOPMENT.md#managing-encrypted-files-git-crypt) for the full workflow.

## Middlewares

Dynamic configuration lives in `advanced/` and is loaded by the file provider.

| File | Provides |
|---|---|
| [`advanced/middlewares-authentik.yml`](../../shared/traefik/advanced/middlewares-authentik.yml) | `authentik-forwardauth` — forward-auth to `infraauth:9000` (Authentik outpost) |
| [`advanced/middlewares-security.yml`](../../shared/traefik/advanced/middlewares-security.yml) | `secure-chain` — security headers + rate limit, applied to every router |
| [`advanced/certificates.yml`](../../shared/traefik/advanced/certificates.yml) | Default self-signed TLS certificate store |
| [`advanced/metrics.yml`](../../shared/traefik/advanced/metrics.yml) | Prometheus metrics (entrypoint/service labels + `client_ip` header label) |

### Security middlewares

[`advanced/middlewares-security.yml`](../../shared/traefik/advanced/middlewares-security.yml) defines the stack-wide baseline, applied as the **first** middleware on every `websecure` router:

- **`secure-chain`** — convenience chain composing the two below, so routers list one middleware.
- **`secure-headers`** — HSTS (180 days, includeSubDomains, preload), `X-Content-Type-Options: nosniff`, `Referrer-Policy: same-origin`, `X-Frame-Options: SAMEORIGIN`, and `Server`/`X-Powered-By` header stripping. No CSP here — it breaks inline-script apps (Confluence, Open WebUI); add per-app if ever needed.
- **`rate-limit`** — 20 req/s average, 50 burst, per client IP. Blunts credential-stuffing against every login page at once. Tune down (or split per-service) if a legitimate workflow trips it.
  - **Exemption:** the identity domain `/static/` prefix is served by router `infraauth-static` (`compose/infra.yml`, priority 200, `secure-headers` only) so Authentik's admin SPA chunk loads cannot exhaust the burst bucket and fail with 429s. Documented in [TROUBLESHOOTING](../../docs/operations/TROUBLESHOOTING.md#identity-console-rate-limited-429).

To protect a router with Authentik forward-auth, add the file middleware **after** `secure-chain`:

```yaml
- "traefik.http.routers.myapp.middlewares=secure-chain,authentik-forwardauth@file"
```

The Authentik outpost must be configured first — see [`authentik.md`](authentik.md).

## Observability

- **Metrics** — Prometheus exporter enabled (`--metrics.prometheus=true`) with entrypoint/service labels. [`advanced/metrics.yml`](../../shared/traefik/advanced/metrics.yml) adds a `client_ip` label from `X-Forwarded-For`. Grafana Alloy scrapes `routetraefik:8080`.
- **Access logs** — JSON format (`--accesslog=true --accesslog.format=json`), collected by Grafana Alloy and stored in VictoriaLogs.

## Operations

```bash
# Rebuild and restart after a config change
docker compose up -d --build routetraefik

# Follow logs
docker compose logs -f routetraefik

# Validate the running configuration (dashboard) at https://${TRAEFIK_DOMAIN}
```

> **Changing `compose/route.yml`:** the command-line flags are baked into the service definition, so a config change requires `up -d --build`. File-provider changes under `advanced/` are picked up automatically.

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../shared/traefik/Dockerfile) | Image build (`FROM traefik:latest`) |
| [`advanced/certificates.yml`](../../shared/traefik/advanced/certificates.yml) | Self-signed default certificate store |
| [`advanced/middlewares-authentik.yml`](../../shared/traefik/advanced/middlewares-authentik.yml) | Authentik forward-auth middleware |
| [`advanced/middlewares-security.yml`](../../shared/traefik/advanced/middlewares-security.yml) | Security headers + rate limit (`secure-chain`) |
| [`advanced/metrics.yml`](../../shared/traefik/advanced/metrics.yml) | Prometheus metrics configuration |
| [`advanced/selfsigncert/`](../../shared/traefik/advanced/selfsigncert/) | git-crypt encrypted staging certificates |

## See also

- [Root README — Architecture](../../README.md#architecture-overview)
- [Managing Encrypted Files](../operations/DEVELOPMENT.md#managing-encrypted-files-git-crypt)
- [Authentik](authentik.md) — forward-auth IdP
- [oCIS](owncloud.md) — long-transfer and encoded WebDAV route consumer
