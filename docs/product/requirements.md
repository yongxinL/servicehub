# Product Requirements - ServiceHub

| Field | Value |
|---|---|
| Title | Product Requirements |
| Status | Approved |
| Owner | project-owner |
| Created | 2026-10-13 |
| Updated | 2026-10-13 |
| Approved by project-owner / owner-self-approval / 2026-10-13 | |
| Vision | `vision.md` |

## 1. Scope

These requirements cover ServiceHub's intended capabilities as a self-hosted HomeLab services platform. They describe what the product must deliver, not how it is implemented. Technical design lives in architecture, ADRs, and specifications; operational detail lives in operations and runbooks. Requirements are not marked satisfied merely because configuration exists.

## 2. User groups and key journeys

**User groups:**

- HomeLab administrators.
- Developers and repository reviewers.
- Forgejo Actions operators.
- AI users and agent operators.
- Family or internal service users.
- Coding and documentation agents.

**Key journeys:**

- Deploy selected application services to a staging or production target.
- Understand route, authentication, database, storage, and dependency relationships.
- Validate Compose configuration before deployment.
- Diagnose a failed route, TLS process, identity flow, database, AI route, or telemetry pipeline.
- Back up PostgreSQL and persistent application data.
- Store, synchronise, and securely share family and project files through an authenticated cloud drive.
- Recover services after data loss only after a restoration procedure has been validated.
- Trace a requirement to architecture, phase, test, release, or operational evidence.
- Review significant design alternatives before implementation.

## 3. Product requirements

