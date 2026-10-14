---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-007
title: Adopt Dual-Target Backup and Disaster Recovery
version: "1.1"
status: Accepted
decision_basis: Owner decision recorded on 2026-10-03 and runner consolidation revised on 2026-10-04; repository configuration added; target selection, source-host scope, non-standard SFTP port, and key-based authentication recorded on 2026-10-07; replication revised on 2026-10-08 to use Rclone for both targets and to place Google Drive behind an Rclone Crypt remote; backup cadence revised on 2026-10-10 (daily schedule at 02:30 Australia/Sydney; day intervals made configurable, superseding the earlier every-third-day / every-tenth-day cadence); failure handling and cadence configuration revised on 2026-10-10 (degraded-target warnings, local-only runs permitted, day intervals moved into `${PREFIX}_CONFIG` with defaults of daily database archives and weekly full archives); runtime validation pending
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-03
updated: 2026-10-10
tags:
  - servicehub
  - architecture
  - backup
  - disaster-recovery
  - rclone
related_documents:
  - ADR-006
  - RFC-001
  - BACKUP-RESTORE
  - PHASE-004 (archived)
  - TEST-001
  - ROADMAP-001 (archived)
---

# ADR-007: Adopt Dual-Target Backup and Disaster Recovery

## Context

The repository implements PostgreSQL dumps and a full `APPS_DATA` archive on configured day intervals (defaults: daily for database archives, weekly for full archives) or on demand through Forgejo Actions (daily schedule at 02:30 `Australia/Sydney`, configuration archives on every run). Those artifacts are written under a configured backup root on the target host, with configured Rclone transfers to both off-host targets. No successful off-site transfer or tested restore is recorded.

ServiceHub must be able to recover from VM loss, an Oracle Cloud outage, accidental deletion, data corruption, and configuration error. Protection must include service configuration, PostgreSQL databases, and persistent filesystem paths for oCIS, Forgejo, email, Authentik, and the other stateful services already in scope.

Recovery objectives are not yet approved or measured. The one-to-two-hour recovery estimate in the decision discussion is a planning estimate only; it is not an approved RTO or evidence of recovery capability.

### Backup artifacts

The workflow produces three archive types before any replication occurs, so each archive is already a self-contained recovery artifact:

- **Database backup (`dbBK`):** PostgreSQL database dumps and PostgreSQL global roles; created on days where the source host's epoch-day index is a multiple of `db_backup_interval_days` (default 1, daily) when database backup is enabled.
- **Configuration backup (`cfgBK`):** deployment `.env` and `egress-policies.conf` when present; created on every backup run.
- **Full backup (`fullBK`):** persistent application data under `APPS_DATA`; created on days where the epoch-day index is a multiple of `full_backup_interval_days` (default 7, weekly) during automatic operation, or manually on request.

Archives follow the existing date hierarchy under `backup_root`:

```text
<backup_root>/
└── YYYY/
    └── YYYYMM/
        ├── <domain>-webapps-dbBK-YYYYMMDD.tar.gz
        ├── <domain>-cfgBK-YYYYMMDD.tar.gz
        └── <domain>-webapps-fullBK-YYYYMMDD.tar.gz
```

## Decision

Use Forgejo Actions to create database dumps and self-contained persistent-data archives, then copy each protected backup set to two destinations with Rclone:

1. **Home Server:** primary recovery target using an Rclone SFTP remote. The original `.tar.gz` archives are stored directly under the existing `YYYY/YYYYMM` hierarchy, so recovery is locate, copy, extract, restore — with no repository reconstruction.
2. **Google Drive:** independent off-site recovery copy using Rclone behind a Crypt remote, so archives are encrypted client-side before upload and decrypted transparently when accessed through the crypt remote.

Run every Forgejo Actions job on the existing `depotrunner` using the `ssh-deploy` label. Extend that runner image with `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`. The shared runner will create database dumps, enforce retention, copy the Home Server copy, copy the encrypted Google Drive copy, verify each transfer, and support disaster-recovery procedures. Legacy tooling from the earlier replication design is removed from the image and the workflow during the refactor.

The owner revised the runner portion of the decision on 2026-10-04 to avoid a second runner service and registration identity. The repository now configures the shared runner and dual-target workflow. Successful image build, scheduled execution, transfers, integrity checks, retention, and restores remain unverified until recorded runtime evidence exists. Same-host artifacts must not be treated as sufficient disaster recovery.

