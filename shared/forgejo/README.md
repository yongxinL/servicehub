# Forgejo — ServiceHub

> Self-hosted Git service: repositories, issues, pull requests and the webhook API consumed by Woodpecker CI.

## Overview

[Forgejo](https://forgejo.org/) is a community fork of Gitea and the source-control host for the stack. It is defined by the `devopgitserv` service in [`compose/devop.yml`](../../compose/devop.yml) and built from [`shared/forgejo/server/Dockerfile`](server/Dockerfile) (`FROM codeberg.org/forgejo/forgejo:${IMAGE_TAG}`).

Woodpecker CI integrates with it over OAuth2 + webhooks — see [Woodpecker](../woodpecker/README.md).

## Service details

| Detail | Value |
|---|---|
| Service name | `devopgitserv` |
| Compose file | `compose/devop.yml` |
| URL | `https://${GITREPO_DOMAIN}` |
| Internal port | 3000 (published through Traefik) |
| Database | PostgreSQL (`${GITREPO_DBNAME}`) |
| Data persistence | `${APPS_DATA}/devops/repos` (mounted at `/data`) |
| Image tag | `GITREPO_VTAG` (default `16`) |
| Volume ownership | `1000:1000` (normally by `devopbldinit`) |
| Health check | `curl -fsS http://localhost:3000/api/healthz` every 30 s (20 s startup delay) |
| Depends on | `devopbldinit` (completed), `routetraefik` (healthy), `dbsvcpgsqldb` (healthy) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `GITREPO_DOMAIN` | Forgejo hostname (e.g. `git.example.com`) |
| `GITREPO_DBNAME` | PostgreSQL database name (must be in `PGRSQL_DBLIST`) |
| `GITREPO_VTAG` | Forgejo image tag passed to the Dockerfile as `IMAGE_TAG` |
| `SQLDB_USER` / `SQLDB_PASS` | Shared PostgreSQL credentials |
| `PGRSQL_HOST` / `PGRSQL_PORT` | PostgreSQL connection target (`dbsvcpgsqldb:5432`) |
| `APPS_DATA` | Host path for the `/data` bind mount |
| `TIME_ZONE` | Container timezone |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `FORGEJO__server__DOMAIN` | `${GITREPO_DOMAIN}` | Hostname Forgejo reports in generated URLs |
| `FORGEJO__server__ROOT_URL` | `https://${GITREPO_DOMAIN}/` | Correct clone URLs, webhooks and OAuth redirects |
| `FORGEJO__server__DISABLE_SSH` | `true` | The SSH port is not published; only HTTPS clones are advertised |
| `FORGEJO__database__DB_TYPE` | `postgres` | PostgreSQL backend |
| `FORGEJO__openid__ENABLE_OPENID_SIGNIN` / `SIGNUP` | `false` | Local accounts only |
| `FORGEJO__webhook__ALLOWED_HOST_LIST` | `external,${GITBLD_DOMAIN}` | Allow Woodpecker webhook callbacks |

> Forgejo environment variables use the `FORGEJO__<section>__<key>` form (for example `FORGEJO__webhook__ALLOWED_HOST_LIST` maps to `[webhook] ALLOWED_HOST_LIST` in `app.ini`).

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/data` | `${APPS_DATA}/devops/repos` | Repositories, `app.ini`, avatars, attachments, LFS |

Forgejo runs as UID/GID `1000`. `devopbldinit` normalises ownership of the bind mount on every boot, so the directory can be created empty beforehand.

## Setup (first boot)

1. Start Forgejo (and its dependencies):

    ```bash
    docker compose up -d devopgitserv
    ```

2. Open `https://${GITREPO_DOMAIN}` and complete the initial configuration, creating the first (admin) account.
3. Register the Woodpecker OAuth2 application — see [Woodpecker — Setup](../woodpecker/README.md#setup-first-boot). It is required before anyone can log in to Woodpecker.

## Operations

```bash
# Start / restart
docker compose up -d devopgitserv

# Rebuild after a Dockerfile change
docker compose up -d --build devopgitserv

# Follow logs
docker compose logs -f devopgitserv
```

### Reset (destructive)

```bash
docker compose down devopgitserv
rm -rf ${APPS_DATA}/devops/repos/*
docker compose up -d devopgitserv
```

> This deletes every repository and the Forgejo `app.ini`. The PostgreSQL database should be dropped/recreated as well.

## Files

| Path | Purpose |
|---|---|
| [`server/Dockerfile`](server/Dockerfile) | Image build (`FROM codeberg.org/forgejo/forgejo:${IMAGE_TAG}`) |

## See also

- [Woodpecker CI](../woodpecker/README.md) — CI server + agent backed by this forge
- [PostgreSQL](../postgresql/README.md) — database backend
- [Root README — Architecture](../../README.md#architecture-overview)
