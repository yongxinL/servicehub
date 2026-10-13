---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: BACKUP-RESTORE
title: ServiceHub Backup and Restore
version: "1.1"
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
  - DEPLOYMENT
  - ADR-006
  - ADR-007
  - RFC-001
  - TEST-001
  - ARCHITECTURE
---

# ServiceHub Backup and Restore

## Status

The repository configures same-host backup creation, backup tooling on the existing Forgejo runner, and the accepted dual-target strategy. Runtime execution, independently retrievable copies, and restore remain unverified. This document distinguishes repository configuration from recovery evidence recorded under [ADR-007](../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md).

The target failure handling and the `db_backup_interval_days` / `full_backup_interval_days` cadence keys were exercised on 2026-10-10 by extracting the workflow's shell script, syntax-checking the generated remote script, and running it against stubbed `ssh` and `rclone` for every target combination (none, Home only, Google Drive only, both) with each stub made to fail: each combination produced the expected local archives line, warning, or error and exit status, and the interval keys produced the expected values in the remote script plus validation errors for `0` and non-numeric input. No transfer against a real Home Server or Google Drive has been run.

## Implemented Backup Scope

The [backup workflow](../../../.forgejo/workflows/71-backup.yml) runs through the existing `ssh-deploy` label, creates archives at the `backup_root` key of the `<PREFIX>_CONFIG` repository variable **on the source server**, and copies each archive to the off-host targets that the same variable enables.

The source server is the host running the ServiceHub services together with Forgejo and the Forgejo Actions runner. It may be a homelab server or an Oracle Cloud VM instance; the workflow reads `server_host`, `server_port`, and `deploy_path` from `<PREFIX>_CONFIG` and does not assume which, and it requires `server_ssh_known_hosts` (pinned host keys) with no runtime `ssh-keyscan` fallback, so host trust is deterministic. `backup_root` is a path on that source server, not a backup target.

| Backup type | Schedule or trigger | Content | Consistency | Status |
|---|---|---|---|---|
| PostgreSQL database | Every `db_backup_interval_days` day (default 1, daily) at 02:30 (Australia/Sydney) in scheduled mode; manual `db` on demand | One `pg_dump` per non-template database plus `pg_dumpall --globals-only` packed into one archive per backup day | Transaction-consistent logical dump | Implemented; execution evidence not available |
| Full `APPS_DATA` | Every `full_backup_interval_days` day (default 7, weekly) at 02:30 (Australia/Sydney) in scheduled mode; manual `full` on demand | Entire configured persistent-data tree with optional exclusions | Crash-consistent for live database directories | Implemented; execution evidence not available |
| Host configuration | Every run of the backup workflow (daily with the scheduled cadence) | `.env` from the deploy path (never in the full archive) and `egress-policies.conf` from `${APPS_DATA}/shared/gateway` (also in the full archive) — both edited on the server at runtime | Not applicable (plain files) | Implemented; execution evidence not available |
| Off-host copy | Same backup workflow | Rclone Home Server copy and Rclone Google Drive copy behind a Crypt remote, each enabled independently by its own key | `rclone hashsum sha256 --download` computed on both ends and compared per artifact; destination preflight before the first transfer | Workflow refactored 2026-10-08, review fixes 2026-10-09; per-artifact SHA-256 verification fix applied 2026-10-10; execution evidence unavailable |
| Encrypted backup archive | Every run of the Google Drive copy | Client-side encryption through an Rclone Crypt remote; credentials governed separately | Not applicable (plain files before encryption) | Accepted in ADR-007; credential governance TBD |
| Host recovery image | None evident | Not applicable | Not applicable | Optional; not selected |
| Restore workflow | No automated workflow | Recovery from either accepted target | Not applicable | Procedure documented; execution not implemented or tested |

Database, full-archive, and configuration-archive same-host retention values (`db_backup_retention_days`, `backup_local_full_retention_days`) are required keys of the `<PREFIX>_CONFIG` repository variable. Their values are not recorded in this document.

### Archive layout and schedule

**Database dumps (every `db_backup_interval_days` days, default 1 — daily)** — one transaction-consistent `pg_dump` per PostgreSQL database (custom format, restored with `pg_restore`) plus a role-globals SQL dump, taken through the `infrapgsql` container while the services keep running. Archive naming: `<prefix>-webapps-dbBK-YYYYMMDD.tar.gz`.

**Full `APPS_DATA` archives (every `full_backup_interval_days` days, default 7 — weekly)** — the full persistent-data tree under the configured `APPS_DATA` root, with optional `backup_exclude` paths removed. Archive naming: `<prefix>-webapps-fullBK-YYYYMMDD.tar.gz`.

**Configuration archives (every run)** — `.env` and `egress-policies.conf` packed together. Archive naming: `<prefix>-webapps-cfgBK-YYYYMMDD.tar.gz`.

All archives are written under the `backup_root` path at the target server with the date hierarchy `YYYY/YYYYMM/`.

## Google Drive Setup (backup_rclone_config)

This section records the Rclone Crypt configuration for the Google Drive backup target. The Rclone config is stored as a secret and must not be committed.

