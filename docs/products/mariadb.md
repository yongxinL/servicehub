# MariaDB — ServiceHub

> MySQL-compatible relational database, unused by the default stack.

## Overview

[MariaDB 11.8](https://mariadb.org/) provides a MySQL-compatible relational database. It is defined by the `inframariadb` service in [`compose/infra.yml`](../../compose/infra.yml) and built from [`shared/mariadb/Dockerfile`](../../shared/mariadb/Dockerfile) (`FROM mariadb:11.8`).

> **Note:** No service in the default stack uses MariaDB — Authentik, Forgejo, LiteLLM and Confluence all use [PostgreSQL](postgresql.md). The service is kept available for future MySQL-backed services; leave `MARIADB_DATABASES` empty if you don't need it.

## Service details

| Detail | Value |
|---|---|
| Service name | `inframariadb` |
| Internal port | 3306 (not published to the host) |
| Data persistence | `${APPS_DATA}/infra/mariadb` |
| Health check | `healthcheck.sh --connect --innodb_initialized` every 10 s |
| Init script | [`create-multiple-databases.sh`](../../shared/mariadb/create-multiple-databases.sh) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `DB_ADMIN_USER` | Shared username created as the superuser |
| `DB_ADMIN_PASSWORD` | Password for `DB_ADMIN_USER` (also used as the root password) |
| `MARIADB_DATABASES` | Comma-separated databases to create on first start (default: `${WORKSPACE_DBNAME}`) |
| `MARIADB_HOST` / `MARIADB_PORT` | In-network connection target exposed to other services (`inframariadb:3306`) |

## Multiple databases

[`create-multiple-databases.sh`](../../shared/mariadb/create-multiple-databases.sh) is copied to `/docker-entrypoint-initdb.d/` and runs **only on first initialisation** of an empty data directory. For each entry in `MARIADB_DATABASES` (comma-separated) it runs:

```sql
CREATE DATABASE IF NOT EXISTS `<name>`;
GRANT ALL ON `<name>`.* TO '<DB_ADMIN_USER>'@'%';
```

Example:

```bash
MARIADB_DATABASES="appdb,analytics"
```

> The script only runs when `${APPS_DATA}/infra/mariadb` is empty. To re-run it on an existing database, you must reset the data directory (see below).

## Connecting from another container

Other services on the `subnet` network connect with the hostname and port:

```
host: ${MARIADB_HOST}   # inframariadb
port: ${MARIADB_PORT}   # 3306
user: ${DB_ADMIN_USER}
pass: ${DB_ADMIN_PASSWORD}
```

## Operations

```bash
# Start / restart
docker compose up -d inframariadb

# Follow logs
docker compose logs -f inframariadb

# Open a SQL shell inside the container
docker compose exec inframariadb mariadb -u"${DB_ADMIN_USER}" -p
```

### Reset the database

To wipe all data and re-run the init script (this also deletes every database):

```bash
docker compose down inframariadb
rm -rf ${APPS_DATA}/infra/mariadb/*
docker compose up -d inframariadb
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../shared/mariadb/Dockerfile) | Image build (`FROM mariadb:11.8`) + init script copy |
| [`create-multiple-databases.sh`](../../shared/mariadb/create-multiple-databases.sh) | First-boot database/bootstrap script |

## See also

- [PostgreSQL](postgresql.md) — the primary database in this stack
- [Root README — Configuration](../../README.md#configuration)