| Label | Requirement (capability or outcome) | Priority | Rationale | Specified by |
|---|---|---|---|---|
| PR-001 | The platform SHALL be defined as a Compose project with domain files included by the root Compose file. | Must | Repository implementation present; satisfaction not validated | To be specified |
| PR-002 | Traefik SHALL be the single HTTP/HTTPS ingress for routed web services. | Must | Confirmed in Compose and Traefik configuration | ADR-002 (Traefik ingress) |
| PR-003 | Services SHALL declare explicit Traefik routes rather than relying on default exposure. | Must | Confirmed by `exposedbydefault=false` and labels | ADR-002 (Traefik ingress) |
| PR-004 | PostgreSQL SHALL host the default relational workloads configured by the stack. | Must | Confirmed by service configuration | To be specified |
| PR-005 | Authentik SHALL be available as the central identity provider. | Must | Infrastructure confirmed; application coverage is partial | ADR-004 (Authentik central identity) |
| PR-006 | Forgejo and its runner SHALL support repository-hosted workflows. | Must | Confirmed by Compose and workflow files | To be specified |
| PR-007 | LiteLLM SHALL route AI requests between local and configured cloud inference targets. | Must | Confirmed by configuration; runtime route not validated | ADR-005 (LiteLLM AI routing) |
| PR-008 | Observability SHALL collect host, container, Traefik, and LiteLLM metrics. | Must | Collector configuration confirmed; data presence not validated | To be specified |
| PR-009 | Observability SHALL collect container logs into VictoriaLogs. | Must | Collector configuration confirmed; retention not validated | To be specified |
| PR-010 | Backup workflows SHALL create PostgreSQL dumps and a periodic persistent-data archive. | Must | Workflow implementation present; execution evidence not available | ADR-007 (dual-target backup) |
| PR-011 | Deployment workflows SHALL support `stag` and `prod` target selection. | Must | Confirmed by workflow inputs | To be specified |
| PR-012 | Documentation SHALL be maintained in `docs/` with stable IDs and indexes. | Must | This documentation set | To be specified |
| PR-013 | Optional services SHALL remain outside the default include set until explicitly enabled. | Should | Confirmed for FastCRW, SearXNG, and optional WordPress | To be specified |
| PR-014 | The cloud drive SHALL use oCIS with Authentik OIDC and local filesystem storage under `APPS_DATA`. | Must | Compose configuration present; runtime authentication and file operations not validated | ADR-006 (oCIS local filesystem) |
| PR-015 | Secret values SHALL remain outside tracked documentation and be referenced only by variable name. | Must | Security baseline | To be specified |
| PR-016 | Routed services SHALL apply the stack security baseline or record an approved exception. | Must | Security baseline | To be specified |
| PR-017 | The Traefik dashboard SHALL require access controls beyond network reachability. | Must | Security baseline | To be specified |
| PR-018 | Public registration SHALL be disabled where administrator-controlled accounts are required. | Must | Confirmed for Forgejo | To be specified |
| PR-019 | Sensitive repository files SHALL use appropriate ignore or encryption controls. | Must | Confirmed; git-crypt in use | To be specified |
| PR-020 | Remote deployment SHALL verify SSH host keys when repository secrets provide them. | Must | Security baseline | To be specified |
| PR-021 | Host and Docker socket exposure SHALL be reviewed and minimised over time. | Must | Risk register | To be specified |
| PR-022 | AI routing SHALL provide a local path for privacy-sensitive requests. | Must | Privacy requirement | ADR-005 (LiteLLM AI routing) |
| PR-023 | Service dependency conditions SHALL reflect startup ordering where the repository defines it. | Must | Reliability baseline | To be specified |
| PR-024 | Persistent service data SHALL use explicit bind mounts under the configured data root. | Must | Reliability baseline | To be specified |
| PR-025 | Deployment SHALL avoid replacing foundational services during application-service deploys. | Must | Reliability baseline | To be specified |
| PR-026 | Backup jobs SHALL fail visibly when required inputs, dumps, or archives are invalid. | Must | Reliability baseline | ADR-007 (dual-target backup) |
| PR-027 | RPO, RTO, off-host durability, and recovery procedures SHALL be defined and tested. | Must | Reliability and recovery | RFC-001 (reliability and recovery baseline) |
| PR-028 | Rollback behaviour SHALL be documented before a governed release. | Must | Reliability baseline | To be specified |
| PR-029 | Each domain SHALL remain in a dedicated Compose file. | Should | Maintainability | To be specified |
| PR-030 | Service-specific operational detail SHALL live with the service configuration and be linked from platform documentation. | Should | Maintainability | To be specified |
| PR-031 | Significant proposals SHALL use RFCs and implementation decisions SHALL use ADRs. | Should | Governance | To be specified |
| PR-032 | Implementation changes SHALL update affected documentation in the same change. | Should | Maintainability | To be specified |
| PR-033 | Deprecated names and variables SHALL be migrated or explicitly retired rather than silently reused. | Should | Maintainability | To be specified |
| PR-034 | Prometheus-compatible metrics SHALL be stored in VictoriaMetrics. | Must | Observability baseline | To be specified |
| PR-035 | Container logs SHALL be forwarded to VictoriaLogs. | Must | Observability baseline | To be specified |
| PR-036 | Grafana SHALL provision the repository dashboards and data sources. | Must | Observability baseline | To be specified |
| PR-037 | Critical services SHALL have service-specific health or error signals suitable for alerting. | Must | Observability baseline | To be specified |
| PR-038 | Alert severity, notification destinations, owners, and testing SHALL be defined. | Must | Observability baseline | To be specified |
| PR-039 | Metric and log retention SHALL be explicitly configured and reviewed. | Must | Observability baseline | To be specified |
| PR-040 | PostgreSQL data SHALL have transaction-consistent logical backups. | Must | Backup and recovery | ADR-007 (dual-target backup) |
| PR-041 | Persistent application files SHALL have filesystem snapshots or archives. | Must | Backup and recovery | ADR-007 (dual-target backup) |
| PR-042 | Backup copies SHALL be protected and copied off-host. | Must | Backup and recovery | ADR-007 (dual-target backup) |
| PR-043 | Retention, encryption, RPO, and RTO SHALL be documented. | Must | Backup and recovery | ADR-007 (dual-target backup) |
| PR-044 | Restoration SHALL be tested with recorded evidence. | Must | Backup and recovery | To be specified |
| PR-045 | Secret, certificate, and repository recovery material SHALL be recoverable without appearing in documentation. | Must | Backup and recovery | To be specified |
| PR-046 | Configuration SHALL be reviewable as source text in Git. | Should | Non-functional | To be specified |
| PR-047 | Service names, routes, ports, networks, volumes, and environment variables SHALL have stable documented identifiers. | Should | Non-functional | To be specified |
| PR-048 | The platform SHALL keep default services on an isolated Compose bridge network. | Should | Non-functional | To be specified |
| PR-049 | Documentation SHALL use standard Markdown, relative links, and controlled metadata. | Should | Non-functional | To be specified |
| PR-050 | Deployment SHALL prevent simultaneous conflicting workflow runs. | Should | Non-functional | To be specified |
| PR-051 | Application services SHALL define health checks where an appropriate probe exists. | Should | Non-functional | To be specified |
| PR-052 | Documentation SHALL distinguish Confirmed, Inferred, Proposed, and TBD claims. | Should | Non-functional | To be specified |
| PR-053 | Future static publishing SHALL not require repository-specific absolute URLs. | Could | Non-functional | To be specified |

