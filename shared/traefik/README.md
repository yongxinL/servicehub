# Traefik — ServiceHub

> Edge reverse proxy and TLS terminator: the single entry point for every inbound request.

## Overview

[Traefik v3](https://traefik.io/) is the edge router for the whole stack. It listens on ports 80/443, forces the HTTP → HTTPS redirect, discovers the rest of the stack through Docker container labels, and terminates TLS with either Let's Encrypt (production) or a self-signed certificate (staging).

It is defined by the `routetraefik` service in [`compose/route.yml`](../../compose/route.yml) and built from the [`shared/traefik/Dockerfile`](Dockerfile) (`FROM traefik:latest`).

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
| ACME store | `${APPS_DATA}/certs/acme.json` (mounted at `/letsencrypt`) |
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

### Dashboard basic auth

Generate the `TRAEFIK_BAAUTH` value with `htpasswd`. In the `.env` file every `$` must be escaped (the compose file uses `$` for interpolation):

```bash
echo $(htpasswd -nb admin "your-password") | sed -e 's/\$/\\$/g'
```

Paste the result into `TRAEFIK_BAAUTH`. The dashboard router chains three middlewares:

```
secure-chain  →  dashboard-whitelist  →  dashboard-auth
```

- `secure-chain` — security headers + rate limit (see [Security middlewares](#security-middlewares))
- `dashboard-whitelist` — `ipallowlist` restricted to `${TRUSTED_IP}`
- `dashboard-auth` — `basicauth` using `${TRAEFIK_BAAUTH}`

> **Note:** The IP allowlist and Authentik forward-auth are mutually exclusive. When you enable `authentik-forwardauth@file`, drop `dashboard-whitelist` from the chain.

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

`CERTRESOLVER=letsencrypt` activates the ACME resolver (TLS challenge). Certificates are stored in `${APPS_DATA}/certs/acme.json`. Traefik creates the file on first successful issuance; make sure its permissions are locked down afterwards:

```bash
chmod 600 ${APPS_DATA}/certs/acme.json
```

On remote deploys the file is restored from the `PROD_B64ENC_ACME` Forgejo Actions secret — see the root [Deployment (Forgejo Actions)](../../README.md#deployment-forgejo-actions).

### Staging — self-signed

Set `CERTRESOLVER=` (empty) so routers fall back to the default certificate. The certificate files live in [`advanced/selfsigncert/`](advanced/selfsigncert/) and are referenced by [`advanced/certificates.yml`](advanced/certificates.yml):

```yaml
tls:
    stores:
        default:
            defaultCertificate:
                certFile: /traefik/config/advanced/selfsigncert/selfcert.pem
                keyFile: /traefik/config/advanced/selfsigncert/selfcert.key
```

The cert/key/CA files are encrypted with **git-crypt** before being committed. See the root [Managing Encrypted Files](../../README.md#managing-encrypted-files-git-crypt) for the full workflow.

## Middlewares

Dynamic configuration lives in `advanced/` and is loaded by the file provider.

| File | Provides |
|---|---|
| [`advanced/middlewares-authentik.yml`](advanced/middlewares-authentik.yml) | `authentik-forwardauth` — forward-auth to `authnservice:9000` (Authentik outpost) |
| [`advanced/middlewares-security.yml`](advanced/middlewares-security.yml) | `secure-chain` — security headers + rate limit, applied to every router |
| [`advanced/certificates.yml`](advanced/certificates.yml) | Default self-signed TLS certificate store |
| [`advanced/metrics.yml`](advanced/metrics.yml) | Prometheus metrics (entrypoint/service labels + `client_ip` header label) |

### Security middlewares

[`advanced/middlewares-security.yml`](advanced/middlewares-security.yml) defines the stack-wide baseline, applied as the **first** middleware on every `websecure` router:

- **`secure-chain`** — convenience chain composing the two below, so routers list one middleware.
- **`secure-headers`** — HSTS (180 days, includeSubDomains, preload), `X-Content-Type-Options: nosniff`, `Referrer-Policy: same-origin`, `X-Frame-Options: SAMEORIGIN`, and `Server`/`X-Powered-By` header stripping. No CSP here — it breaks inline-script apps (Confluence, Open WebUI); add per-app if ever needed.
- **`rate-limit`** — 20 req/s average, 50 burst, per client IP. Blunts credential-stuffing against every login page at once. Tune down (or split per-service) if a legitimate workflow trips it.

To protect a router with Authentik forward-auth, add the file middleware **after** `secure-chain`:

```yaml
- "traefik.http.routers.myapp.middlewares=secure-chain,authentik-forwardauth@file"
```

The Authentik outpost must be configured first — see [`shared/authentik/README.md`](../authentik/README.md).

## Observability

- **Metrics** — Prometheus exporter enabled (`--metrics.prometheus=true`) with entrypoint/service labels. [`advanced/metrics.yml`](advanced/metrics.yml) adds a `client_ip` label from `X-Forwarded-For`. Grafana Alloy scrapes `routetraefik:8080`.
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
| [`Dockerfile`](Dockerfile) | Image build (`FROM traefik:latest`) |
| [`advanced/certificates.yml`](advanced/certificates.yml) | Self-signed default certificate store |
| [`advanced/middlewares-authentik.yml`](advanced/middlewares-authentik.yml) | Authentik forward-auth middleware |
| [`advanced/middlewares-security.yml`](advanced/middlewares-security.yml) | Security headers + rate limit (`secure-chain`) |
| [`advanced/metrics.yml`](advanced/metrics.yml) | Prometheus metrics configuration |
| [`advanced/selfsigncert/`](advanced/selfsigncert/) | git-crypt encrypted staging certificates |

## See also

- [Root README — Architecture](../../README.md#architecture-overview)
- [Root README — Managing Encrypted Files](../../README.md#managing-encrypted-files-git-crypt)
- [Authentik](../authentik/README.md) — forward-auth IdP
- [oCIS](../owncloud/README.md) — long-transfer and encoded WebDAV route consumer
