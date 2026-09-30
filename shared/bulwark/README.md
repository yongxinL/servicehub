# Bulwark Webmail — ServiceHub

> Self-hosted JMAP webmail client for Stalwart Mail Server (Next.js).

## Overview

[Bulwark](https://github.com/bulwarkmail/webmail) provides the web UI for the ServiceHub email domain (`poste`): mail, calendar, contacts and files over JMAP against [Stalwart](../stalwart/README.md). It is defined by the `postewebmail` service in [`compose/poste.yml`](../../compose/poste.yml) and built from [`Dockerfile`](Dockerfile) (`FROM ghcr.io/bulwarkmail/webmail:${IMAGE_TAG}`). Upstream configuration reference: [Configuration](https://github.com/bulwarkmail/webmail#configuration).

## Service details

| Detail | Value |
|---|---|
| Service name | `postewebmail` |
| HTTP port | 3000, routed by Traefik at `https://${WEBMAIL_DOMAIN}` |
| JMAP backend | `https://${EMAIL_HOST}` — resolves via Docker DNS because `posteservice` sets its container hostname to `${EMAIL_HOST}` |
| Health check | Node HTTP check of `http://localhost:3000/api/health` every 30 s |
| Depends on | `postesvcinit` (completed) — creates/chowns the data dirs; `posteservice` (healthy) |
| Data persistence | `${APPS_DATA}/platform/webmail/...` |
| Volume ownership | `1001:1001` (`nextjs:nodejs`) — set by `postesvcinit` on every boot |
| Onboarding | Setup wizard on first launch unless `JMAP_SERVER_URL` is preset (it is, here) |

## Traefik routing

Traefik serves the webmail at `https://${WEBMAIL_DOMAIN}` with automatic TLS. It is a public-facing router — no IP allow-list or SSO middleware is applied at the Traefik level; authentication happens in the app itself or the configured IdP.

## Login prerequisites (Stalwart side)

For *any* sign-in — password form or OIDC — two Stalwart settings must hold:

1. **Permissive CORS** — the browser talks to Stalwart's JMAP endpoint cross-origin (webmail origin `${WEBMAIL_DOMAIN}`, JMAP origin `${EMAIL_HOST}`), so Stalwart must answer with CORS headers. Stalwart's setting is all-or-nothing: enable **Permissive CORS policy** (`usePermissiveCors`) under **Settings → Network → HTTP → Security**, then reload/restart Stalwart. Every JMAP endpoint requires authentication and the admin router is IP-allow-listed at Traefik, which keeps the exposure bounded. Origin-restricted CORS can instead be injected by a Traefik `headers` middleware on the `posteservice` router if permissive is not acceptable.
2. **Trusted certificate on Stalwart's HTTPS listener** — the webmail server checks `JMAP_SERVER_URL` itself (server-side), and the browser opens the JMAP session against it. `https://${EMAIL_HOST}` must (a) resolve inside the container network — `posteservice`'s hostname makes Docker DNS do this — and (b) serve the exported Let's Encrypt certificate via a Stalwart Certificate object (see [Stalwart — TLS certificates](../stalwart/README.md#tls-certificates)); the 2-day bootstrap self-signed cert fails server-side checks with `DEPTH_ZERO_SELF_SIGNED_CERT` in the container logs.

## Volume ownership

Bulwark's image runs as non-root `uid=1001 gid=1001` (`nextjs:nodejs`) and has no ownership-fixing entrypoint, so the host directories mounted at `/data/*` (`platform/webmail/{settings,admin,admin-state,telemetry}`) must be writable by `1001:1001`. The one-shot `postesvcinit` service (busybox — same pattern as [`depotsvcinit`](../forgejo/README.md)) creates the directories and `chown -R 1001:1001`s them on every boot, so they can be created empty beforehand. Wrong ownership shows as `EACCES` warnings on boot and breaks login (the auth session cannot be persisted).

## Configuration (env)

### Branding & integration

| Variable | Purpose |
|---|---|
| `APP_NAME` / `APP_SHORT_NAME` / `APP_DESCRIPTION` | Branding shown in the UI and PWA |
| `JMAP_SERVER_URL` | Stalwart endpoint the app connects to (`https://${EMAIL_HOST}`) |
| `STALWART_FEATURES` | Enables Stalwart-specific features (password change, Sieve UI, ...) — note: password change only works when Stalwart holds the password hashes (internal accounts); with the Authentik LDAP directory users change passwords in Authentik |
| `BULWARK_TELEMETRY` | `off` — telemetry locked off |

### SSO / OIDC (not used)

Bulwark supports OIDC single sign-on, but this stack does **not** use it: it only works when Stalwart's directory for the mail domain is an **OIDC** directory, while this stack uses **LDAP**. With an LDAP directory the OIDC flow gets tokens from the IdP fine and then fails when Stalwart rejects the IdP-issued bearer token at the JMAP endpoint (generic "Failed to complete authentication" — the token exchange itself succeeds). Users therefore sign in with the **password form** (email + Authentik password), validated by Stalwart, which binds to Authentik's LDAP outpost.

If you ever switch Stalwart to an OIDC directory, see upstream [Authentication](https://bulwarkmail.org/docs/getting-started/configuration/authentication) and [Embedded SSO](https://bulwarkmail.org/docs/guides/embedded-sso) for the full setup; note that settings saved through the admin dashboard live in `${ADMIN_CONFIG_DIR}` (`/data/admin`) and take precedence over environment variables.

### Sessions & state

| Variable | Purpose |
|---|---|
| `WEBMAIL_SESSION_SECRET` | Session cookie encryption — auto-generated by `scripts/setup.sh` |
| `SETTINGS_SYNC_ENABLED` | Per-account settings sync (encrypted at rest with `SESSION_SECRET`) |

### Data directories

| Variable | Host path |
|---|---|
| `SETTINGS_DATA_DIR=/data/settings` | `${APPS_DATA}/platform/webmail/settings` |
| `ADMIN_CONFIG_DIR=/data/admin` | `${APPS_DATA}/platform/webmail/admin` |
| `ADMIN_STATE_DIR=/data/admin-state` | `${APPS_DATA}/platform/webmail/admin-state` |
| `TELEMETRY_DATA_DIR=/data/telemetry` | `${APPS_DATA}/platform/webmail/telemetry` |

## First boot

1. `docker compose up -d postesvcinit postewebmail` (the init service creates/chowns the data dirs)
2. Open `https://${WEBMAIL_DOMAIN}` — users sign in with their email + Authentik password (see [Login prerequisites](#login-prerequisites-stalwart-side) for the required Stalwart-side CORS and certificate settings).

## Security hardening

- **Edge protection** — the router carries `secure-chain` (rate limit + security headers); the login form is throttled at Traefik. See [Traefik — Security middlewares](../traefik/README.md#security-middlewares).
- **Admin dashboard stays disabled** — no `ADMIN_PASSWORD` is set, so the dashboard never boots; do not add one unless needed.
- **`SESSION_SECRET`** — generated by `setup.sh`, lives only in `.env`; rotating it signs every user out.

## Operations

```bash
# Start / restart
docker compose up -d postewebmail

# Follow logs
docker compose logs -f postewebmail
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM ghcr.io/bulwarkmail/webmail:${IMAGE_TAG}`) |

## See also

- [Stalwart Mail Server](../stalwart/README.md) — the JMAP backend this client talks to
- [Authentik](../authentik/README.md) — IdP; serves the LDAP directory behind all webmail/IMAP/SMTP logins
- [Traefik](../traefik/README.md) — edge routing and TLS termination
- [Root README — Email stack](../../README.md#email-stack-poste)
