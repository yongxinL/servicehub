---
project: ServiceHub
project_code: SVCHUB
document_type: PHASE
document_id: PHASE-004
title: Observability and Operational Hardening
version: "1.1"
status: Draft
lifecycle_stage: Planning
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-04
tags:
  - servicehub
  - phase
  - observability
  - operations
related_documents:
  - PRD-001
  - RFC-001
  - ADR-007
  - BACKUP-RESTORE
  - MONITORING-ALERTING
  - TEST-001
---

# PHASE-004: Observability and Operational Hardening

## Objective

Establish observable services, governed operational procedures, tested backup and recovery, alerting, troubleshooting, and release controls.

## Scope

- Grafana Alloy, VictoriaMetrics, VictoriaLogs, Grafana provisioning, and dashboards.
- Service health and logs.
- Backup workflow and configured dual-target recovery strategy.
- Runbook, service inventory, monitoring, and troubleshooting.
- Test, release, lesson, and investigation governance.
- Security and privileged-access review.

## Deliverables

- [Observability Compose domain](../../compose/obsvc.yml)
- [Alloy configuration](../../shared/grafana/alloy/config.alloy)
- [Grafana provisioning and dashboards](../../shared/grafana/)
- [Backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml)
- [Forgejo runner and backup workflow runtime](../../shared/forgejo/README.md#backup-workflow-runtime)
- Operations documentation under [docs/operations/](../operations/)
- Test and release registers under [docs/testing/](../testing/) and [docs/releases/](../releases/)

## Requirements Addressed

- FR-008 to FR-010
- OBS-001 to OBS-006
- BCR-001 to BCR-006
- REL-004 to REL-006
- NFR-007, NFR-008

## Dependencies

- Healthy metrics and log stores.
- Working Alloy host and Docker access.
- Existing backup target secrets and backup root.
- Protected Home Server and Google Drive target access under ADR-007; secret names are configured but values are not recorded here.
- Approved retention, RPO, RTO, and encryption controls.
- Notification channels and owners.
- Staging runtime and release evidence.

## Tasks

- [x] Metrics and log collection configuration exists.
- [x] Grafana data sources and dashboards are provisioned.
- [x] Backup workflow implements database dumps and full archives.
- [x] Restic, Rclone, and PostgreSQL client configuration exists on the shared Forgejo runner image.
- [x] Restic Home Server and Rclone Google Drive transfer, integrity-check, and retention configuration exists.
- [x] Operations and test documentation exists in this documentation set.
- [ ] Validate metrics, logs, dashboards, and retention.
- [ ] Define alert severities, notifications, owners, and alert tests.
- [x] Record the recovery-baseline decision in RFC-001 and ADR-007.
- [ ] Build the extended shared runner image, then execute and verify Home Server and Google Drive copies under ADR-007.
- [ ] Execute restoration and record evidence.
- [ ] Define and test rollback.
- [ ] Define and execute the first governed release.
- [ ] Record phase acceptance evidence.

## Risks

- Telemetry exists without confirmed data or alert delivery.
- Dual-target configuration exists but transfers and encryption controls are not runtime-validated.
- Restore is untested.
- Privileged and host-mounted collectors increase blast radius.
- Documentation may drift from implementation.

## Acceptance Criteria

- Expected metrics and logs appear in Grafana.
- Dashboards resolve their data sources.
- Alert delivery is tested to a named destination and owner.
- Backups meet approved scope and retention.
- A restore succeeds in an isolated test.
- RPO and RTO are approved and measured.
- Rollback is tested.
- Release evidence and post-release validation are recorded.
- Security review actions are tracked.

## Evidence Required

- Metrics and log queries.
- Dashboard screenshots or exported evidence.
- Alert test records.
- Backup manifests and integrity checks.
- Restore duration, validation, and service checks.
- Rollback and release records.

## Completion Summary

**Retrospective validation required.** Collection, same-host backup, and dual-target configuration exist; target transfers, alert delivery, restoration, rollback, release, and phase completion are not validated.

## Follow-up Work

- Execute and validate [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md).
- Execute operational sections of [TEST-001](../testing/TEST-001-platform-baseline-validation.md).
- Define the first release under [release governance](../releases/README.md).
