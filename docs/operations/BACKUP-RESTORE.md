---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: BACKUP-RESTORE
title: ServiceHub Backup and Restore
version: "1.0"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-03
tags:
  - servicehub
  - operations
  - backup
  - recovery
related_documents:
  - ADR-006
  - ADR-007
  - RFC-001
  - TEST-001
  - ARCHITECTURE
---

# ServiceHub Backup and Restore

## Status

The repository implements same-host backup creation but does not implement the accepted dual-target strategy or validate restore. This document distinguishes confirmed backup behaviour from the target strategy recorded in [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md).

## Implemented Backup Scope

The [backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml) runs through the `ssh-deploy` runner and writes to `<PREFIX>_BACKUP_ROOT` on the target host.

| Backup type | Schedule or trigger | Content | Consistency | Status |
|---|---|---|---|---|
| PostgreSQL database | Daily at 02:30 in scheduled mode; manual `db` or `auto` | One `pg_dump` per non-template database plus `pg_dumpall --globals-only` packed into one daily archive | Transaction-consistent logical dump | Implemented; execution evidence not available |
| Full `APPS_DATA` | Sundays in `auto`; manual `full` or `auto` | Entire configured persistent-data tree with optional exclusions | Crash-consistent for live database directories | Implemented; execution evidence not available |
| Off-host copy | None evident | Home Server and Google Drive targets | Not applicable | Accepted under ADR-007; not implemented |
| Encrypted backup archive | None evident | Encryption method and key governance | Not applicable | TBD |
| Host recovery image | None evident | Not applicable | Not applicable | Optional; not selected |
| Restore workflow | None evident | Recovery from either accepted target | Not applicable | Accepted under ADR-007; not implemented |

Database archive retention defaults to 182 days and can be overridden by `<PREFIX>_DB_BACKUP_RETENTION_DAYS`. Full-archive retention is `TBD`.

## Target Backup Strategy

**Accepted on 2026-10-03; not implemented or tested.**

| Target | Purpose | Technology | Status |
|---|---|---|---|
| Home Server | Primary recovery target | Restic over SSH/SFTP | Accepted; not implemented |
| Google Drive | Independent off-site copy | Rclone | Accepted; not implemented |

Forgejo Actions will use a dedicated `nexora/runner-backup` image containing `restic`, `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq` to create database dumps and persistent-data archives, enforce retention, and copy each protected set to both targets.

The target scope includes Compose and service configuration, PostgreSQL role and database dumps, oCIS configuration and file data, Forgejo data, mail data, Authentik data, certificates, and the remaining inventoried persistent state. The current same-host archive remains an intermediate or baseline artifact until the dual-target workflow is implemented; it is not sufficient disaster recovery by itself.

## Databases

The database backup discovers all non-template PostgreSQL databases except `postgres`, validates database names, and creates:

- One custom-format `.dump` per database.
- One role-globals `.sql` file.
- One daily `.tar.gz` archive containing those files.

The workflow does not dump MariaDB. If optional WordPress uses MariaDB, its backup is `TBD`.

oCIS does not have a dedicated PostgreSQL database. Its local configuration and file data are protected through the filesystem archive rather than a database dump.

## Bind Mounts

The full archive covers `APPS_DATA`, which includes paths declared in the default Compose files:

- `${APPS_DATA}/databases/mariadb`
- `${APPS_DATA}/databases/pgsqldb`
- `${APPS_DATA}/platform/authentik/media`
- `${APPS_DATA}/platform/authentik/templates`
- `${APPS_DATA}/platform/repos`
- `${APPS_DATA}/platform/buildexec`
- `${APPS_DATA}/platform/workspace`
- `${APPS_DATA}/cloud/ocis/config`
- `${APPS_DATA}/cloud/ocis/data`
- `${APPS_DATA}/webapps/confluence`
- `${APPS_DATA}/openwebui`
- `${APPS_DATA}/litellm`
- `${APPS_DATA}/llamacpp`
- `${HERMES_DATA_00:-${APPS_DATA}/hermesagent/00}`
- `${APPS_DATA}/victoriametrics`
- `${APPS_DATA}/victorialogs`
- `${APPS_DATA}/grafana`
- `${APPS_DATA}/platform/mailbox`
- `${APPS_DATA}/platform/webmail/settings`
- `${APPS_DATA}/platform/webmail/admin`
- `${APPS_DATA}/platform/webmail/admin-state`
- `${APPS_DATA}/platform/webmail/telemetry`
- `${APPS_DATA}/certs`

If `HERMES_DATA_00` points outside `APPS_DATA`, it is not covered by the full archive unless the operating system copies it separately. The workflow allows exclusions through `<PREFIX>_BACKUP_EXCLUDE`; actual exclusions are `TBD`.

