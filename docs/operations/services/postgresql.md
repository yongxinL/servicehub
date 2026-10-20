# PostgreSQL — ServiceHub

> The primary relational database for Authentik, Forgejo, LiteLLM and Confluence.

## Overview

[PostgreSQL 16](https://www.postgresql.org/) is the primary relational database in the stack. It is defined by the `infrapgsql` service in [`compose/infra.yml`](../../../compose/infra.yml) and built from [`shared/postgresql/Dockerfile`](../../../shared/postgresql/Dockerfile) (`FROM postgres:16-alpine`).

## Service details

| Detail | Value |
|---|---|
| Service name | `infrapgsql` |
| Internal port | 5432 (not published to the host) |
| Data persistence | `${APPS_DATA}/infra/postgresql` |
| Health check | `pg_isready` every 30 s (20 s startup delay, 5 retries) |
| Shared memory | `shm_size: 128mb` |
| Init script | [`create-multiple-databases.sh`](../../../shared/postgresql/create-multiple-databases.sh) |

### Consumers

| Service | Database variable |
|---|---|
| Authentik (`infraauth` / `infraauthwrk`) | `IDENTITY_DBNAME` |
| Forgejo (`devopsforgejo`) | `SOURCECODE_DBNAME` |
| LiteLLM (`aiservlitellm`) | `AIGATE_DBNAME` |
| Confluence (`webappconf`, default homepage) | `WORKSPACE_DBNAME` |
| Stalwart (`mailsvstalwart`) | `POSTOFFICE_DBNAME` — sole mail data store (accounts, messages, indexes, blobs) (disabled; OCI blocks port 25) |

`webappocis` (oCIS) is **not** a PostgreSQL consumer. It uses local configuration and file storage under `${APPS_DATA}/webapp/ocis`; PostgreSQL still holds the Authentik identity data used by the oCIS OIDC flow.

## Configuration

Set in `.env` (see [`env.example`](../../../env.example)):

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

[`create-multiple-databases.sh`](../../../shared/postgresql/create-multiple-databases.sh) is copied to `/docker-entrypoint-initdb.d/` and runs **only on first initialisation** of an empty data directory. For each entry in `POSTGRES_DATABASES` it creates the database if it does not exist and grants privileges to `POSTGRES_USER`.

> The script only runs when `${APPS_DATA}/infra/postgresql` is empty. To re-run it on an existing cluster, you must reset the data directory (see below).

## PostgreSQL Monitoring Role

### Purpose and least-privilege design

`svc_metrics` exists only so Alloy's embedded PostgreSQL exporter can collect read-only monitoring data. The role has `LOGIN`, no superuser, database-creation, role-creation, replication, or bypass-RLS privileges, no table ownership or table-write grants, `NOINHERIT`, and a connection limit of five. It is a member of `pg_monitor` and has explicit `CONNECT` privilege on the `postgres` monitoring database.

The password belongs only in the server-side `.env` or the approved secret mechanism. Never commit, print, email, interpolate into Git, or place it in a shell command argument.

### Role creation

Create the role as a PostgreSQL owner or superuser. The password is set separately through the secure procedure below.

```sql
CREATE ROLE svc_metrics
    WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOINHERIT
    NOREPLICATION
    NOBYPASSRLS
    CONNECTION LIMIT 5;

GRANT pg_monitor TO svc_metrics;
GRANT CONNECT ON DATABASE postgres TO svc_metrics;
```

Do not grant application database ownership, `CREATEDB`, `CREATEROLE`, `SUPERUSER`, `REPLICATION`, `BYPASSRLS`, or application-table write privileges.

### Secure password-setting procedure

1. Generate or retrieve the password from the approved server-side secret mechanism.
2. Set it interactively in `psql` with `\password svc_metrics`, or pipe it from the approved secret mechanism directly into `psql` stdin. Do not place the value in `argv`, SQL files, Git, logs, or shell history.
3. Store the same runtime value only as `POSTGRES_EXPORTER_PASSWORD` in the server-side `.env` with owner-only permissions or in the approved external secret mechanism.
4. Confirm only that the variable is present. Do not print or inspect its value.

Interactive command:

```bash
docker compose exec -it infrapgsql sh -lc 'psql -U "$POSTGRES_USER"'
```

Inside `psql`:

```text
\password svc_metrics
\q
```

### Exporter environment variables

`compose/obsvce.yml` passes these non-secret names and the runtime-only password into Alloy:

| Variable | Runtime value or purpose |
|---|---|
| `POSTGRES_EXPORTER_ENABLED` | `true` while PostgreSQL telemetry is enabled |
| `POSTGRES_EXPORTER_HOST` | `infrapgsql` |
| `POSTGRES_EXPORTER_PORT` | `5432` |
| `POSTGRES_EXPORTER_DATABASE` | `postgres` |
| `POSTGRES_EXPORTER_USER` | `svc_metrics` |
| `POSTGRES_EXPORTER_PASSWORD` | Server-side secret; never print |

The current internal DSN uses `sslmode=disable`. This is the accepted internal-network trust decision recorded by the [ADR-010 Phase 5 runbook](../runbooks/ADR-010-PHASE-5-OCI-VALIDATION.md). If monitoring traffic must cross an untrusted boundary, approve and validate TLS before changing the DSN.

### Role verification

Run these checks as a PostgreSQL owner or superuser. They do not retrieve or display a password hash.

```sql
SELECT rolname,
       rolsuper,
       rolcreatedb,
       rolcreaterole,
       rolreplication,
       rolbypassrls,
       rolinherit,
       rolconnlimit
FROM pg_roles
WHERE rolname = 'svc_metrics';

SELECT pg_has_role('svc_metrics', 'pg_monitor', 'MEMBER') AS has_pg_monitor;
SELECT has_database_privilege('svc_metrics', 'postgres', 'CONNECT') AS has_connect;

SELECT table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'svc_metrics'
ORDER BY table_schema, table_name, privilege_type;
```

Expected: `LOGIN` enabled; `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION`, and `BYPASSRLS` false; `NOINHERIT`; connection limit `5`; `pg_monitor` membership true; `CONNECT` on `postgres` true; and no application-table grants.

Optional hardening for read-only sessions:

```sql
ALTER ROLE svc_metrics SET default_transaction_read_only = on;
```

Apply that setting only through the approved owner procedure and re-run the verification queries. Current runtime verification did not find this role setting; absence of the setting does not grant table-write privileges because `pg_monitor` and the explicit grants remain read-only.

### WAL collector permission

The enabled `wal` collector calls `pg_catalog.pg_ls_waldir()` to expose WAL directory metadata as `pg_wal_segments` and `pg_wal_size_bytes`.

`svc_metrics` reaches that function through its existing `pg_monitor` membership, so **no additional grant is required**. Runtime verification on the OCI host confirmed:

```sql
SELECT has_function_privilege(
    'svc_metrics',
    'pg_catalog.pg_ls_waldir()',
    'EXECUTE'
);
-- true
```

The direct grant below remains the approved, documented fallback if `pg_monitor` membership is ever withdrawn or the collector is enabled for a role that is not a member:

```sql
GRANT EXECUTE ON FUNCTION pg_catalog.pg_ls_waldir() TO svc_metrics;
```

This grant permits reading WAL directory metadata only. It does not grant filesystem writes, table writes, `pg_read_server_files`, or replication. It requires no PostgreSQL restart.

Review this access if the `wal` collector is disabled later. It can be revoked independently, without removing the monitoring role:

```sql
REVOKE EXECUTE ON FUNCTION pg_catalog.pg_ls_waldir() FROM svc_metrics;
```

Do not grant `SUPERUSER`, database ownership, or broader function execution merely to satisfy this collector.

### Connection validation

For an interactive check, enter the password at the hidden prompt:

```bash
docker compose exec -it infrapgsql psql -U svc_metrics -d postgres
```

```sql
SELECT current_user, pg_is_in_recovery();
```

Do not pass `PGPASSWORD` or the password value on the command line. The primary non-interactive validation is exporter health:

```bash
curl -fsSG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=pg_up'
```

### Alloy recreation

After any exporter environment or password change, recreate only Alloy:

```bash
docker compose up -d --no-deps --force-recreate obsvcealloy
```

Do not recreate PostgreSQL, Grafana, VictoriaMetrics, VictoriaLogs, or unrelated services for this change. Wait at least two 30-second scrape intervals before judging recovery.

### Metric verification

Verify the actual job and core health:

```bash
curl -fsSG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=pg_up'

curl -fsSG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=pg_exporter_last_scrape_error'

curl -fsSG 'http://127.0.0.1:8428/api/v1/query' \
  --data-urlencode 'query=pg_scrape_collector_success'
```

Expected runtime evidence:

- scrape job `integrations/postgres`;
- `pg_up == 1`;
- `pg_exporter_last_scrape_error == 0`;
- non-WAL collectors report success;
- VictoriaMetrics remote-write failures remain `0`;
- Grafana dashboard UID `servicehub-database` resolves and its core panels return data.

Runtime-verified on the OCI host: the `wal` collector reports success and exports `pg_wal_segments` and `pg_wal_size_bytes`. `pg_wal_lsn_diff` is **not** emitted by this exporter and must not be assumed to exist. Vacuum-progress (`pg_stat_progress_vacuum`) and user-table (`pg_stat_user_tables`) series are currently empty; those collectors report success but produce no series until the database has active work. Collector success alone is not evidence of samples.

### Password rotation

1. Generate the replacement in the approved server-side secret mechanism.
2. Update `POSTGRES_EXPORTER_PASSWORD` in the server-only `.env` without printing it.
3. Set the replacement on `svc_metrics` through the interactive or stdin-only procedure above.
4. Recreate only `obsvcealloy`.
5. Verify `pg_up`, collector health, the database dashboard, and the PostgreSQL alert.
6. If verification fails, restore the previous server-side secret and role password, recreate only `obsvcealloy`, and repeat verification.

### Exporter disablement

For an intentional disablement:

1. Set `POSTGRES_EXPORTER_ENABLED=false` in the server-side `.env`.
2. Recreate only `obsvcealloy`.
3. Confirm `pg_up` stops receiving new samples.
4. Record that the PostgreSQL alert may enter its configured no-data state after its pending window because PostgreSQL telemetry is intended to remain enabled.

Do not change the alert merely to hide an intentional maintenance state.

### Role revocation and removal

Disable the exporter and recreate Alloy first so monitoring does not reconnect during revocation:

```sql
REVOKE pg_monitor FROM svc_metrics;
REVOKE CONNECT ON DATABASE postgres FROM svc_metrics;
REVOKE EXECUTE ON FUNCTION pg_catalog.pg_ls_waldir() FROM svc_metrics;
DROP ROLE svc_metrics;
```

Run the `REVOKE EXECUTE` statement only if the WAL function grant was applied. Do not drop application roles, databases, owners, or data as part of monitoring-role removal.

### Security considerations

- The password never enters Git, Grafana provisioning, dashboard JSON, alert YAML, logs, command arguments, or evidence files.
- PostgreSQL remains unpublished; Alloy reaches it only on the internal Docker network.
- Metric labels may include `instance`, `job`, database/state fields, and `usename`; they must never include the password, connection string credentials, or secret values.
- `pg_monitor` provides monitoring reads but does not confer database ownership or table-write privileges.
- Keep the connection limit at five unless measured exporter behavior requires a reviewed change.
- Treat the internal `sslmode=disable` decision as scope-specific, not a general database connection policy.

### Rollback

To roll back monitoring configuration:

1. Restore the previous server-side `POSTGRES_EXPORTER_*` values without printing them.
2. Restore the previous `svc_metrics` password if it was rotated.
3. Recreate only `obsvcealloy`.
4. Verify `pg_up`, collector health, remote-write status, dashboard data, and alert state.
5. If the role itself must be rolled back, restore only the documented monitoring grants.

Never delete PostgreSQL data, VictoriaMetrics data, VictoriaLogs data, or run `docker compose down -v` as part of monitoring rollback.

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
| [`Dockerfile`](../../../shared/postgresql/Dockerfile) | Image build (`FROM postgres:16-alpine`) + init script copy |
| [`create-multiple-databases.sh`](../../../shared/postgresql/create-multiple-databases.sh) | First-boot database bootstrap script |

## See also

- [Backup and restore](../runbooks/BACKUP-RESTORE.md) — the scheduled Forgejo backup workflow takes `pg_dump` backups of every database every `db_backup_interval_days` days (default 1, daily; 6-month retention) and a full `APPS_DATA` archive every `full_backup_interval_days` days (default 7, weekly)
- [Stalwart — Database management](../../archive/2026-10-mailsv-removal/docs/operations/services/stalwart.md#database-management-create--delete--backup--restore) — worked create/drop/`pg_dump`/`pg_restore` example (archived)
- [MariaDB](mariadb.md) — MySQL-compatible alternative (unused by default)
- [Root README — Configuration](../../../README.md#configuration)
