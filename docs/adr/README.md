---
project: ServiceHub
project_code: SVCHUB
document_type: ADR-INDEX
document_id: ADR-INDEX
title: ServiceHub Architecture Decision Register
version: "1.3"
status: Active
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-05
tags:
  - servicehub
  - architecture
  - adr
  - index
related_documents:
  - ARCHITECTURE
  - PRD-001
---

# ServiceHub Architecture Decision Register

These ADRs record both retrospective decisions inferred from the current implementation and accepted forward-looking design decisions. Each record states whether supporting implementation evidence exists; `status: Accepted` records the decision, not successful runtime validation.

| ID | Title | Status | Date | Related implementation | Supersedes | Link |
|---|---|---|---|---|---|---|
| ADR-001 | Use Docker Compose for Orchestration | Accepted | 2026-10-01 | `docker-compose.yml`, `compose/*.yml` | None | [ADR-001](ADR-001-use-docker-compose.md) |
| ADR-002 | Use Traefik as the Single HTTP Ingress | Accepted | 2026-10-01 | `compose/route.yml`, Traefik labels | None | [ADR-002](ADR-002-use-traefik-as-ingress.md) |
| ADR-003 | Use PostgreSQL as the Primary Relational Platform | Accepted | 2026-10-01 | `compose/infra.yml`, PostgreSQL consumers | None | [ADR-003](ADR-003-use-postgresql-as-primary-database.md) |
| ADR-004 | Use Authentik for Central Identity | Accepted | 2026-10-01 | `compose/infra.yml`, forward-auth and LDAP configuration | None | [ADR-004](ADR-004-use-authentik-for-central-identity.md) |
| ADR-005 | Use LiteLLM for AI Workload Routing | Accepted | 2026-10-01 | `compose/aiserv.yml`, `shared/litellm/` | None | [ADR-005](ADR-005-use-litellm-for-ai-routing.md) |
| ADR-006 | Adopt oCIS with Local Filesystem Storage | Accepted | 2026-10-03 | `compose/webapp.yml`, `env.example`, `compose/route.yml`, `shared/owncloud/`; runtime validation pending | None | [ADR-006](ADR-006-adopt-ocis-with-local-filesystem-storage.md) |
| ADR-007 | Adopt Dual-Target Backup and Disaster Recovery | Accepted | 2026-10-03 | `.forgejo/workflows/30-prod-backup-services.yml` and `shared/forgejo/actions/`; shared runner revision recorded; runtime validation pending | None | [ADR-007](ADR-007-adopt-dual-target-backup-and-recovery.md) |
| ADR-008 | Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables | Accepted | 2026-10-05 | `compose/*.yml`, `env.example`, `scripts/setup.sh`, workflows, and storage layout applied on `service-renaming`; runtime validation pending | None | [ADR-008](ADR-008-standardise-service-naming-storage-and-bind-mounts.md) |
| ADR-009 | Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries | Proposed | 2026-10-05 | None — draft recording the owner discussion of 2026-10-05; implementation pending | None | [ADR-009](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) |

New records must use the next unused `ADR-NNN` ID, add a row here, and use [ADR-TEMPLATE.md](../templates/ADR-TEMPLATE.md).