## Named Volumes

No named Docker volumes are declared in the default root Compose files. Dynamic Authentik outpost state or optional components may introduce additional storage not visible here and requires runtime inventory.

## Forgejo Repositories

The current source-control service is Forgejo. Repositories and Forgejo application state live under `${APPS_DATA}/platform/repos`. Runner registration and workspaces live under `platform/buildexec` and `platform/workspace`.

The full archive covers these paths only when they are beneath `APPS_DATA`.

## Authentik Data

The archive includes media and templates. Authentik's primary application state is in PostgreSQL and is covered by the logical database dump. Runtime outpost containers and their storage require inventory.

## WordPress Data

The optional WordPress path is not included by the root Compose file. If enabled, `${APPS_DATA}/webapps/wordpress` is covered by a full archive, while its MariaDB data requires a separate database backup that is not implemented.

## AI Configuration and Model Considerations

- LiteLLM configuration under `${APPS_DATA}/litellm` is included in a full archive.
- Local model cache under `${APPS_DATA}/llamacpp` is included if not excluded; it may be large.
- Hermes state under the configured data path is included only when it is under `APPS_DATA`.
- Cloud provider credentials remain in `.env` and repository secrets, not service bind mounts.
- Restoring configuration does not prove model availability or cloud provider access.

## Observability Data and Configuration

- VictoriaMetrics, VictoriaLogs, and Grafana data are included when under `APPS_DATA`.
- Repository dashboards and Alloy configuration are tracked in Git.
- A full archive of live telemetry stores may be internally inconsistent; restoration validation is required.
- Metric and log retention is `TBD`.

## Traefik Certificate State

`${APPS_DATA}/certs/acme.json` is included in a full archive. Repository-encoded self-signed material may be restored from git-crypt. Backup archive permissions and encryption are `TBD`.

## Secret Recovery Material

Required but not stored in this document:

- Local `.env`.
- Git-crypt symmetric key.
- Forgejo repository secrets for environment, ACME, SSH, runner, and deployment access.
- DNS or certificate-authority credentials if applicable.
- Break-glass account recovery material.

Locations, custodians, rotation, and tested recovery paths are `TBD`.

## Restore Sequence

**Proposed; not implemented or tested.**

1. Establish an isolated recovery environment and record its commit and configuration.
2. Recover `.env`, git-crypt key, and other approved secret material without logging values.
3. Recover repository code and validate configuration.
4. Restore PostgreSQL role globals and verify required roles.
5. Restore each PostgreSQL database using its logical dump into an empty, verified database.
6. Verify row counts, application startup, and critical data.
7. Restore non-database bind mounts from a filesystem archive.
8. Restore certificates and verify permissions and trust.
9. Start foundational services in dependency order.
10. Start application services without replacing recovery data unexpectedly.
11. Validate routes, TLS, authentication, repositories, identity, oCIS file access, AI, email, telemetry, and backups.
12. Record elapsed time against approved RPO and RTO values.

Exact commands, target layout, ordering details, and compatibility checks remain `TBD`. Do not run a destructive restore against production without an approved plan and verified backup.

## Validation Requirements

- Archive readability and integrity.
- Database role and object restoration.
- Application-specific data checks.
- File ownership and permissions.
- Certificate validity and mode.
- Container health.
- Route, TLS, and login tests.
- oCIS configuration, file data, OIDC access, upload, download, and sharing checks.
- AI and email smoke tests where affected.
- Metrics and log availability.
- Successful subsequent backup.

## RPO and RTO

| Objective | Value | Evidence |
|---|---|---|
| RPO | TBD | Requires owner decision and measured backup history |
| RTO | TBD | Requires timed restoration test |
| Backup retention | Database default 182 days; full archive TBD | Workflow default and owner decision |
| Off-host objective | Two-target design accepted; objective TBD | ADR-007 decision; no transfer or restore evidence |

## Restoration Evidence Template

| Field | Value |
|---|---|
| Restore date | TBD |
| Environment | TBD |
| Source commit | TBD |
| Backup archive names | TBD |
| Backup creation times | TBD |
| Restore operator | TBD |
| Start and finish time | TBD |
| Database validation | TBD |
| File validation | TBD |
| Service validation | TBD |
| RPO achieved | TBD |
| RTO achieved | TBD |
| Defects and follow-up | TBD |
| Evidence link | TBD |
| Decision | Not Executed |

## Related Documents

- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [ADR-006 Adopt oCIS with Local Filesystem Storage](../adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md)
- [Monitoring and alerting](MONITORING-ALERTING.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
