---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-001
title: Use Docker Compose for Orchestration
version: "1.1"
status: Accepted
decision_basis: Inferred from current implementation
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-08
tags:
  - servicehub
  - architecture
  - docker
related_documents:
  - ARCHITECTURE
  - PRD-001
  - DEPLOYMENT-ARCHITECTURE
---

# ADR-001: Use Docker Compose for Orchestration

## Context

ServiceHub combines infrastructure, identity, developer services, web applications, AI, observability, and email on a HomeLab platform. The repository uses a root Compose file with `include` for eight domain files and a fixed project name that creates `servicehub_subnet`.

## Decision

Use Docker Compose as the orchestration model for the ServiceHub platform.

## Decision Drivers

- Source-reviewable service topology.
- Familiar administration for a single-host HomeLab.
- Domain-based configuration files.
- Explicit health checks, dependencies, ports, networks, and bind mounts.
- Direct use by local administration and SSH deployment workflows.

## Options Considered

1. Docker Compose.
2. Kubernetes.
3. A collection of independent `docker run` scripts.
4. A commercial orchestration platform.

## Rationale

Compose matches the repository's current single-host deployment model, keeps topology visible in Git, and supports the `include` split used by the project. Kubernetes and commercial platforms would add cluster and operational requirements not present in the repository.

## Positive Consequences

- Simple local and remote commands.
- Domain ownership remains clear.
- Dependency conditions and health checks are explicit.
- Workflows can deploy application services without replacing foundations.

## Negative Consequences

- Compose 2.20+ is required for `include`.
- Orchestration is primarily host-local.
- Scheduling, replication, and cluster failover are not provided.
- Manual foundational updates remain necessary.

## Risks

- Configuration drift between local and remote hosts.
- No tested rollback model.
- Bind-mount ownership and host filesystem dependencies.
- Long-lived containers may restart without an integrated release process.

## Implementation Evidence

- [docker-compose.yml](../../docker-compose.yml)
- [compose/](../../compose/)
- [deployment workflow](../../.forgejo/workflows/61-deploy.yml)
- Root README prerequisites requiring Compose 2.20+

## Related Documents

- [Architecture](../architecture/ARCHITECTURE.md)
- [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md)
- [Runbook](../operations/RUNBOOK.md)

## Follow-up Actions

- Validate `docker compose config` and service health in staging.
- Define and test rollback behaviour.
- Confirm foundational-service update procedure.