1. **Install Rclone** on a workstation: `curl https://rclone.org/install.sh | sudo bash`.
2. **Create a Google Drive remote** (`gdrive:`):
   ```sh
   rclone config create gdrive drive config_is_local false
   ```
   Follow the browser auth flow. Test with `rclone lsd gdrive:`.
3. **Create a Crypt remote wrapping `gdrive:`** (`gdrive-crypt:`):
   ```sh
   rclone config create gdrive-crypt crypt remote gdrive:servicehub-backups filename_encryption standard directory_name_encryption true password [strong-generated] password2 [strong-generated]
   ```
   Test with `rclone lsd gdrive-crypt:`.
4. **Export the config** for Forgejo Actions:
   ```sh
   rclone config show gdrive-crypt
   ```
   Copy the entire output (including the `gdrive:` remote if inline, or both remotes separately). Save as `rclone.conf` (`chmod 600`).
5. **Set secrets in Forgejo Actions**:
   - `BACKUP_RCLONE_CONFIG` (Secrets): the full `rclone.conf` content.
   - `BACKUP_RCLONE_DESTINATION` (Secrets): `gdrive-crypt:servicehub-backups`.
   - `BACKUP_RCLONE_CRYPT_PASSWORD` (Secrets): the crypt password from step 3 (only needed if the config is ever lost and must be recreated; Rclone stores the obscured password in the config).
   - `BACKUP_GDRIVE_ENABLED` (Variables): `true` or `false` per environment.

   **Do not commit `rclone.conf` or any password.**

## Home Server Setup

The Home Server is the primary recovery target using Rclone SFTP.

1. Ensure SSH key access from the source server to the Home Server. The private key is stored as `BACKUP_HOME_SSH_KEY` (Forgejo Actions secret).
2. Configure the Home Server destination in `<PREFIX>_CONFIG`:
   - `backup_home_sftp`: the SFTP remote string (e.g. `sftp://user@home.example:2222/path/to/backups`)
   - `backup_home_destination`: the destination path on the Home Server
   - `backup_home_keep_days_dbBK`, `backup_home_keep_days_cfgBK`, `backup_home_keep_days_fullBK`: retention days per archive type
   - `BACKUP_HOME_SSH_KNOWN_HOSTS` (Forgejo Actions secret): hashed host keys from `ssh-keyscan -p <port> -H <host>` (one line per key type; see [DEPLOYMENT.md](DEPLOYMENT.md#ssh-known-hosts))

## Retrieving Backup Archives

### Retrieval from Target 1 (Home Server — plain archives)

The Home Server stores plain `.tar.gz` archives under the `YYYY/YYYYMM/` hierarchy, matching the source `backup_root` structure. To fetch a specific archive:

```sh
# one archive
scp user@home.example:path/to/backups/YYYY/YYYYMM/<file>.tar.gz ./restore/

# or everything
rsync -avz user@home.example:path/to/backups/ ./restore/
```

Verify before use: `gzip -t ./restore/<file>.tar.gz`, and `tar -tzf ./restore/<file>.tar.gz` to list the contents without extracting.

### Retrieval from Target 2 (Google Drive)

Google Drive stores **ciphertext only** — file and folder names are scrambled, so the Drive web UI shows nothing usable and cannot tell you which archive is which. Decryption happens locally, in Rclone, on the machine that holds the Rclone configuration.

1. **Get the configuration.** Use the workstation `rclone.conf` created during [Google Drive setup](#google-drive-setup-backup_rclone_config), or fetch the `BACKUP_RCLONE_CONFIG` secret (Forgejo → Settings → Actions → Secrets) and save its body as `rclone.conf` (`chmod 600`, LF endings). The config carries the obscured Crypt password, which is all Rclone needs to decrypt; the original password is required only if the config itself is lost ([Step 5](#google-drive-setup-backup_rclone_config)).
2. **List the real names** through the Crypt remote — the same paths look random through the plain `gdrive:` remote or the web UI:
   ```sh
   rclone --config ./rclone.conf lsf -R gdrive-crypt:servicehub-backups/
   ```
   If `backup_rclone_destination` is not `gdrive-crypt:servicehub-backups`, use that value instead.
3. **Pull what is needed.** Rclone decrypts on the way down, so the files that land locally are the plain `.tar.gz` archives:
   ```sh
   # one archive
   rclone --config ./rclone.conf copy \
     'gdrive-crypt:servicehub-backups/<YYYY>/<YYYYMM>/<file>.tar.gz' ./restore/

   # or everything
   rclone --config ./rclone.conf copy 'gdrive-crypt:servicehub-backups/' ./restore/
   ```
4. **Verify:** `gzip -t ./restore/<file>.tar.gz`.

Nothing is sent back to Google: the same commands also run on the source server if the archive should be restored there, and only the local machine running Rclone ever needs the configuration.

## Restore Sequence

**Proposed; not implemented or tested.**

Start from archives fetched with [Retrieving backup archives](#retrieving-backup-archives).

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

- [RFC-001 Reliability and Recovery Baseline](../../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [ADR-006 Adopt oCIS with Local Filesystem Storage](../../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md)
- [Monitoring and alerting](../MONITORING-ALERTING.md)
- [Baseline test plan](../../testing/TEST-001-platform-baseline-validation.md)