*Priorities: Must, Should, Could. Labels are local references only.*

## 4. Constraints

- Docker Compose 2.20+ `include` support and the current service names are preserved.
- Existing ports, networks, volumes, environment variables, images, and routes are not changed for documentation convenience.
- Remote deployment uses SSH, Forgejo repository secrets, and passwordless sudo on target hosts.
- Sensitive files may be git-crypt protected; documentation must never reproduce their values.
- Australian English and standard Markdown are used where natural.

Technology appears here only where it is itself a product constraint (Compose `include`, current service names, and the static ports/routes that must be preserved).

## 5. Non-goals

- Designing or silently changing application or infrastructure behaviour through documentation.
- A dedicated family file-cloud platform at this stage.
- Guaranteed production availability, security, recovery, or compliance outcomes.
- Confluence or Forgejo Wiki content as the authoritative documentation store.
- Ownership, staffing, budget, approval, or completion claims not present in repository evidence.
- Arbitrary access to real secrets, private keys, recovery material, or production hostnames.

## 6. Success measures

- `docs/` contains the required registers and templates with valid metadata and unique IDs.
- Every relative documentation link resolves.
- The root README links to the documentation home.
- `AGENTS.md` contains the documentation rules.
- Repository claims map to Compose, workflows, scripts, configuration, or Git evidence.
- No test, phase, release, restore, or approval is reported as complete without evidence.
- A runtime baseline test can be executed in staging without changing the implementation solely for documentation.

## 7. Assumptions

- The repository is intended to remain the authoritative project record.
- Staging and production exist as workflow targets, but their runtime state is `Not yet verified`.
- The owner will review the charter before it becomes Accepted or Active.
- Confluence and any future wiki act as portals that link back to this repository.

## 8. Open questions

| Question | Raised | Decision needed by | Resolution |
|---|---|---|---|
| Which applications have completed Authentik OIDC integration? (PR-005, PR-014: coverage is partial or pending) | 2026-10-13 | Before the identity work in the platform delivery plan is marked complete | Open. To be recorded per application in [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) and verified in TEST-001. |
| What are the validated RPO, RTO, and off-host retention for backups? (PR-027, PR-043, PR-044: not yet defined) | 2026-10-13 | Before release 1.0.0 | Open. Values to be approved by the Project Owner with restore-exercise evidence (ADR-007, RFC-001). |
| Which alert destinations, owners, and severities apply to which services? (PR-037, PR-038: not yet defined) | 2026-10-13 | Before release 1.0.0 | Open. Alerting policy to be defined in docs/operations/MONITORING-ALERTING.md and tested. |

## 9. Change history

Not recorded in source documents.
