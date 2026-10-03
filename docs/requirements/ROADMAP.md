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
updated: 2026-10-03
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
  - ADR-006
  - ADR-007
  - RFC-001
  - RFC-002
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
- Repository configuration for the `wbappcloudrv` oCIS service with Authentik OIDC and local filesystem paths.
- Hermes, LiteLLM, and llama.cpp AI services with configured local/cloud routing.
- VictoriaMetrics, VictoriaLogs, Grafana Alloy, and Grafana provisioning.
- Stalwart and Bulwark email services.
- Daily PostgreSQL dump workflow and weekly full persistent-data archive workflow.

“Implemented” describes repository content only. Runtime results remain `Not yet verified`.

## Current Priorities

1. Review and approve the charter, requirements, and architecture accuracy.
2. Confirm or revise inferred ADR statuses.
3. Validate the repository-configured oCIS cloud-drive platform under ADR-006.
4. Validate Authentik OIDC, local storage, routing, file operations, and recovery for oCIS.
5. Validate phase evidence against Git history and runtime behaviour.
6. Execute the platform baseline test in staging.
7. Implement the ADR-007 Home Server and Google Drive backup targets, restoration tests, retention, RPO, and RTO.
8. Define the first governed release and its rollback evidence.

## Phase Sequence

| Sequence | Phase | Primary outcome |
|---|---|---|
| 1 | [PHASE-001 Platform Foundation](../phases/PHASE-001-platform-foundation.md) | Compose, network, ingress, data, and deployment baseline |
| 2 | [PHASE-002 Identity and Developer Services](../phases/PHASE-002-identity-and-developer-services.md) | Authentik, Forgejo, runner, and application identity coverage |
| 3 | [PHASE-003 AI Platform](../phases/PHASE-003-ai-platform.md) | Local inference, LiteLLM routing, privacy, and client access |
| 4 | [PHASE-004 Observability and Operational Hardening](../phases/PHASE-004-observability-and-operational-hardening.md) | Metrics, logs, dashboards, backup, restoration, and release controls |

No dates are assigned because the repository does not provide a reliable schedule.

## Accepted Roadmap Entry

| Feature | Phase | Priority | Decision | Delivery status |
|---|---|---|---|---|
| Cloud Drive Platform | Infrastructure Services | High | [ADR-006](../adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md) | Repository configuration added; runtime validation pending |

Deploy oCIS integrated with Authentik SSO to provide personal and family storage, shared spaces, secure file sharing, and a foundation for future office integration.

### Cloud Drive Deliverables

- oCIS deployment with Traefik routing and health checks.
- Authentik OIDC integration.
- Persistent local configuration and file-storage paths included in backup scope.
- Backup automation and Google Drive replication under ADR-007.
- Recovery runbook and restoration evidence.
- Monitoring dashboards and alert validation.

### Cloud Drive Dependencies

- Authentik, backed by PostgreSQL.
- Forgejo Actions.
- The dedicated backup runner and protected backup-target credentials.
- Traefik.
- An approved staging environment and validation evidence.

## Future Candidates

- Restore rehearsal and documented recovery evidence.
- Encryption, retention policy, and restoration automation for the accepted ADR-007 backup targets.
- Consolidated alert routing, severity policy, ownership, and alert tests.
- Security review of dynamic ports, Docker socket access, privileged containers, and host mounts.
- Full identity integration coverage and break-glass controls.
- Static documentation publishing configuration.
- A governed first release with migration and rollback notes.
- Office or collaboration integration beyond the initial oCIS file-sharing scope.

## Dependencies

- Owner approval for governance records.
- Staging access and a valid environment configuration.
- Repository secrets for remote workflows.
- Git-crypt recovery key availability.
- Tested backups before recovery claims.
- Home Server and Google Drive access for the ADR-007 backup targets.
- Backup runner image, retention policy, and protected credentials.
- DNS and certificate state for TLS validation.
- Runtime logs and metrics for observability validation.

## Exit Criteria

Each phase must satisfy its own acceptance criteria and record the required evidence. Repository presence alone is insufficient. A phase becomes `Completed` only after evidence is attached or linked and the owner accepts it.

## Deferred Items

- MinIO, OCI Object Storage, and S3 storage for the initial oCIS deployment.
- Nextcloud or a broader collaboration suite unless ADR-006 is revised.
- Alternative cloud-drive platforms unless requirements change.
- Release dates not present in repository evidence.
- Production hostname, approval, ownership, and recovery-objective claims.
