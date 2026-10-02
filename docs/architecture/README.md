---
project: ServiceHub
project_code: SVCHUB
document_type: ARCHITECTURE
document_id: ARCHITECTURE-INDEX
title: ServiceHub Architecture Index
version: "1.0"
status: Active
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - architecture
  - index
related_documents:
  - ARCHITECTURE
  - ADR-INDEX
---

# ServiceHub Architecture Index

The architecture documents explain the current repository implementation. Claims are marked as repository evidence, inference, proposal, or TBD; they do not replace the Compose files and service configuration.

## Documents

- [Architecture overview](ARCHITECTURE.md) — principles, subsystems, boundaries, platforms, and open concerns.
- [System context](SYSTEM-CONTEXT.md) — users, external systems, ingress, remote targets, DNS, certificates, and AI providers.
- [Component catalogue](COMPONENT-CATALOGUE.md) — service-by-service Compose inventory.
- [Data flow](DATA-FLOW.md) — request, identity, deployment, AI, telemetry, database, and backup flows.
- [Deployment architecture](DEPLOYMENT-ARCHITECTURE.md) — local, staging, production, runner, SSH, TLS, environment, and rollback model.

## Decision Records

- [ADR register](../adr/README.md)
- [ADR-001 Use Docker Compose for Orchestration](../adr/ADR-001-use-docker-compose.md)
- [ADR-002 Use Traefik as the Single HTTP Ingress](../adr/ADR-002-use-traefik-as-ingress.md)
- [ADR-003 Use PostgreSQL as the Primary Relational Platform](../adr/ADR-003-use-postgresql-as-primary-database.md)
- [ADR-004 Use Authentik for Central Identity](../adr/ADR-004-use-authentik-for-central-identity.md)
- [ADR-005 Use LiteLLM for AI Workload Routing](../adr/ADR-005-use-litellm-for-ai-routing.md)

## Primary Evidence

- [Root Compose definition](../../docker-compose.yml)
- [Compose domain files](../../compose/)
- [Forgejo workflows](../../.forgejo/workflows/)
- [Environment template](../../env.example)
- [Service configuration and README files](../../shared/)

