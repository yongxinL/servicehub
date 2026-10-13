# Operations

## Purpose
Describes how `<PROJECT_NAME>` is deployed, configured, monitored, backed up, and recovered.

## Authority
Authoritative for the operational model. Procedures are authoritative in runbooks ([runbooks/README.md](runbooks/README.md)); design decisions belong in ADRs. Contains no secret values. Owning chapter: central manual 15.

## Artifact triggers
Write the operational model before the first deployment to any shared or production environment; update on infrastructure change.

## Naming and identifiers
This README holds the operational model. No identifiers.

## Status expectations
Reviewed date recorded per section.

## Operational model
No operational model has yet been recorded. When recorded, cover: environments, hosting, deployment path, configuration sources and precedence, secret store references by name, monitoring, alerting, backup scope and method, restore and recovery objectives, and links to runbooks.

## Index-entry requirements
Each section links the runbook that implements it.

## Index

| Document | Type | Status | Updated |
|---|---|---|---|
| [Development Workflows](DEVELOPMENT.md) | Development guide | Active | 2026-10-10 |
| [Container Egress Controls](EGRESS-CONTROLS.md) | Operations guide | Draft | 2026-10-10 |
| [Installation](INSTALLATION.md) | Operations guide | Active | 2026-10-09 |
| [Monitoring and Alerting](MONITORING-ALERTING.md) | Operations guide | Draft | 2026-10-05 |
| [Service Inventory](SERVICE-INVENTORY.md) | Operations guide | Draft | 2026-10-10 |
| [Troubleshooting](TROUBLESHOOTING.md) | Operations guide | Draft | 2026-10-08 |
| [Project-specific service guides](services/README.md) | Service-guide index | Active | 2026-10-09 |
| [Runbooks](runbooks/README.md) | Runbook index | Not recorded | Not recorded |

## Relationship to other artifacts
Release records reference deployment and rollback runbooks.

## Current scaffold state
Operations documents and indexes are listed above.
