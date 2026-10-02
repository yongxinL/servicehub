---
project: ServiceHub
project_code: SVCHUB
document_type: PRD
document_id: PRD-001
title: ServiceHub Product Requirements
version: "1.0"
status: Proposed
lifecycle_stage: Requirements
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - requirements
  - product
related_documents:
  - CHARTER-001
  - ROADMAP-001
  - ARCHITECTURE
---

# ServiceHub Product Requirements

## Product Vision

ServiceHub should provide a coherent self-hosted platform for HomeLab administration, developer services, web collaboration, AI workloads, email, and observability, with repository-backed governance and operations knowledge.

Requirements describe intended capability. A requirement is not marked satisfied merely because configuration exists.

## User Groups

- HomeLab administrators.
- Developers and repository reviewers.
- Forgejo Actions operators.
- AI users and agent operators.
- Family or internal service users.
- Coding and documentation agents.

## Use Cases

- Deploy selected application services to a staging or production target.
- Understand route, authentication, database, storage, and dependency relationships.
- Validate Compose configuration before deployment.
- Diagnose a failed route, TLS process, identity flow, database, AI route, or telemetry pipeline.
- Back up PostgreSQL and persistent application data.
- Recover services after data loss only after a restoration procedure has been validated.
- Trace a requirement to architecture, phase, test, release, or operational evidence.
- Review significant design alternatives before implementation.

## Functional Requirements

| ID | Requirement | Evidence state |
|---|---|---|
| FR-001 | The platform SHALL be defined as a Compose project with domain files included by the root Compose file. | Repository implementation present; satisfaction not validated |
| FR-002 | Traefik SHALL be the single HTTP/HTTPS ingress for routed web services. | Confirmed in Compose and Traefik configuration |
| FR-003 | Services SHALL declare explicit Traefik routes rather than relying on default exposure. | Confirmed by `exposedbydefault=false` and labels |
| FR-004 | PostgreSQL SHALL host the default relational workloads configured by the stack. | Confirmed by service configuration |
| FR-005 | Authentik SHALL be available as the central identity provider. | Infrastructure confirmed; application coverage is partial |
| FR-006 | Forgejo and its runner SHALL support repository-hosted workflows. | Confirmed by Compose and workflow files |
| FR-007 | LiteLLM SHALL route AI requests between local and configured cloud inference targets. | Confirmed by configuration; runtime route not validated |
| FR-008 | Observability SHALL collect host, container, Traefik, and LiteLLM metrics. | Collector configuration confirmed; data presence not validated |
| FR-009 | Observability SHALL collect container logs into VictoriaLogs. | Collector configuration confirmed; retention not validated |
| FR-010 | Backup workflows SHALL create PostgreSQL dumps and a periodic persistent-data archive. | Workflow implementation present; execution evidence not available |
| FR-011 | Deployment workflows SHALL support `stag` and `prod` target selection. | Confirmed by workflow inputs |
| FR-012 | Documentation SHALL be maintained in `docs/` with stable IDs and indexes. | This documentation set |
| FR-013 | Optional services SHALL remain outside the default include set until explicitly enabled. | Confirmed for FastCRW, SearXNG, and optional WordPress |

## Non-Functional Requirements

| ID | Requirement | Evidence state |
|---|---|---|
| NFR-001 | Configuration SHALL be reviewable as source text in Git. | Confirmed |
| NFR-002 | Service names, routes, ports, networks, volumes, and environment variables SHALL have stable documented identifiers. | Documentation requirement |
| NFR-003 | The platform SHALL keep default services on an isolated Compose bridge network. | Confirmed `subnet` network |
| NFR-004 | Documentation SHALL use standard Markdown, relative links, and controlled metadata. | Documentation requirement |
| NFR-005 | Deployment SHALL prevent simultaneous conflicting workflow runs. | Confirmed concurrency groups |
| NFR-006 | Application services SHALL define health checks where an appropriate probe exists. | Mostly present; coverage requires validation |
| NFR-007 | Documentation SHALL distinguish Confirmed, Inferred, Proposed, and TBD claims. | Documentation requirement |
| NFR-008 | Future static publishing SHALL not require repository-specific absolute URLs. | Proposed publishing constraint |

## Security Requirements

