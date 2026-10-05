---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: BACKUP-RESTORE
title: ServiceHub Backup and Restore
version: "1.3"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-06
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

The repository configures same-host backup creation, backup tooling on the existing Forgejo runner, and the accepted dual-target strategy. Runtime execution, independently retrievable copies, and restore remain unverified. This document distinguishes repository configuration from recovery evidence recorded under [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md).

## Implemented Backup Scope

The [backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml) runs through the existing `ssh-deploy` label, creates archives at the `backup_root` key of the `<PREFIX>_CONFIG` secret, and configures transfers to both accepted targets.

| Backup type | Schedule or trigger | Content | Consistency | Status |
|---|---|---|---|---|
| PostgreSQL database | Daily at 02:30 in scheduled mode; manual `db` or `auto` | One `pg_dump` per non-template database plus `pg_dumpall --globals-only` packed into one daily archive | Transaction-consistent logical dump | Implemented; execution evidence not available |
| Full `APPS_DATA` | Sundays in `auto`; manual `full` or `auto` | Entire configured persistent-data tree with optional exclusions | Crash-consistent for live database directories | Implemented; execution evidence not available |
| Off-host copy | Same backup workflow | Restic Home Server copy and Rclone Google Drive copy | Target-side integrity checks configured | Repository configuration added; execution evidence unavailable |
| Encrypted backup archive | None evident | Encryption method and key governance | Not applicable | TBD |
| Host recovery image | None evident | Not applicable | Not applicable | Optional; not selected |
| Restore workflow | No automated workflow | Recovery from either accepted target | Not applicable | Procedure documented; execution not implemented or tested |

Database and full-archive same-host retention values (`db_backup_retention_days`, `backup_local_full_retention_days`) are required keys of the `<PREFIX>_CONFIG` repository secret. Their values are not recorded in this document.

## Target Backup Strategy

**Accepted on 2026-10-03; repository configuration added, not runtime-validated.**

| Target | Purpose | Technology | Status |
|---|---|---|---|
| Home Server | Primary recovery target | Restic over SSH/SFTP | Configuration added; transfer not runtime-validated |
| Google Drive | Independent off-site copy | Rclone | Configuration added; transfer not runtime-validated |

Forgejo Actions uses the existing `devopsrunner` image, extended with `restic`, `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`, to orchestrate database dumps, persistent-data archives, retention, transfers, and integrity checks. The runner configuration is documented in [`shared/forgejo/README.md`](../../shared/forgejo/README.md). Because deployment and backup jobs share one capacity-one runner, they queue behind one another.

The target scope includes Compose and service configuration, PostgreSQL role and database dumps, oCIS configuration and file data, Forgejo data, mail data, Authentik data, certificates, and the remaining inventoried persistent state. The same-host archive remains an intermediate artifact; it is not sufficient disaster recovery by itself.

## Dual-Target Transfer

For each archive created in the run, the workflow:

1. Streams the file to the configured Restic `sftp:` repository.
2. Runs a Restic repository integrity check.
3. Applies the approved Restic retention policy.
4. Copies the file through the configured Rclone destination.
5. Compares the destination file with the source using Rclone download mode.
6. Applies separate approved database and full-archive Rclone retention policies.

The workflow fails on a missing required secret or command, failed dump or archive, failed transfer, failed integrity check, or failed retention operation. Configuration presence does not record a successful transfer.

## Databases

The database backup discovers all non-template PostgreSQL databases except `postgres`, validates database names, and creates:

- One custom-format `.dump` per database.
- One role-globals `.sql` file.
- One daily `.tar.gz` archive containing those files.

The workflow does not dump MariaDB. If optional WordPress uses MariaDB, its backup is `TBD`.

oCIS does not have a dedicated PostgreSQL database. Its local configuration and file data are protected through the filesystem archive rather than a database dump.

## Bind Mounts

The full archive covers `APPS_DATA`, which includes paths declared in the default Compose files:

