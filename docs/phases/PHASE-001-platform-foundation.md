---
project: ServiceHub
project_code: SVCHUB
document_type: PHASE
document_id: PHASE-001
title: Platform Foundation
version: "1.1"
status: Draft
lifecycle_stage: Planning
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-08
tags:
  - servicehub
  - phase
  - foundation
related_documents:
  - PRD-001
  - ARCHITECTURE
  - ADR-001
  - ADR-002
  - ADR-003
---

# PHASE-001: Platform Foundation

## Objective

Establish a reviewable Compose platform with a shared network, ingress, relational persistence, environment management, and deployment prerequisites.

## Scope

- Root Compose project and domain includes.
- `servicehub_subnet`.
- Traefik ingress, redirect, TLS configuration, routes, and security middleware.
- PostgreSQL and MariaDB persistence.
- `env.example` and `scripts/setup.sh`.
- Local start and remote deployment foundations.

## Deliverables

- [docker-compose.yml](../../docker-compose.yml)
- Domain files under [compose/](../../compose/)
- [Traefik configuration](../../shared/traefik/)
- [PostgreSQL](../../shared/postgresql/) and [MariaDB](../../shared/mariadb/) images
- [Environment template](../../env.example)
- [Setup script](../../scripts/setup.sh)
- Deployment and backup workflows

## Requirements Addressed

- FR-001 to FR-004
- NFR-001 to NFR-006
- SEC-002, SEC-005, SEC-006
- REL-001 to REL-004
- MR-001 and MR-004

## Dependencies

- Docker 24+ and Compose 2.20+.
- Linux target with Docker access and passwordless sudo for remote workflows.
- Domain and certificate strategy.
- Environment and secret values.
- Git-crypt key where encrypted certificate material is required.

## Tasks

- [x] Repository contains the Compose structure.
- [x] Repository contains ingress and security middleware configuration.
- [x] Repository contains database images and persistence definitions.
- [x] Repository contains environment generation and migration logic (migration logic later removed after the `.env` rename was applied manually).
- [ ] Validate Compose configuration in the intended environment.
- [ ] Validate HTTP redirect, TLS, routes, and security headers.
- [ ] Validate database health and first-boot creation.
- [ ] Validate remote prerequisites and deployment.
- [ ] Record phase acceptance evidence.

## Risks

- High-privileged ingress container and Docker socket access.
- Bind-mount ownership failures.
- Unvalidated certificate and DNS state.
- Passwordless sudo scope.
- No rollback procedure.

## Acceptance Criteria

- `docker compose config` succeeds in the target environment.
- All default services reach expected health states.
- HTTP redirects to HTTPS and each intended host route responds.
- TLS trust and renewal match the selected mode.
- Databases persist and are reachable by dependent services.
- Remote-access workflow checks pass for the target.
- Deployment completes without unintended foundational replacement.
- Evidence links are attached to this phase.

## Evidence Required

- Compose validation output.
- Container health output.
- Route and TLS results.
- Database dependency results.
- Remote-access and deployment workflow logs.
- Post-deployment validation.

No such execution record is present in this documentation set.

## Completion Summary

**Retrospective validation required.** Repository implementation exists, but phase completion is not claimed.

## Follow-up Work

- Execute the foundation portion of [TEST-001](../testing/TEST-001-platform-baseline-validation.md).
- Document rollback.
- Review privileged and direct network exposure.

