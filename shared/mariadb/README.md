# MariaDB — ServiceHub

> MySQL-compatible relational database, unused by the default stack.

## Overview

[MariaDB 11.8](https://mariadb.org/) provides a MySQL-compatible relational database. It is defined by the `dbsvcmariadb` service in [`compose/dbsvc.yml`](../../compose/dbsvc.yml) and built from [`shared/mariadb/Dockerfile`](Dockerfile) (`FROM mariadb:11.8`).

> **Note:** No service in the default stack uses MariaDB — Authentik, Forgejo, LiteLLM and Confluence all use [PostgreSQL](../postgresql/README.md). The service is kept available for future MySQL-backed services; leave `MARIADB_DB_LIST` empty if you don't need it.

## Service details

| Detail | Value |
|---|---|
| Service name | `dbsvcmariadb` |
| Internal port | 3306 (not published to the host) |
| Data persistence | `${APPS_DATA}/databases/mariadb` |
| Health check | `healthcheck.sh --connect --innodb_initialized` every 10 s |
| Init script | [`create-multiple-databases.sh`](create-multiple-databases.sh) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `SQLDB_USER` | Shared username created as the superuser |
| `SQLDB_PASS` | Password for `SQLDB_USER` (also used as the root password) |
| `MARIADB_DB_LIST` | Comma-separated databases to create on first start (default: `${WBHOME_DBNAME}`) |
| `MySQL_HOST` / `MySQL_PORT` | In-network connection target exposed to other services (`dbsvcmariadb:3306`) |

## Multiple databases

[`create-multiple-databases.sh`](create-multiple-databases.sh) is copied to `/docker-entrypoint-initdb.d/` and runs **only on first initialisation** of an empty data directory. For each entry in `MARIADB_DB_LIST` (comma-separated) it runs:

```sql
CREATE DATABASE IF NOT EXISTS `<name>`;
GRANT ALL ON `<name>`.* TO '<SQLDB_USER>'@'%';
```

Example:

```bash
MARIADB_DB_LIST="appdb,analytics"
```

> The script only runs when `${APPS_DATA}/databases/mariadb` is empty. To re-run it on an existing database, you must reset the data directory (see below).

## Connecting from another container

Other services on the `subnet` network connect with the hostname and port:

```
host: ${MySQL_HOST}   # dbsvcmariadb
port: ${MySQL_PORT}   # 3306
user: ${SQLDB_USER}
pass: ${SQLDB_PASS}
```

## Operations

```bash
# Start / restart
docker compose up -d dbsvcmariadb

# Follow logs
docker compose logs -f dbsvcmariadb

# Open a SQL shell inside the container
docker compose exec dbsvcmariadb mariadb -u"${SQLDB_USER}" -p
```

### Reset the database

To wipe all data and re-run the init script (this also deletes every database):

```bash
docker compose down dbsvcmariadb
rm -rf ${APPS_DATA}/databases/mariadb/*
docker compose up -d dbsvcmariadb
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM mariadb:11.8`) + init script copy |
| [`create-multiple-databases.sh`](create-multiple-databases.sh) | First-boot database/bootstrap script |

## See also

- [PostgreSQL](../postgresql/README.md) — the primary database in this stack
- [Root README — Configuration](../../README.md#configuration)