- `${APPS_DATA}/infra/mariadb`
- `${APPS_DATA}/infra/postgresql`
- `${APPS_DATA}/infra/authentik/media`
- `${APPS_DATA}/infra/authentik/templates`
- `${APPS_DATA}/devops/forgejo/data`
- `${APPS_DATA}/devops/forgejo/runner`
- `${APPS_DATA}/devops/forgejo/workspace`
- `${APPS_DATA}/webapp/ocis/config`
- `${APPS_DATA}/webapp/ocis/data`
- `${APPS_DATA}/webapp/confluence`
- `${APPS_DATA}/aiserv/openwebui`
- `${APPS_DATA}/aiserv/litellm`
- `${APPS_DATA}/aiserv/llamacpp`
- `${HERMES_DATA_00:-${APPS_DATA}/aiserv/hermes/00}`
- `${APPS_DATA}/obsvce/victoriametrics`
- `${APPS_DATA}/obsvce/victorialogs`
- `${APPS_DATA}/obsvce/grafana`
- `${APPS_DATA}/mailsv/stalwart`
- `${APPS_DATA}/mailsv/bulwark/settings`
- `${APPS_DATA}/mailsv/bulwark/admin`
- `${APPS_DATA}/mailsv/bulwark/admin-state`
- `${APPS_DATA}/mailsv/bulwark/telemetry`
- `${APPS_DATA}/shared/certs`

Per [ADR-009](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) the AI platform moves to local infrastructure; backup, recovery, and retention coverage for the `aiserv/*` paths on local infrastructure is an open follow-up and is not yet re-scoped here.

If `HERMES_DATA_00` points outside `APPS_DATA`, it is not covered by the full archive unless the operating system copies it separately. The workflow allows exclusions through the `backup_exclude` key of `<PREFIX>_CONFIG`; set them per the tier classification below.

## Backup tiers

[ADR-008 §8](../adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md) classifies the paths above:

- **Tier 1 — critical** (`infra/`, `devops/forgejo/data`, `webapp/confluence`, `webapp/ocis`, `mailsv/stalwart`, `shared/certs`): must be included in all backups; never add to `backup_exclude`.
- **Tier 2 — important** (`aiserv/openwebui`, `aiserv/hermes`, `aiserv/litellm`, `obsvce/grafana`): recommended backup; exclude only when storage constraints require it.
- **Tier 3 — rebuildable** (`devops/forgejo/workspace`, `obsvce/victoriametrics`, `obsvce/victorialogs`, `mailsv/bulwark/telemetry`): shorter retention or exclusion, depending on storage constraints.

The exclusion value itself is stored in the `backup_exclude` key of `STAG_CONFIG` / `PROD_CONFIG` (a repository secret); the repository documents an example value in the README Actions secrets table (noisy logs and Tier 3 `devops/forgejo/workspace`). Add further Tier 3 paths when storage constraints require it; never exclude Tier 1.

## Named Volumes

No named Docker volumes are declared in the default root Compose files. Dynamic Authentik outpost state or optional components may introduce additional storage not visible here and requires runtime inventory.

## Forgejo Repositories

The current source-control service is Forgejo. Repositories and Forgejo application state live under `${APPS_DATA}/devops/forgejo/data`. Runner registration and workspaces live under `devops/forgejo/runner` and `devops/forgejo/workspace`.

The full archive covers these paths only when they are beneath `APPS_DATA`.

## Authentik Data

The archive includes media and templates. Authentik's primary application state is in PostgreSQL and is covered by the logical database dump. Runtime outpost containers and their storage require inventory.

## WordPress Data

The optional WordPress path is not included by the root Compose file. If enabled, `${APPS_DATA}/webapp/wordpress` is covered by a full archive, while its MariaDB data requires a separate database backup that is not implemented.

## AI Configuration and Model Considerations

- LiteLLM configuration under `${APPS_DATA}/aiserv/litellm` is included in a full archive.
- Local model cache under `${APPS_DATA}/aiserv/llamacpp` is included if not excluded; it may be large.
- Hermes state under the configured data path is included only when it is under `APPS_DATA`.
- Cloud provider credentials remain in `.env` and repository secrets, not service bind mounts.
- Restoring configuration does not prove model availability or cloud provider access.

## Observability Data and Configuration

- VictoriaMetrics, VictoriaLogs, and Grafana data are included when under `APPS_DATA`.
- Repository dashboards and Alloy configuration are tracked in Git.
- A full archive of live telemetry stores may be internally inconsistent; restoration validation is required.
- Metric and log retention is `TBD`.

## Traefik Certificate State

`${APPS_DATA}/shared/certs/acme.json` is included in a full archive. Repository-encoded self-signed material may be restored from git-crypt. Backup archive permissions and encryption are `TBD`.

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
| Backup retention | Required protected secrets; values not tracked | ADR-007 configuration; no execution evidence |
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