| ID | Requirement |
|---|---|
| SEC-001 | Secret values SHALL remain outside tracked documentation and be referenced only by variable name. |
| SEC-002 | Routed services SHALL apply the stack security baseline or record an approved exception. |
| SEC-003 | The Traefik dashboard SHALL require access controls beyond network reachability. |
| SEC-004 | Public registration SHALL be disabled where administrator-controlled accounts are required. |
| SEC-005 | Sensitive repository files SHALL use appropriate ignore or encryption controls. |
| SEC-006 | Remote deployment SHALL verify SSH host keys when repository secrets provide them. |
| SEC-007 | Host and Docker socket exposure SHALL be reviewed and minimised over time. |
| SEC-008 | AI routing SHALL provide a local path for privacy-sensitive requests. |

These requirements are not claimed satisfied until security review and runtime validation occur.

## Reliability Requirements

| ID | Requirement |
|---|---|
| REL-001 | Service dependency conditions SHALL reflect startup ordering where the repository defines it. |
| REL-002 | Persistent service data SHALL use explicit bind mounts under the configured data root. |
| REL-003 | Deployment SHALL avoid replacing foundational services during application-service deploys. |
| REL-004 | Backup jobs SHALL fail visibly when required inputs, dumps, or archives are invalid. |
| REL-005 | RPO, RTO, off-host durability, and recovery procedures SHALL be defined and tested. |
| REL-006 | Rollback behaviour SHALL be documented before a governed release. |

## Maintainability Requirements

| ID | Requirement |
|---|---|
| MR-001 | Each domain SHALL remain in a dedicated Compose file. |
| MR-002 | Service-specific operational detail SHALL live with the service configuration and be linked from platform documentation. |
| MR-003 | Significant proposals SHALL use RFCs and implementation decisions SHALL use ADRs. |
| MR-004 | Implementation changes SHALL update affected documentation in the same change. |
| MR-005 | Deprecated names and variables SHALL be migrated or explicitly retired rather than silently reused. |

## Observability Requirements

| ID | Requirement |
|---|---|
| OBS-001 | Prometheus-compatible metrics SHALL be stored in VictoriaMetrics. |
| OBS-002 | Container logs SHALL be forwarded to VictoriaLogs. |
| OBS-003 | Grafana SHALL provision the repository dashboards and data sources. |
| OBS-004 | Critical services SHALL have service-specific health or error signals suitable for alerting. |
| OBS-005 | Alert severity, notification destinations, owners, and testing SHALL be defined. |
| OBS-006 | Metric and log retention SHALL be explicitly configured and reviewed. |

## Backup and Recovery Requirements

| ID | Requirement |
|---|---|
| BCR-001 | PostgreSQL data SHALL have transaction-consistent logical backups. |
| BCR-002 | Persistent application files SHALL have filesystem snapshots or archives. |
| BCR-003 | Backup copies SHALL be protected and copied off-host. |
| BCR-004 | Retention, encryption, RPO, and RTO SHALL be documented. |
| BCR-005 | Restoration SHALL be tested with recorded evidence. |
| BCR-006 | Secret, certificate, and repository recovery material SHALL be recoverable without appearing in documentation. |

## Acceptance Criteria

- `docs/` contains the required registers and templates with valid metadata and unique IDs.
- Every relative documentation link resolves.
- The root README links to the documentation home.
- `AGENTS.md` contains the documentation rules.
- Repository claims map to Compose, workflows, scripts, configuration, or Git evidence.
- No test, phase, release, restore, or approval is reported as complete without evidence.
- A runtime baseline test can be executed in staging without changing the implementation solely for documentation.

## Requirement Traceability Guidance

Link requirements to:

- Architecture: `ARCHITECTURE`, `SYSTEM-CONTEXT`, `COMPONENT-CATALOGUE`, `DATA-FLOW`, and `DEPLOYMENT-ARCHITECTURE`.
- Decisions: ADR IDs and related implementation files.
- Planning: phase IDs and task records.
- Verification: test IDs and recorded evidence.
- Delivery: release IDs and migration or rollback notes.
- Operations: runbook, backup, monitoring, inventory, and troubleshooting IDs.

Do not infer acceptance from the mere presence of a file. Record the evidence source and its validation state.

