---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: BACKUP-RESTORE
title: ServiceHub Backup and Restore
version: "1.2"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-10
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

The [backup workflow](../../.forgejo/workflows/71-backup.yml) runs through the existing `ssh-deploy` label, creates archives at the `backup_root` key of the `<PREFIX>_CONFIG` repository variable **on the source server**, and copies each archive to the off-host targets that the same variable enables.

The source server is the host running the ServiceHub services together with Forgejo and the Forgejo Actions runner. It may be a homelab server or an Oracle Cloud VM instance; the workflow reads `server_host`, `server_port`, and `deploy_path` from `<PREFIX>_CONFIG` and does not assume which, and it requires `server_ssh_known_hosts` (pinned host keys) with no runtime `ssh-keyscan` fallback, so host trust is deterministic. `backup_root` is a path on that source server, not a backup target.

| Backup type | Schedule or trigger | Content | Consistency | Status |
|---|---|---|---|---|
| PostgreSQL database | Daily at 02:30 in scheduled mode; manual `db` or `auto` | One `pg_dump` per non-template database plus `pg_dumpall --globals-only` packed into one daily archive | Transaction-consistent logical dump | Implemented; execution evidence not available |
| Full `APPS_DATA` | Sundays in `auto`; manual `full` or `auto` | Entire configured persistent-data tree with optional exclusions | Crash-consistent for live database directories | Implemented; execution evidence not available |
| Host configuration | Every run of the backup workflow | `.env` from the deploy path (never in the full archive) and `egress-policies.conf` from `${APPS_DATA}/shared/gateway` (also in the weekly full archive) — both edited on the server at runtime | Not applicable (plain files) | Implemented; execution evidence not available |
| Off-host copy | Same backup workflow | Rclone Home Server copy and Rclone Google Drive copy behind a Crypt remote, each enabled independently by its own key | `rclone hashsum sha256 --download` computed on both ends and compared per artifact; destination preflight before the first transfer | Workflow refactored 2026-10-08, review fixes 2026-10-09; per-artifact SHA-256 verification fix applied 2026-10-10; execution evidence unavailable |
| Encrypted backup archive | Every run of the Google Drive copy | Client-side encryption through an Rclone Crypt remote; credentials governed separately | Not applicable (plain files before encryption) | Accepted in ADR-007; credential governance TBD |
| Host recovery image | None evident | Not applicable | Not applicable | Optional; not selected |
| Restore workflow | No automated workflow | Recovery from either accepted target | Not applicable | Procedure documented; execution not implemented or tested |

Database, full-archive, and configuration-archive same-host retention values (`db_backup_retention_days`, `backup_local_full_retention_days`) are required keys of the `<PREFIX>_CONFIG` repository variable. Their values are not recorded in this document.

## Target Backup Strategy

**Accepted on 2026-10-03; repository configuration added, not runtime-validated. Target selection made optional on 2026-10-07. Replication revised to Rclone for both targets and the workflow refactored on 2026-10-08; transfers not runtime-validated.**

| Target | Purpose | Technology | Enabled by | Status |
|---|---|---|---|---|
| Home Server | Primary recovery target | Rclone SFTP remote; plain `.tar.gz` archives under `YYYY/YYYYMM` | `backup_home_destination` in `<PREFIX>_CONFIG` | Workflow refactored 2026-10-08; transfer not runtime-validated |
| Google Drive | Independent off-site copy | Rclone behind a Crypt remote (client-side encryption) | `backup_rclone_destination` in `<PREFIX>_CONFIG` | Configuration added; Crypt remote and transfer not runtime-validated |

Both targets read from the source server: the workflow copies each archive out of `backup_root` to each destination with Rclone. Neither target depends on the other, so either can be disabled without changing the data path of the remaining one.

A target is enabled when its key is non-empty. An absent or empty key disables that target, and every setting and secret used only by it is ignored rather than validated — see the table below. At least one target must be enabled; the workflow fails with `no off-host target is enabled` when both are missing. Same-host archives under `backup_root` are always created.

| Disabled target | Keys ignored | Secrets ignored |
|---|---|---|
| Home Server (Target 1) | `backup_home_sftp`, `backup_home_destination`, `backup_home_db_keep_age`, `backup_home_full_keep_age` | `BACKUP_HOME_SSH_KEY`, `BACKUP_HOME_SSH_KNOWN_HOSTS` |
| Google Drive (Target 2) | `backup_rclone_destination`, `backup_rclone_db_keep_age`, `backup_rclone_full_keep_age` | `BACKUP_RCLONE_CONFIG` |

