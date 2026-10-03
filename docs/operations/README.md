---
project: ServiceHub
project_code: SVCHUB
document_type: OPS-INDEX
document_id: OPS-INDEX
title: ServiceHub Operations Index
version: "1.0"
status: Active
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-03
tags:
  - servicehub
  - operations
  - index
related_documents:
  - ARCHITECTURE
  - TEST-001
  - RFC-001
---

# ServiceHub Operations Index

Operations guidance is derived from repository commands, Compose definitions, service configuration, and workflows. Runtime results and recovery guarantees remain unverified unless a linked record states otherwise.

## Documents

- [Runbook](RUNBOOK.md) — prerequisites, lifecycle commands, health, logs, upgrades, rollback, and escalation.
- [Backup and restore](BACKUP-RESTORE.md) — implemented backup scope, accepted dual-target strategy, recovery procedure, and evidence template.
- [Monitoring and alerting](MONITORING-ALERTING.md) — metrics, logs, dashboards, signals, severity, and alert testing.
- [Service inventory](SERVICE-INVENTORY.md) — evidence-based service register.
- [Troubleshooting](TROUBLESHOOTING.md) — structured diagnostics for common failures.

## Safe Use

- Read the relevant service README before changing configuration.
- Validate Compose configuration before starting or rebuilding.
- Back up data before upgrades or destructive maintenance.
- Do not paste secret values into commands, issues, test evidence, or documentation.
- Treat commands labelled `Proposed` as unverified.
- Escalate to the project owner when recovery, security, or data-loss decisions are required; named escalation contacts are `TBD`.
