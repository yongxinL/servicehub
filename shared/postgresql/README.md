# PostgreSQL — ServiceHub

> The primary relational database for Authentik, Forgejo, LiteLLM and Confluence.

## Overview

[PostgreSQL 16](https://www.postgresql.org/) is the primary relational database in the stack. It is defined by the `infrapgsql` service in [`compose/infra.yml`](../../compose/infra.yml) and built from [`shared/postgresql/Dockerfile`](Dockerfile) (`FROM postgres:16-alpine`).

## Service details

| Detail | Value |
|---|---|
| Service name | `infrapgsql` |
| Internal port | 5432 (not published to the host) |
| Data persistence | `${APPS_DATA}/infra/postgresql` |
| Health check | `pg_isready` every 30 s (20 s startup delay, 5 retries) |
| Shared memory | `shm_size: 128mb` |
| Init script | [`create-multiple-databases.sh`](create-multiple-databases.sh) |

### Consumers

| Service | Database variable |
|---|---|
| Authentik (`infraauth` / `infraauthwrk`) | `AUTHN_DBNAME` |
| Forgejo (`devopsforgejo`) | `DEPOT_DBNAME` |
| LiteLLM (`aiservlitellm`) | `LITEM_DBNAME` |
| Confluence (`webappconf`, default homepage) | `WBHOME_DBNAME` |
| Stalwart (`mailsvstalwart`) | `POSTE_DBNAME` — sole mail data store (accounts, messages, indexes, blobs) |

`webappocis` (oCIS) is **not** a PostgreSQL consumer. It uses local configuration and file storage under `${APPS_DATA}/webapp/ocis`; PostgreSQL still holds the Authentik identity data used by the oCIS OIDC flow.

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `SQLDB_USER` | Shared username created as the superuser |
| `SQLDB_PASS` | Password for `SQLDB_USER` |
| `PGRSQL_DBLIST` | Comma-separated databases to create on first start |
| `PGRSQL_HOST` / `PGRSQL_PORT` | In-network connection target exposed to other services (`infrapgsql:5432`) |

The default `PGRSQL_DBLIST` creates every service database:

```bash
PGRSQL_DBLIST="${AUTHN_DBNAME},${DEPOT_DBNAME},${LITEM_DBNAME},${WBHOME_DBNAME},${POSTE_DBNAME}"
```

## Multiple databases

[`create-multiple-databases.sh`](create-multiple-databases.sh) is copied to `/docker-entrypoint-initdb.d/` and runs **only on first initialisation** of an empty data directory. For each entry in `PGRSQL_DBLIST` it creates the database if it does not exist and grants privileges to `POSTGRES_USER`.

> The script only runs when `${APPS_DATA}/infra/postgresql` is empty. To re-run it on an existing cluster, you must reset the data directory (see below).

## Connecting from another container

Other services on the `subnet` network connect with the hostname and port. The standard DSN form is:

```
postgresql://${SQLDB_USER}:${SQLDB_PASS}@${PGRSQL_HOST}:${PGRSQL_PORT}/${DBNAME}
```

LiteLLM, for example, uses it directly:

```yaml
- DATABASE_URL=postgresql://${SQLDB_USER}:${SQLDB_PASS}@${PGRSQL_HOST}:${PGRSQL_PORT}/${LITEM_DBNAME}
```

## Operations

```bash
# Start / restart
docker compose up -d infrapgsql

# Follow logs
docker compose logs -f infrapgsql

# Open a psql shell inside the container
docker compose exec infrapgsql psql -U "${SQLDB_USER}"
```

### List databases

```bash
docker compose exec infrapgsql psql -U "${SQLDB_USER}" -c "\l"
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
| [`Dockerfile`](Dockerfile) | Image build (`FROM postgres:16-alpine`) + init script copy |
| [`create-multiple-databases.sh`](create-multiple-databases.sh) | First-boot database bootstrap script |

## See also

- [Root README — Data Backups](../../README.md#data-backups-forgejo-actions) — the scheduled Forgejo workflow takes daily `pg_dump` backups of every database (6-month retention) and a weekly `APPS_DATA` archive
- [Stalwart — Database management](../stalwart/README.md#database-management-create--delete--backup--restore) — worked create/drop/`pg_dump`/`pg_restore` example
- [MariaDB](../mariadb/README.md) — MySQL-compatible alternative (unused by default)
- [Root README — Configuration](../../README.md#configuration)
