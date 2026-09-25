# Confluence — ServiceHub

> Atlassian Confluence Data Center as the team wiki / CMS homepage (the default homepage).

## Overview

[Confluence](https://www.atlassian.com/software/confluence) runs as a custom Data Center image and serves `WBHOME_DOMAIN` plus the apex `${DOMAIN_NAME}`. It is defined by the `wbappcmshome` service in [`compose/wbapp.yml`](../../compose/wbapp.yml) and built from [`shared/confluence/Dockerfile`](Dockerfile) (`FROM atlassian/confluence:${IMAGE_TAG}`).

Confluence is the default homepage and is backed by [PostgreSQL](../postgresql/README.md).

## Service details

| Detail | Value |
|---|---|
| Service name | `wbappcmshome` |
| Compose file | `compose/wbapp.yml` |
| URL | `https://${WBHOME_DOMAIN}` and `https://${DOMAIN_NAME}` (apex) |
| Internal port | 8090 (Tomcat; TLS terminated by Traefik) |
| Database | PostgreSQL (`${WBHOME_DBNAME}`) |
| Data persistence | `${APPS_DATA}/webapps/confluence` (mounted at `/var/atlassian/application-data/confluence`) |
| Image tag | `WBHOME_TAG` (default `10.2`) |
| JVM memory | `JVM_MINIMUM_MEMORY=1024m` / `JVM_MAXIMUM_MEMORY=3072m` |
| Middleware | `wbappcmshome-compress` (Traefik gzip compression) |
| Image extras | Java agent (`com.custom.confluence.mcp.connector`) plus SAML SSO, Draw.io, Table Filter, Questions and Aura (formatting) plugins |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `WBHOME_DOMAIN` | Homepage hostname (default `www.${DOMAIN_NAME}`) |
| `WBHOME_DBNAME` | PostgreSQL database name (must be in `PGRSQL_DBLIST`) |
| `WBHOME_TAG` | Confluence image tag passed to the Dockerfile as `IMAGE_TAG` |
| `SQLDB_USER` / `SQLDB_PASS` | Shared PostgreSQL credentials |
| `PGRSQL_HOST` / `PGRSQL_PORT` | PostgreSQL connection target (`dbsvcpgsqldb:5432`) |
| `APPS_DATA` | Host path for the data bind mount |
| `TIME_ZONE` | Container timezone |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `ATL_PROXY_NAME` | `${WBHOME_DOMAIN}` | Public proxy hostname |
| `ATL_PROXY_PORT` | `443` | Public proxy port |
| `ATL_TOMCAT_SCHEME` | `https` | External scheme seen by Confluence |
| `ATL_DB_TYPE` / `ATL_JDBC_URL` | `postgresql` / `jdbc:postgresql://.../${WBHOME_DBNAME}` | Database backend |
| `ATL_JDBC_USER` / `ATL_JDBC_PASSWORD` | `${SQLDB_USER}` / `${SQLDB_PASS}` | Database credentials |

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/atlassian/application-data/confluence` | `${APPS_DATA}/webapps/confluence` | Confluence home, attachments, indexes and configuration |

## Setup (first boot)

1. Start Confluence (with Traefik and PostgreSQL healthy):

    ```bash
    docker compose up -d wbappcmshome
    ```

2. Open `https://${WBHOME_DOMAIN}` and complete the setup wizard, pointing it at the
   PostgreSQL database and credentials configured above.
3. Apply the bundled license/plugin activation. The Java agent and plugins are baked
   into the image; activation details are intentionally not stored in this repository.

## Operations

```bash
# Start / restart
docker compose up -d wbappcmshome

# Rebuild after a Dockerfile or plugin change
docker compose up -d --build wbappcmshome

# Follow logs
docker compose logs -f wbappcmshome
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM atlassian/confluence:${IMAGE_TAG}`) + plugin/agent install |
| [`plugins/`](plugins/) | Local plugin tarballs copied into the image |

## See also

- [PostgreSQL](../postgresql/README.md) — database backend
- [Traefik](../traefik/README.md) — edge routing and TLS
- [Root README — Homepage](../../README.md#homepage)
