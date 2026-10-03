---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-007
title: Adopt Dual-Target Backup and Disaster Recovery
version: "1.0"
status: Accepted
decision_basis: Owner decision recorded on 2026-10-03; implementation pending
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-03
updated: 2026-10-03
tags:
  - servicehub
  - architecture
  - backup
  - disaster-recovery
  - restic
  - rclone
related_documents:
  - ADR-006
  - RFC-001
  - BACKUP-RESTORE
  - PHASE-004
  - TEST-001
  - ROADMAP-001
---

# ADR-007: Adopt Dual-Target Backup and Disaster Recovery

## Context

The repository currently implements daily PostgreSQL dumps and a weekly or on-demand `APPS_DATA` archive through Forgejo Actions. Those artifacts are written under a configured backup root on the target host. The current workflow does not provide an off-host copy or a tested restore.

ServiceHub must be able to recover from VM loss, an Oracle Cloud outage, accidental deletion, data corruption, and configuration error. Protection must include service configuration, PostgreSQL databases, and persistent filesystem paths for oCIS, Forgejo, email, Authentik, and the other stateful services already in scope.

Recovery objectives are not yet approved or measured. The one-to-two-hour recovery estimate in the decision discussion is a planning estimate only; it is not an approved RTO or evidence of recovery capability.

## Decision

Use Forgejo Actions to create database dumps and persistent-data archives, then copy each protected backup set to two destinations:

1. **Home Server:** primary recovery target using Restic over SSH/SFTP.
2. **Google Drive:** independent off-site recovery copy using Rclone.

Provide a dedicated backup runner, `nexora/runner-backup`, containing `restic`, `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`. The runner will create database dumps, enforce retention, upload the Home Server copy, synchronise the Google Drive copy, and support disaster-recovery procedures.

The existing same-host backup workflow remains the implemented baseline until the dual-target workflow is committed, validated, and tested. Same-host artifacts must not be treated as sufficient disaster recovery.

## Decision Drivers

- Recover from loss of the Oracle VM or cloud environment.
- Maintain a primary target that can be used directly for restoration.
- Maintain an independent off-site copy.
- Include databases, configuration, and persistent application data.
- Automate retention and transfers through repository-hosted workflows.
- Keep credentials outside tracked documentation.
- Support oCIS once it is deployed under [ADR-006](ADR-006-adopt-ocis-with-local-filesystem-storage.md).

## Backup Scope

### Service Configuration

- Docker Compose files.
- Environment files, without documenting secret values.
- Traefik configuration and certificate state.
- oCIS, Authentik, Forgejo, Stalwart, and related service configuration.
- Recovery material for `.env`, git-crypt keys, ACME state, and repository secrets, stored and governed separately from normal documentation.

### PostgreSQL Databases

Create transaction-consistent logical dumps for all non-template ServiceHub PostgreSQL databases, including databases used by Authentik, Forgejo, LiteLLM, Confluence, and Stalwart. Preserve the role-globals dump and validate database names before transfer. oCIS does not add a dedicated PostgreSQL database; its configuration and file data are protected as filesystem paths.

### Persistent Data

Protect the complete persistent-data inventory, including:

- oCIS configuration under `${APPS_DATA}/cloud/ocis/config`.
- oCIS file data under `${APPS_DATA}/cloud/ocis/data`.
- Forgejo repositories and application state.
- Mail data.
- Authentik media, templates, and any inventoried runtime state.
- Certificates, observability data, AI configuration, and other stateful bind mounts already covered by ServiceHub backup scope.

The implementation must record actual paths and exclusions. Storage outside the protected data root requires a separate copy rule.

## Backup Targets

| Target | Purpose | Technology | Implementation status |
|---|---|---|---|
| Home Server | Primary recovery target | Restic over SSH/SFTP | Accepted; not implemented |
| Google Drive | Independent off-site copy | Rclone | Accepted; not implemented |

Target locations, account identifiers, hostnames, credentials, repository names, and retention values must remain in approved secret or environment configuration and must not be invented in documentation.

## Backup Workflow

```text
Forgejo Actions
      |
      v
Database dumps and persistent-data archives
      |
      +--> Restic over SSH/SFTP --> Home Server
      |
      +--> Rclone ---------------> Google Drive
```

The workflow should fail visibly when required inputs, dumps, archives, transfers, retention operations, or integrity checks fail. Transfer and restore credentials must be available only to the backup runner through approved secrets.

## Recovery Procedures

### Scenario 1: Oracle VM Lost