Disabling one target reduces the environment to a single off-host copy, which is the condition ADR-007 rejected as a design. Treat a single-target environment as an accepted reduction in protection and record which targets each environment is expected to enable.

### Home Server connection

The Target 1 endpoint comes from `backup_home_sftp` (`user@host` or `user@host:port`; the port defaults to 22), and the destination path from the absolute `backup_home_destination`. The workflow creates the `_workflow_home` Rclone SFTP remote from these keys and the `BACKUP_HOME_SSH_KEY` / `BACKUP_HOME_SSH_KNOWN_HOSTS` secrets at runtime, so a non-standard port needs no code change. The target can be any SFTP server reachable from the runner, including one on a local network, and archives are stored as created under the `YYYY/YYYYMM` hierarchy.

Authentication uses the SSH private key in `BACKUP_HOME_SSH_KEY`, with strict host verification enforced by `BACKUP_HOME_SSH_KNOWN_HOSTS`. Both secrets are required whenever Target 1 is enabled. There is no repository password: the Home Server is treated as trusted storage and holds readable archives. The exact `ssh-keyscan -p <port> -H <host>` procedure for producing the host-key value, and how to paste it into each secret or variable, is documented under [SSH host keys](DEPLOYMENT.md#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts) in the deployment guide.

Forgejo Actions uses the existing `devopsrunner` image, extended with `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`, to orchestrate database dumps, persistent-data archives, retention, transfers, and integrity checks. The runner configuration is documented in [`../products/forgejo.md`](../products/forgejo.md). Because deployment and backup jobs share one capacity-one runner, they queue behind one another.

The target scope includes Compose and service configuration, PostgreSQL role and database dumps, oCIS configuration and file data, Forgejo data, mail data, Authentik data, certificates, and the remaining inventoried persistent state. The same-host archive remains an intermediate artifact; it is not sufficient disaster recovery by itself.

## Dual-Target Transfer

For each archive created in the run, and for each target that is enabled in `<PREFIX>_CONFIG`, the workflow:

1. Copies the file to the Home Server through the `_workflow_home` Rclone SFTP remote. *(Target 1 only)*
2. Computes SHA-256 over downloaded bytes on both ends with `rclone hashsum sha256 --download` and fails the run on mismatch. *(Target 1 only)*
3. Applies the approved Home Server retention policy. *(Target 1 only)*
4. Copies the file through the configured Rclone destination to Google Drive. *(Target 2 only)*
5. Computes SHA-256 over downloaded bytes on both ends with `rclone hashsum sha256 --download` and fails the run on mismatch. *(Target 2 only)*
6. Applies separate approved database and full-archive retention policies. *(Target 2 only)*

Before the first transfer, the workflow creates the Home Server destination directory and lists it to confirm the endpoint, key, host key, port, user, and path are all correct; for Google Drive it verifies that the configured remote exists and has type `crypt`. Both fail the run before any archive is read.

Replication uses copy semantics, never sync: source deletions must not propagate to backup destinations, and retention is applied explicitly on each destination. Both copies are read from the source server; the workflow creates an `_workflow_source` Rclone SFTP remote back to `server_host` (reserved names, so they cannot collide with remotes inside `BACKUP_RCLONE_CONFIG`), so no step fetches data from the Home Server.

Per-destination retention ages are `backup_home_db_keep_age` and `backup_home_full_keep_age` for the Home Server and `backup_rclone_db_keep_age` and `backup_rclone_full_keep_age` for Google Drive; `*-cfgBK-*` archives share the database keep age on each destination, and the Home Server and Google Drive may use different periods. Before the first production run against a destination, execute its three retention deletions with `--dry-run -vv` and review the listed files, because retention deletes real backups.

The workflow logs `Enabled off-host targets: home=<0|1> gdrive=<0|1>` before any transfer, and skips every step, tool check, and secret check belonging to a disabled target.

The workflow fails on a missing required secret or command for an enabled target, a missing key for an enabled target, both targets disabled, a failed dump or archive, a failed transfer, a failed integrity check, or a failed retention operation. Configuration presence does not record a successful transfer.

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

The exclusion value itself is stored in the `backup_exclude` key of `STAG_CONFIG` / `PROD_CONFIG` (a repository variable); an example value (noisy logs and Tier 3 `devops/forgejo/workspace`) is documented in the [deployment guide](DEPLOYMENT.md#data-backups-forgejo-actions). Add further Tier 3 paths when storage constraints require it; never exclude Tier 1.

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
