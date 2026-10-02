---
project: ServiceHub
project_code: SVCHUB
document_type: ROADMAP
document_id: ROADMAP-001
title: ServiceHub Roadmap
version: "1.0"
status: Draft
lifecycle_stage: Planning
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - roadmap
  - planning
related_documents:
  - PRD-001
  - PHASE-001
  - PHASE-002
  - PHASE-003
  - PHASE-004
---

# ServiceHub Roadmap

## Current State

The repository contains implementation associated with platform foundation, identity and developer services, AI routing and inference, observability, deployment workflows, and backup workflows. Git history provides implementation activity, but the repository does not contain a formal phase completion record or a complete runtime validation report.

Current state is therefore **implemented in part, not yet verified as a governed release**.

## Completed or Implemented Capabilities

- Compose project with domain includes and a shared `subnet` network.
- Traefik ingress, security middleware, TLS resolver configuration, and service routes.
- PostgreSQL and MariaDB images with persistent bind mounts.
- Authentik server and worker services.
- Forgejo, host-mode runner, and repository workflows.
- Confluence and Open WebUI services.
- Hermes, LiteLLM, and llama.cpp AI services with configured local/cloud routing.
- VictoriaMetrics, VictoriaLogs, Grafana Alloy, and Grafana provisioning.
- Stalwart and Bulwark email services.
- Daily PostgreSQL dump workflow and weekly full persistent-data archive workflow.

“Implemented” describes repository content only. Runtime results remain `Not yet verified`.

## Current Priorities

1. Review and approve the charter, requirements, and architecture accuracy.
2. Confirm or revise inferred ADR statuses.
3. Decide RFC-001 reliability and recovery baseline.
4. Record the RFC-002 family cloud platform decision.
5. Validate phase evidence against Git history and runtime behaviour.
6. Execute the platform baseline test in staging.
7. Define backup restoration, off-host protection, RPO, and RTO.
8. Define the first governed release and its rollback evidence.

## Phase Sequence

| Sequence | Phase | Primary outcome |
|---|---|---|
| 1 | [PHASE-001 Platform Foundation](../phases/PHASE-001-platform-foundation.md) | Compose, network, ingress, data, and deployment baseline |
| 2 | [PHASE-002 Identity and Developer Services](../phases/PHASE-002-identity-and-developer-services.md) | Authentik, Forgejo, runner, and application identity coverage |
| 3 | [PHASE-003 AI Platform](../phases/PHASE-003-ai-platform.md) | Local inference, LiteLLM routing, privacy, and client access |
| 4 | [PHASE-004 Observability and Operational Hardening](../phases/PHASE-004-observability-and-operational-hardening.md) | Metrics, logs, dashboards, backup, restoration, and release controls |

No dates are assigned because the repository does not provide a reliable schedule.

## Future Candidates

- Restore rehearsal and documented recovery evidence.
- Off-host backup copies, encryption, retention policy, and restoration automation.
- Consolidated alert routing, severity policy, ownership, and alert tests.
- Security review of dynamic ports, Docker socket access, privileged containers, and host mounts.
- Full identity integration coverage and break-glass controls.
- Static documentation publishing configuration.
- A governed first release with migration and rollback notes.
- Family file-cloud pilot only if a validated file synchronisation or sharing requirement emerges.

## Dependencies

- Owner approval for governance records.
- Staging access and a valid environment configuration.
- Repository secrets for remote workflows.
- Git-crypt recovery key availability.
- Tested backups before recovery claims.
- DNS and certificate state for TLS validation.
- Runtime logs and metrics for observability validation.

## Exit Criteria

Each phase must satisfy its own acceptance criteria and record the required evidence. Repository presence alone is insufficient. A phase becomes `Completed` only after evidence is attached or linked and the owner accepts it.

## Deferred Items

- oCIS, ownCloud Infinite Scale, and Nextcloud deployment.
- Dedicated cloud platform decisions without a validated requirement.
- Release dates not present in repository evidence.
- Production hostname, approval, ownership, and recovery-objective claims.

