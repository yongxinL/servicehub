# PostgreSQL — ServiceHub

> The primary relational database for Authentik, Forgejo, LiteLLM and Confluence.

## Overview

[PostgreSQL 16](https://www.postgresql.org/) is the primary relational database in the stack. It is defined by the `infrapgsql` service in [`compose/infra.yml`](../../compose/infra.yml) and built from [`shared/postgresql/Dockerfile`](../../shared/postgresql/Dockerfile) (`FROM postgres:16-alpine`).

## Service details

| Detail | Value |
|---|---|
| Service name | `infrapgsql` |
| Internal port | 5432 (not published to the host) |
| Data persistence | `${APPS_DATA}/infra/postgresql` |
| Health check | `pg_isready` every 30 s (20 s startup delay, 5 retries) |
| Shared memory | `shm_size: 128mb` |
| Init script | [`create-multiple-databases.sh`](../../shared/postgresql/create-multiple-databases.sh) |

### Consumers

| Service | Database variable |
|---|---|
| Authentik (`infraauth` / `infraauthwrk`) | `IDENTITY_DBNAME` |
| Forgejo (`devopsforgejo`) | `SOURCECODE_DBNAME` |
| LiteLLM (`aiservlitellm`) | `AIGATE_DBNAME` |
| Confluence (`webappconf`, default homepage) | `WORKSPACE_DBNAME` |
| Stalwart (`mailsvstalwart`) | `POSTOFFICE_DBNAME` — sole mail data store (accounts, messages, indexes, blobs) |

`webappocis` (oCIS) is **not** a PostgreSQL consumer. It uses local configuration and file storage under `${APPS_DATA}/webapp/ocis`; PostgreSQL still holds the Authentik identity data used by the oCIS OIDC flow.

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `DB_ADMIN_USER` | Shared username created as the superuser |
| `DB_ADMIN_PASSWORD` | Password for `DB_ADMIN_USER` |
| `POSTGRES_DATABASES` | Comma-separated databases to create on first start |
| `POSTGRES_HOST` / `POSTGRES_PORT` | In-network connection target exposed to other services (`infrapgsql:5432`) |

The default `POSTGRES_DATABASES` creates every service database:

```bash
POSTGRES_DATABASES="${IDENTITY_DBNAME},${SOURCECODE_DBNAME},${AIGATE_DBNAME},${WORKSPACE_DBNAME},${POSTOFFICE_DBNAME}"
```

## Multiple databases

[`create-multiple-databases.sh`](../../shared/postgresql/create-multiple-databases.sh) is copied to `/docker-entrypoint-initdb.d/` and runs **only on first initialisation** of an empty data directory. For each entry in `POSTGRES_DATABASES` it creates the database if it does not exist and grants privileges to `POSTGRES_USER`.

> The script only runs when `${APPS_DATA}/infra/postgresql` is empty. To re-run it on an existing cluster, you must reset the data directory (see below).

## Connecting from another container

Other services on the `subnet` network connect with the hostname and port. The standard DSN form is:

```
postgresql://${DB_ADMIN_USER}:${DB_ADMIN_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${DBNAME}
```

LiteLLM, for example, uses it directly:

```yaml
- DATABASE_URL=postgresql://${DB_ADMIN_USER}:${DB_ADMIN_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${AIGATE_DBNAME}
```

## Operations

```bash
# Start / restart
docker compose up -d infrapgsql

# Follow logs
docker compose logs -f infrapgsql

# Open a psql shell inside the container
docker compose exec infrapgsql psql -U "${DB_ADMIN_USER}"
```

### List databases

```bash
docker compose exec infrapgsql psql -U "${DB_ADMIN_USER}" -c "\l"
```

### Reset the database

To wipe all data and re-run the init script (this also deletes every database):

```bash
docker compose down infrapgsql
rm -rf ${APPS_DATA}/infra/postgresql/*
docker compose up -d infrapgsql
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../shared/postgresql/Dockerfile) | Image build (`FROM postgres:16-alpine`) + init script copy |
| [`create-multiple-databases.sh`](../../shared/postgresql/create-multiple-databases.sh) | First-boot database bootstrap script |

## See also

- [Root README — Data Backups](../../README.md#data-backups-forgejo-actions) — the scheduled Forgejo workflow takes daily `pg_dump` backups of every database (6-month retention) and a weekly `APPS_DATA` archive
- [Stalwart — Database management](stalwart.md#database-management-create--delete--backup--restore) — worked create/drop/`pg_dump`/`pg_restore` example
- [MariaDB](mariadb.md) — MySQL-compatible alternative (unused by default)
- [Root README — Configuration](../../README.md#configuration)
