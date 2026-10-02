---
project: ServiceHub
project_code: SVCHUB
document_type: RFC
document_id: RFC-001
title: ServiceHub Reliability and Recovery Baseline
version: "1.0"
status: Proposed
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
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
- Prunes database archives using a configurable retention value with a default of 182 days.
- Creates a full `APPS_DATA` archive on Sundays or on demand.
- Writes archives under a repository-secret backup root on the same target host.

The workflow explicitly states that the live full archive is crash-consistent for database directories, while the database dumps are the transaction-consistent layer.

There is no committed restore workflow, off-host copy, encryption step, restoration evidence, RPO, or RTO.

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

**Assessment:** required for disaster or host-loss recovery; not present in the repository.

Archives written only beneath the configured backup root do not protect against loss of the target host.

### Encryption

**Assessment:** `TBD`.

The repository documents git-crypt protection for self-signed certificates and secret material in repository secrets, but it does not document encryption for backup archives or off-host copies.

### Retention

**Assessment:** partially implemented for database archives.

The default database retention is 182 days. Full-archive retention, off-host retention, and legal or family retention requirements are `TBD`.

### RPO and RTO

**Assessment:** `TBD`.

The schedule suggests a database RPO candidate of up to one day, but repository evidence does not establish an approved RPO, successful run history, transfer delay, or restoration time.

### Restoration Testing

**Assessment:** not implemented.

No restore procedure, isolated recovery environment, integrity check, timed test, or evidence template exists in the repository.

## Recommended Direction

**Proposed:** use database-native PostgreSQL backups plus protected filesystem backups, supplemented by host-level recovery where practical and periodic restoration tests.

The recommended design should include:

1. Daily transaction-consistent PostgreSQL dumps.
2. Regular persistent-data archives that include all non-database bind mounts.
3. Encrypted copies to at least one off-host location.
4. Separate retention rules for database, filesystem, and host-recovery layers.
5. Documented restoration into an isolated environment.
6. Owner-approved RPO and RTO values.
7. Scheduled restore rehearsals with recorded duration, integrity, and service validation.
8. Protected recovery material for `.env`, git-crypt keys, ACME state, and repository secrets.

## Decision

Awaiting owner decision. The recommendation is `Proposed`, not implemented.

## Consequences

- Multiple backup layers increase storage and operational cost.
- Encryption and off-host transfer require key and credential governance.
- Restore rehearsals consume time and isolated resources.
- Host imaging may require tooling not present in the repository.

## Acceptance Criteria for a Future Decision

- A reviewed backup scope includes every persistence path.
- RPO and RTO are explicitly approved.
- Off-host protection and encryption are defined.
- A restore succeeds with recorded evidence.
- Backup and restore commands are documented without exposing secret values.
- Alerting or monitoring covers failed or missing backups.

## Related Documents

- [Backup and restore](../operations/BACKUP-RESTORE.md)
- [Monitoring and alerting](../operations/MONITORING-ALERTING.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
- [Observability and hardening phase](../phases/PHASE-004-observability-and-operational-hardening.md)