The o…24879 chars truncated…n-numeric: each produced the expected warning, error, exit status, or injected remote value. Transfers against real Home Server and Google Drive targets, and the cadence keys in a live environment, remain unexecuted and unevidenced.

## Related Documents

- [ADR-006 Adopt oCIS with Local Filesystem Storage](ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [RFC-001 Reliability and Recovery Baseline](../../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [Backup and restore](../../operations/runbooks/BACKUP-RESTORE.md)
- [PHASE-004 Observability and Operational Hardening (archived)](../../archive/2026-10-delivery-plan/PHASE-004-observability-and-operational-hardening.md)
- [Baseline test plan](../../testing/TEST-001-platform-baseline-validation.md)
- [ServiceHub Roadmap (archived)](../../archive/2026-10-delivery-plan/ROADMAP.md)

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Refactor the backup workflow so both off-host targets replicate each archive with Rclone | ServiceHub Architecture | TBD | Implemented 2026-10-08; transfer execution pending |
| Set `backup_home_sftp`, `backup_home_destination`, and the Home Server keep-age keys for each environment, with `BACKUP_HOME_SSH_KEY` and `BACKUP_HOME_SSH_KNOWN_HOSTS` secrets | ServiceHub Architecture | TBD | Keys finalised 2026-10-08; environment values pending |
| Configure the Google Drive Rclone remote and a Crypt remote wrapping it | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Verify per-artifact hash verification (or equivalent) runs after every transfer to both targets | ServiceHub Architecture | TBD | `rclone hashsum sha256 --download` per artifact on both targets 2026-10-10; execution evidence pending |
| Preserve independent retention policies for `dbBK`, `cfgBK`, and `fullBK` on each destination | ServiceHub Architecture | TBD | Per-destination keep-age keys implemented 2026-10-08; approved values pending |
| Remove retired Home Server replication configuration and secrets after successful migration | ServiceHub Architecture | TBD | Removed from workflow, image, and documentation 2026-10-08; repository secret removal pending |
| Preserve the Rclone Crypt credentials and configuration in a secure recovery location separate from Google Drive | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Execute and validate database dumps, archive creation, retention, and Rclone transfers to both targets in Forgejo Actions | ServiceHub Architecture | TBD | Repository implementation added; execution evidence pending |
| Perform a complete Home Server recovery test and a complete Google Drive Crypt recovery test | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Introduce periodic automated or documented restore verification (monthly `cfgBK`/`dbBK`, less frequent `fullBK`) | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Retain the existing Home Server backup repository until both new recovery paths have been tested successfully | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Align related documentation (`BACKUP-RESTORE`, `ARCHITECTURE`, `DATA-FLOW`, `SYSTEM-CONTEXT`, `DEPLOYMENT-ARCHITECTURE`, `RFC-001`, `TEST-001`, `PHASE-004`, `ROADMAP`) with the Rclone dual-target decision | ServiceHub Architecture | TBD | Completed 2026-10-08 |
| Build and validate the existing `depotrunner` image with the added backup tools | ServiceHub Architecture | TBD | Repository configuration added; build result pending |
| Define protected target configuration, credentials, retention, encryption, and alerting without recording secret values | ServiceHub Architecture | TBD | Secret names and validation added; approved values and alerting pending |
| Add oCIS configuration and persistent file storage to backup scope under ADR-006 | ServiceHub Architecture | TBD | Covered by full-archive and target-transfer configuration; execution pending |
| Implement and execute isolated restores from both targets and record integrity, duration, and validation evidence | ServiceHub Architecture | TBD | Proposed |
| Execute each target-selection combination (both targets, Home Server only, Google Drive only) in Forgejo Actions and confirm a disabled target's secrets and tools are not required | ServiceHub Architecture | TBD | Validation logic reworked and verified against 18 combinations locally 2026-10-09; Forgejo Actions runtime execution pending |
| Prune same-host archives only after successful off-host replication; local retention currently runs during archive creation, before transfer | ServiceHub Architecture | TBD | Proposed 2026-10-09 |
| Run each destination's retention with `--dry-run -vv` and review the listed files before the first production run against a new destination | ServiceHub Architecture | TBD | Proposed 2026-10-09 |
| Record which targets each environment is expected to enable, and alert when a run reports a changed enabled-target count | ServiceHub Architecture | TBD | Proposed |
| Approve RPO and RTO values from measured restore evidence | George Li | TBD | Proposed |