1. Provision a replacement VM.
2. Restore Compose and approved environment configuration.
3. Restore PostgreSQL role globals and database dumps.
4. Restore persistent volumes and certificate state.
5. Restore separately governed secret recovery material.
6. Start services in dependency order.
7. Validate routes, authentication, repositories, email, oCIS data, telemetry, and subsequent backups.

**Planning estimate:** one to two hours. This estimate is untested and does not establish an RTO.

### Scenario 2: Google Drive Used for Recovery

1. Provision a replacement VM.
2. Retrieve the off-site backup set using Rclone.
3. Validate backup integrity before restoration.
4. Restore configuration, databases, volumes, certificates, and secret recovery material.
5. Start and validate the platform as in Scenario 1.

**Planning estimate:** subject to the same untested one-to-two-hour estimate; download duration and access recovery must be measured.

## Options Considered

1. Retain same-host PostgreSQL and filesystem archives only.
2. Replicate backups to one off-host destination.
3. Replicate backups to a Home Server primary target and a Google Drive off-site target.

Option 1 was rejected because host or cloud loss can remove both service data and backups. Option 2 was rejected because a single off-host destination becomes a single point of backup failure or credential loss. Option 3 was accepted because it separates primary recovery from off-site continuity without introducing cluster infrastructure.

## Rationale

The dual-target design addresses host-loss and cloud-outage scenarios while preserving a filesystem-visible primary recovery path. Restic supports managed repository retention and transfer to the Home Server, while Rclone provides a separate path to Google Drive. Repository-hosted automation keeps backup behaviour reviewable and reusable across environments.

## Positive Consequences

- Primary and off-site recovery paths are independent.
- Database and filesystem layers have distinct consistency roles.
- Retention and transfer behaviour can be automated and alerted.
- The design can cover existing stateful services and the configured oCIS filesystem paths.
- Backup creation remains traceable to Forgejo Actions history once implemented.

## Negative Consequences

- Two transfer paths increase runtime, storage, credential, and monitoring overhead.
- Google Drive recovery depends on external service availability and account access.
- Large filesystem archives may consume significant Home Server and network capacity.
- Backup creation alone does not provide recovery assurance without restore tests.

## Risks

- **No tested restore:** implement recovery procedures and record an isolated restore test before claiming recovery capability.
- **Undefined RPO, RTO, and retention:** approve objectives only from measured backup history and timed restoration evidence.
- **Credential or key loss:** define protected storage, custodians, rotation, and break-glass recovery without placing values in documentation.
- **Transfer failure remains unnoticed:** alert on missing, stale, failed, or integrity-checked backups.
- **Inconsistent live archives:** use transaction-consistent PostgreSQL dumps and validate filesystem or oCIS-aware consistency rules.
- **External Google Drive limitations:** test retrieval, quotas, authentication recovery, and off-site retention before relying on the copy.

## Implementation Evidence

The current repository contains:

- [Daily and weekly backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml)
- [Backup and restore operations record](../operations/BACKUP-RESTORE.md)
- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [ADR-006 oCIS filesystem configuration](ADR-006-adopt-ocis-with-local-filesystem-storage.md)

No `nexora/runner-backup` image definition, Restic Home Server destination, Rclone Google Drive configuration, dual-target workflow, restore workflow, successful transfer evidence, or timed restore evidence is recorded as of 2026-10-03.

## Related Documents

- [ADR-006 Adopt oCIS with Local Filesystem Storage](ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [Backup and restore](../operations/BACKUP-RESTORE.md)
- [PHASE-004 Observability and Operational Hardening](../phases/PHASE-004-observability-and-operational-hardening.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
- [ServiceHub Roadmap](../requirements/ROADMAP.md)

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Build or publish the `nexora/runner-backup` image with the decided tools | ServiceHub Architecture | TBD | Proposed |
| Implement database dumps, archive creation, retention, Restic transfer, and Rclone synchronisation in Forgejo Actions | ServiceHub Architecture | TBD | Proposed |
| Define protected target configuration, credentials, retention, encryption, and alerting without recording secret values | ServiceHub Architecture | TBD | Proposed |
| Add oCIS configuration and persistent file storage to backup scope under ADR-006 | ServiceHub Architecture | TBD | Both paths present in current full-archive scope; dual-target transfer pending |
| Implement and execute isolated restores from both targets and record integrity, duration, and validation evidence | ServiceHub Architecture | TBD | Proposed |
| Approve RPO and RTO values from measured restore evidence | George Li | TBD | Proposed |
