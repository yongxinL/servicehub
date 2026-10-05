# Confluence — ServiceHub

> Atlassian Confluence Data Center as the team wiki / CMS homepage (the default homepage).

## Overview

[Confluence](https://www.atlassian.com/software/confluence) runs as a custom Data Center image and serves `WORKSPACE_DOMAIN` plus the apex `${DOMAIN_NAME}`. It is defined by the `webappconf` service in [`compose/webapp.yml`](../../compose/webapp.yml) and built from [`shared/confluence/Dockerfile`](Dockerfile) (`FROM atlassian/confluence:${IMAGE_TAG}`).

Confluence is the default homepage and is backed by [PostgreSQL](../postgresql/README.md).

## Service details

| Detail | Value |
|---|---|
| Service name | `webappconf` |
| Compose file | `compose/webapp.yml` |
| URL | `https://${WORKSPACE_DOMAIN}` and `https://${DOMAIN_NAME}` (apex) |
| Internal port | 8090 (Tomcat; TLS terminated by Traefik) |
| Database | PostgreSQL (`${WORKSPACE_DBNAME}`) |
| Data persistence | `${APPS_DATA}/webapp/confluence` (mounted at `/var/atlassian/application-data/confluence`) |
| Image tag | `WORKSPACE_TAG` (default `10.2`) |
| JVM memory | `JVM_MINIMUM_MEMORY=1024m` / `JVM_MAXIMUM_MEMORY=3072m` |
| Middleware | `webappconf-compress` (Traefik gzip compression) |
| Image extras | Java agent (`com.custom.confluence.mcp.connector`) plus SAML SSO, Draw.io, Table Filter, Questions and Aura (formatting) plugins |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `WORKSPACE_DOMAIN` | Homepage hostname (default `www.${DOMAIN_NAME}`) |
| `WORKSPACE_DBNAME` | PostgreSQL database name (must be in `POSTGRES_DATABASES`) |
| `WORKSPACE_TAG` | Confluence image tag passed to the Dockerfile as `IMAGE_TAG` |
| `DB_ADMIN_USER` / `DB_ADMIN_PASSWORD` | Shared PostgreSQL credentials |
| `POSTGRES_HOST` / `POSTGRES_PORT` | PostgreSQL connection target (`infrapgsql:5432`) |
| `APPS_DATA` | Host path for the data bind mount |
| `TIME_ZONE` | Container timezone |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `ATL_PROXY_NAME` | `${WORKSPACE_DOMAIN}` | Public proxy hostname |
| `ATL_PROXY_PORT` | `443` | Public proxy port |
| `ATL_TOMCAT_SCHEME` | `https` | External scheme seen by Confluence |
| `ATL_DB_TYPE` / `ATL_JDBC_URL` | `postgresql` / `jdbc:postgresql://.../${WORKSPACE_DBNAME}` | Database backend |
| `ATL_JDBC_USER` / `ATL_JDBC_PASSWORD` | `${DB_ADMIN_USER}` / `${DB_ADMIN_PASSWORD}` | Database credentials |

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/atlassian/application-data/confluence` | `${APPS_DATA}/webapp/confluence` | Confluence home, attachments, indexes and configuration |

## Setup (first boot)

1. Start Confluence (with Traefik and PostgreSQL healthy):

    ```bash
    docker compose up -d webappconf
    ```

2. Open `https://${WORKSPACE_DOMAIN}` and complete the setup wizard, pointing it at the
   PostgreSQL database and credentials configured above.
3. Apply the bundled license/plugin activation. The Java agent and plugins are baked
   into the image; activation details are intentionally not stored in this repository.

## Operations

```bash
# Start / restart
docker compose up -d webappconf

# Rebuild after a Dockerfile or plugin change
docker compose up -d --build webappconf

# Follow logs
docker compose logs -f webappconf
```

## Security hardening

- **Edge protection** — the router carries `secure-chain` (rate limit + security headers, before the compression middleware). See [Traefik — Security middlewares](../traefik/README.md#security-middlewares).
- **Admin console** — restrict the admin UI to trusted networks (Confluence Administration → General Configuration → **Security and Permissions** → admin session / network restrictions) and never leave anonymous access on a public space (Space Settings → Permissions → check *Anonymous* is off).
- **Delegate accounts to Authentik** — set up a SAML/OIDC user directory pointing at `infraauth` (Administration → User Management → User Directories) so passwords and MFA live in Authentik; keep one local `confluence-admin` as break-glass.

## Outbound egress policy

[ADR-009 §5](../../docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) treats Confluence as independent of Atlassian-hosted services. Outbound traffic is allowed only to approved dependency classes:

| Allowed | Purpose |
|---|---|
| PostgreSQL | Primary persistence |
| Authentik | Authentication and SSO |
| SMTP (Stalwart) | Outbound notifications |
| DNS | Name resolution |
| NTP | Time synchronisation |

Blocked by default: Atlassian Marketplace, Atlassian Cloud Services, migration services, application tunnels, and general internet access. Temporary outbound access may be granted for marketplace app install/upgrade, data migration, or approved maintenance, and must be removed as soon as the activity completes.

The allow list and exception procedure are still to be implemented and recorded in ADR-009 follow-up actions; blocked destinations should be logged during the initial observation period so unexpected app calls are surfaced.


## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM atlassian/confluence:${IMAGE_TAG}`) + plugin/agent install |
| [`plugins/`](plugins/) | Local plugin tarballs copied into the image |

## See also

- [PostgreSQL](../postgresql/README.md) — database backend
- [Traefik](../traefik/README.md) — edge routing and TLS
- [Root README — Homepage](../../README.md#homepage)
