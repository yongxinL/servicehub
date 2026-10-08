---
project: ServiceHub
project_code: SVCHUB
document_type: RFC
document_id: RFC-001
title: ServiceHub Reliability and Recovery Baseline
version: "1.2"
status: Accepted
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-08
tags:
  - servicehub
  - reliability
  - recovery
  - backup
related_documents:
  - ARCHITECTURE
  - BACKUP-RESTORE
  - TEST-001
  - PHASE-004
  - ADR-007
---

# RFC-001: ServiceHub Reliability and Recovery Baseline

## Summary

Define a recovery baseline for ServiceHub that protects databases, persistent application files, certificates, repositories, configuration, and secret recovery material, then proves the process through restoration tests.

## Current Evidence

The repository implements a Forgejo Actions backup workflow that:

- Runs daily at 02:30 in its default scheduled mode.
- Creates one `pg_dump` per non-template PostgreSQL database.
- Creates a role-globals `pg_dumpall` output.
- Packs database dumps into one daily archive.
- Requires approved protected retention inputs for database and full archives.
- Creates a full `APPS_DATA` archive on Sundays or on demand.
- Writes archives under a repository-secret backup root on the same target host.
- Runs on the existing Forgejo runner, whose image is extended with Rclone, SSH, the PostgreSQL client, Bash, and jq.
- Copies archives to the Home Server over an Rclone SFTP remote and to Google Drive through an Rclone Crypt remote, with destination integrity checks and target retention.

The workflow explicitly states that the live full archive is crash-consistent for database directories, while the database dumps are the transaction-consistent layer.

There is no successful image-build or transfer evidence, executed restore workflow, encryption-step evidence, restoration evidence, RPO, or RTO. Actual target locations and retention values remain in protected configuration.

## Evaluation

### Filesystem-Only Backups

**Assessment:** insufficient as the sole recovery method.

A filesystem archive covers bind-mounted data and configuration but is not transaction-consistent for live PostgreSQL files. It also remains on the target host unless another process copies it.

### Database-Native Backups Plus File Snapshots

**Assessment:** strongest repository-aligned baseline when combined with protection and testing.

PostgreSQL logical dumps support database-level recovery. Filesystem archives preserve media, repositories, application files, model or configuration state, certificates, and other bind mounts. They must not replace database-native dumps.

### Whole-Host Recovery Images

**Assessment:** useful supplemental layer, not a substitute for application-aware backups.

A host image can recover the operating system and Docker installation quickly but may be large, infrastructure-specific, and stale. Repository evidence does not show that host imaging exists.

### Off-Host Copies

**Assessment:** required for disaster or host-loss recovery; repository configuration is present but not runtime-validated.

The workflow configures Rclone transfers to both targets in addition to the same-host archive. Until both target copies execute successfully and are independently retrieved, repository configuration does not protect against loss of the target host.

### Encryption

**Assessment:** `TBD`.

The repository documents git-crypt protection for self-signed certificates and secret material in repository secrets. Under ADR-007 the Google Drive off-site copy is encrypted client-side through an Rclone Crypt remote, with its credentials governed separately; encryption for same-host archives and the Home Server copy remains `TBD`.

### Retention

**Assessment:** configured for same-host and target archives; execution not evidenced.

The workflow requires protected same-host and Rclone retention inputs and fails when retention operations fail. Approved values and successful retention evidence remain `TBD` and are not recorded in tracked documentation.

### RPO and RTO

**Assessment:** `TBD`.

The schedule suggests a database RPO candidate of up to one day, but repository evidence does not establish an approved RPO, successful run history, transfer delay, or restoration time.

### Restoration Testing

**Assessment:** procedure documented; execution not completed or tested.

The repository documents a restore sequence, validation requirements, and an evidence template. No isolated recovery execution, timed test, or recorded result exists.

## Recommended Direction

**Accepted through ADR-007:** use database-native PostgreSQL backups plus protected filesystem backups, an Rclone Home Server primary target, a Google Drive off-site copy behind an Rclone Crypt remote, and periodic restoration tests.

The repository now configures backup creation, dual-target transfer, integrity checks, and separate retention. The remaining assurance work is:

1. Execute and validate daily transaction-consistent PostgreSQL dumps and persistent-data archives.
2. Verify Home Server and Google Drive copies independently.
3. Verify separate retention rules for database and filesystem layers.
4. Restore into an isolated environment.
5. Approve RPO and RTO values from measured restores.
6. Schedule restore rehearsals with recorded duration, integrity, and service validation.
7. Validate protected recovery material for `.env`, git-crypt keys, ACME state, and repository secrets.

## Decision

Accepted on 2026-10-03 through [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md). Repository configuration is added but not tested. RPO, RTO, approved retention values, encryption controls, successful transfers, and restoration evidence remain `TBD` until verified.

## Consequences

- Multiple backup layers increase storage and operational cost.
- Encryption and off-host transfer require key and credential governance.
- Restore rehearsals consume time and isolated resources.
- The shared runner toolchain and both target integrations require build, execution, credential-governance, and recovery validation.

## Implementation and Assurance Criteria

- A reviewed backup scope includes every persistence path.
- RPO and RTO are explicitly approved.
- Home Server and Google Drive copies are implemented and independently retrievable.
- Backup encryption and key governance are defined.
- A restore succeeds with recorded evidence.
- Backup and restore commands are documented without exposing secret values.
- Alerting or monitoring covers failed or missing backups.

## Related Documents

- [Backup and restore](../operations/BACKUP-RESTORE.md)
- [Forgejo runner and backup workflow runtime](../../shared/forgejo/README.md#backup-workflow-runtime)
- [Monitoring and alerting](../operations/MONITORING-ALERTING.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
- [Observability and hardening phase](../phases/PHASE-004-observability-and-operational-hardening.md)
