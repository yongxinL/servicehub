---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-009
title: Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries
version: "1.1"
status: Accepted
decision_basis: Owner discussion recorded on 2026-10-05 covering AI platform placement, Open WebUI domain ownership, observability strategy, OCI service scope, Confluence egress, and administrative endpoint access; compose and documentation changes implemented on `adr-009`, operational follow-ups pending; log collection and APM integration split out to ADR-010; egress enforced by a host firewall rule in the Docker `DOCKER-USER` chain, driven by a per-service policy file plus a global block of Atlassian CIDRs
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-05
updated: 2026-10-13
approved_by: project-owner
approval_mode: owner-self-approval
approved_on: 2026-10-12
note: Accepted retrospectively; the decision was implemented before formal acceptance.
tags:
  - servicehub
  - architecture
  - oci
  - ai
  - observability
  - egress
  - access-control
  - compose
related_documents:
  - ADR-002
  - ADR-004
  - ADR-005
  - ADR-008
  - ADR-010
  - ARCHITECTURE
  - DEPLOYMENT-ARCHITECTURE
  - MONITORING-ALERTING
  - SERVICE-INVENTORY
---

# ADR-009: Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries

<!-- Allowed status: Draft, Proposed, In Review, Accepted, Rejected, Superseded, Deprecated, Archived -->

## Context

The ServiceHub platform has been migrated to Oracle Cloud Infrastructure (OCI). The current compose domains and their services are:

| Domain | Services |
|---|---|
| `route` | Traefik |
| `infra` | Authentik, PostgreSQL, MariaDB |
| `devops` | Forgejo, Forgejo Runner |
| `webapp` | Confluence, oCIS, Open WebUI |
| `mailsv` | Stalwart, Bulwark |
| `obsvce` | VictoriaMetrics, VictoriaLogs, Alloy, Grafana |
| `aiserv` | LiteLLM, Hermes, llama.cpp |

Observations from operation on OCI:

- OCI resources are limited and should prioritise core platform services.
- AI workloads consume significant CPU, memory, and storage.
- OCI provides managed APM, Monitoring, Logging, and Tracing capabilities that the platform does not yet use; the self-hosted observability stack duplicates them.
- Open WebUI is deployed under the `webapp` domain even though it is part of the AI platform rather than a business application.
- Administrative endpoints are protected by IP allow lists (`compose/route.yml` `dashboard-whitelist`, `compose/mailsv.yml` `mailsvstalwart-whitelist`) and return HTTP 403 to unauthorised callers.
- Confluence Data Center does not require routine communication with Atlassian services for normal operation, but no outbound restriction is currently defined.

These forces affect deployment scope, resource allocation, and the security boundary of the platform, so they are decided together rather than as independent changes.

## Decision

The ServiceHub OCI deployment SHALL be rescoped to business-critical platform services only, AI services SHALL be relocated to local infrastructure, self-hosted observability SHALL be replaced by Oracle Cloud native services for OCI-hosted workloads, and the platform egress and administrative access policies SHALL be hardened as follows.

### 1. AI platform placement

All AI-related services SHALL be hosted on local infrastructure and SHALL NOT be deployed on the Oracle Cloud ServiceHub environment.

| | Domains |
|---|---|
| OCI deployment | `route`, `infra`, `devops`, `webapp`, `mailsv` |
| Local AI platform | `aiserv` — Open WebUI, LiteLLM, Hermes, Ollama, and future AI services |

Benefits:

- **Resource optimisation.** OCI resources remain dedicated to identity, documentation, DevOps, mail, and storage rather than AI workloads.
- **Scalability.** Local infrastructure can be expanded independently and can support future GPU acceleration.
- **Operational simplicity.** OCI remains focused on business-critical platform services.
- **Security.** AI experimentation and model-serving workloads remain isolated from internet-facing business services.

### 2. Open WebUI domain ownership

Open WebUI SHALL be reclassified as an AI platform component and moved from `webapp` to `aiserv`.

Open WebUI functions as the AI platform user interface and serves LiteLLM, Hermes, Ollama, and future AI agents. It is not a business application comparable to Confluence or oCIS.

The move follows the [ADR-008](ADR-008-standardise-service-naming-storage-and-bind-mounts.md) convention: the service is renamed `aiservowui` in `compose/aiserv.yml`, and its runtime state moves from `${APPS_DATA}/webapp/openwebui` to `${APPS_DATA}/aiserv/openwebui`.

### 3. Observability strategy

Oracle Cloud native observability services SHALL replace the self-hosted observability stack for OCI-hosted workloads.

The services selected, their credentials, and the log collection and APM integration design are recorded in [ADR-010](ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md); this ADR only retires the self-hosted deployment.

This decision applies only to workloads hosted within the OCI ServiceHub environment.

The observability requirements for locally hosted AI services (`aiserv`) are outside the scope of this ADR and SHALL be evaluated separately. Local AI services MAY use a different monitoring and observability approach appropriate to the local infrastructure.

Deployment impact:

- `compose/obsvce.yml` SHALL be removed from the OCI deployment.
- The `include` reference to `compose/obsvce.yml` in `../../../docker-compose.yml` SHALL be removed.

Repository strategy:

- `compose/obsvce.yml` MAY remain in source control for future reference.
- `compose/obsvce.yml` SHALL NOT be deployed to OCI.

Benefits:

- **Reduced resource consumption.** Lower CPU, memory, storage, and operational overhead.
- **Managed service model.** Monitoring and tracing become OCI-managed responsibilities for OCI-hosted workloads.
- **Simplified operations.** Reduced patching, backup, and maintenance burden.
- **Clear platform boundaries.** OCI monitoring is focused on OCI-hosted services, while local infrastructure monitoring can evolve independently as the AI platform grows.

### 4. OCI service scope

The ServiceHub OCI deployment SHALL exclude AI platform services and SHALL be restricted to:

```text
route    Traefik
infra    Authentik, PostgreSQL, MariaDB
devops   Forgejo, Forgejo Runner
webapp   Confluence, oCIS
mailsv   Stalwart, Bulwark
```

Principle: OCI SHALL host business-critical platform services; resource-intensive AI workloads SHALL be hosted on local infrastructure.

### 5. Confluence communication and internet egress policy

Confluence Data Center is intended to operate independently of Atlassian-hosted services during normal operation.

The platform requires communication with approved infrastructure dependencies such as database, identity, mail, DNS, and time-synchronisation services. Specific implementation details are intentionally not prescribed by this ADR.

Approved dependency classes:

| Dependency Type | Purpose |
|---|---|
| Database | Primary persistence |
| Identity | Authentication and SSO |
| Mail Delivery | Outbound notifications |
| DNS | Name resolution |
| Time Synchronisation | Time consistency |

Blocked by default:

- Atlassian Marketplace
- Atlassian Cloud Services
- Migration Services
- Application Tunnels
- General internet access

Exceptions: temporary outbound access MAY be granted for marketplace app installation, marketplace app upgrade, data migration activities, and approved maintenance tasks. Access SHALL be removed immediately after the activity is completed.

Benefits: reduced attack surface, reduced third-party dependency and privacy exposure, predictable self-managed operation, and operational independence from Atlassian service availability.

Implementation: two layers, both enforced on the host inside the Docker `DOCKER-USER` chain by [scripts/egress-guard.sh](../../../scripts/egress-guard.sh). (1) A per-service policy in [scripts/egress-policies.conf](../../../scripts/egress-policies.conf) — Confluence (`webappconf`) carries the `restricted` policy, which diverts the container's traffic to an `EGRESS_RESTRICTED` helper chain that returns for RFC1918 destinations (the approved dependency classes above) and for the host's own public IP — hairpin back to Traefik when public names such as `login.<domain>` resolve to it, detected at apply time from instance metadata — and logs then drops everything else; services are resolved by Compose service label, and an `allow-blocked` policy opts a service out of layer 2. (2) A global block drops traffic from any container to the CIDRs listed in `EGRESS_BLOCK_URL` (configured in `.env`; the feed is externalised so no vendor is named in the script), held in one `ipset` and refreshed at startup and by a daily timer. Confluence itself stays on the single `subnet` network. Installation, verification, the command reference, and the time-boxed exception procedure are recorded in [Container egress controls](../../operations/EGRESS-CONTROLS.md); the Confluence-specific destination table is in [../../operations/services/confluence.md](../../operations/services/confluence.md#outbound-egress-policy).

### 6. Administrative endpoint access policy

Administrative services SHALL continue to use IP allow-list protection.

The redirect mechanism SHALL NOT grant access to protected endpoints and SHALL preserve the existing IP allow-list enforcement.

Unauthorised requests SHALL be redirected to `https://login.<domain>` rather than displaying HTTP 403 responses.

| Caller | Path |
|---|---|
| Authorised IP | User → admin endpoint → service |
| Unauthorised IP | User → admin endpoint → `https://login.<domain>` |

Applies at minimum to `traefik.<domain>` and `mail.<domain>`; future administrative endpoints SHALL follow the same pattern.

Benefits: consistent user experience with all authentication entry beginning at a well-known endpoint, reduced information disclosure from service-specific forbidden pages, and a simpler end-user experience.

`login.<domain>` is the existing identity endpoint (`IDENTITY_DOMAIN` in [env.example](../../../env.example)), so no new service is required for the redirect target.

## Decision Drivers

- OCI resources are limited and must be prioritised for business-critical services.
- AI workloads are the largest consumer of CPU, memory, and storage.
- OCI offers managed APM, Monitoring, Logging, and Tracing that the platform does not use.
- AI experimentation and model serving should not run beside internet-facing business services.
- Local infrastructure can be expanded and can host future GPU acceleration.
- Confluence has no operational need for routine Atlassian communication.
- Administrative endpoints should present a consistent authentication entry point instead of an error page.

## Non-Goals

This ADR does not prescribe:

- Docker network segmentation.
- OCI network topology.
- Firewall implementation details.
- Traefik middleware implementation details.
- Oracle Cloud networking configuration.

These topics MAY be addressed by future ADRs if required.

The decision to restrict Confluence communication with Atlassian services is independent of any future Docker network segmentation initiative.

## Options Considered

1. Retain the current state: AI services partially on OCI, self-hosted observability, unrestricted Confluence egress, and HTTP 403 on unauthorised administrative access.
2. Rescope the OCI deployment, relocate all AI services and Open WebUI to the local `aiserv` platform, adopt Oracle Cloud native observability, and harden Confluence egress and administrative access (selected).
3. Apply only the administrative redirect and keep AI, observability, and egress unchanged, deferring the deployment rescope.

## Rationale

Option 2 satisfies every driver in a single, coherent rescope. Option 1 leaves AI workloads competing with business services on a constrained OCI tenancy, keeps a self-hosted observability stack duplicating managed OCI capability, and leaves both the egress and administrative access gaps in place. Option 3 fixes the visible access-control symptom while leaving the resource, isolation, and egress drivers untouched, and would require a second rescope later over the same compose files.

## Positive Consequences

- OCI resource usage reduced; cost and operational surface lowered.
- Oracle Cloud native observability eliminates self-hosted stack maintenance.
- Confluence egress boundary reduces attack surface.
- Administrative endpoints no longer return bare 403.
- Local AI platform can scale independently and support GPU.

## Negative Consequences

- OCI loses self-hosted metrics and logs history; replaced by Oracle native.
- Local AI platform requires separate deployment entrypoint and backup scope.
- Two deployment environments (OCI and local) increase operational complexity.
- ADR-010 configuration not yet implemented; OCI workloads currently unobserved.
- Confluence egress restriction may break marketplace or cloud integrations; exception procedure required.

## Risks

- Oracle native observability may not accept Docker log glob or lack read permission on container log directory; mitigate by verifying collection on deployed instance during implementation.
- ADR-010 credential model (APM data key vs OCI IAM) may be misapplied; mitigate by documenting both models and verifying on implementation.
- Ingested spans and log volume are billable; mitigate by starting with log collection only and enabling trace export per service.
- Collection failures are silent; mitigate by checking for recent log entries and APM traces after every change.
- Local `aiserv` observability strategy is deferred; residual gap until defined.

## Implementation Evidence

- `docker-compose.yml` include set updated to five domains on `adr-009` branch.
- `compose/aiserv.yml` and `compose/obsvce.yml` retained in source control.
- `compose/webapp.yml` updated: Open WebUI renamed to `aiservowui`, moved to `aiserv` domain, storage path updated.
- `scripts/egress-guard.sh` and `scripts/egress-policies.conf` enforce Confluence egress (`restricted` policy with host-public-IP return, global Atlassian CIDR block via ipset).
- Traefik file-provider middleware generated from `.env` for administrative redirect to `login.<domain>`.
- Living documentation updated: README, Architecture, Deployment architecture, Component catalogue, Service inventory, Monitoring and alerting, Backup and restore, affected service READMEs.
- `docker compose config --quiet` passes locally on reduced include set.

## Related Documents

- [ADR-002 Use Traefik as the Single HTTP Ingress](ADR-002-use-traefik-as-ingress.md) — middleware and routing behaviour changed by the administrative redirect.
- [ADR-004 Use Authentik for Central Identity](ADR-004-use-authentik-for-central-identity.md) — identity endpoint targeted by the redirect and an approved Confluence dependency.
- [ADR-005 Use LiteLLM for AI Workload Routing](ADR-005-use-litellm-for-ai-routing.md) — AI routing platform moved to local infrastructure.
- [ADR-008 Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables](ADR-008-standardise-service-naming-storage-and-bind-mounts.md) — naming, storage, and backup tier conventions applied when Open WebUI moves.
- [ADR-010 Collect OCI Logs and Integrate Service Telemetry with Oracle APM](ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md) — replacement for the retired self-hosted observability stack, split out of this decision.
- [Deployment architecture](../DEPLOYMENT-ARCHITECTURE.md) — deployment targets and environment model rescope by this decision.
- [Architecture](../ARCHITECTURE.md) — system and component boundaries.
- [Monitoring and alerting](../../operations/MONITORING-ALERTING.md) — self-hosted stack replaced by Oracle Cloud native services.
- [Container egress controls](../../operations/EGRESS-CONTROLS.md) — decision 5 installation, verification, commands, and exception procedure.
- [Service inventory](../../operations/SERVICE-INVENTORY.md) — service placement after the rescope.

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Move all AI services to local infrastructure and remove `compose/aiserv.yml` from the OCI deployment include set while retaining the compose definition in source control | ServiceHub Architecture | 2026-10-05 | Implemented in source control — `docker-compose.yml` include removed; local deployment entrypoint below |
| Move Open WebUI from `webapp` to `aiserv` (compose placement, `aiservowui` name, Traefik labels, storage path, variables, backup tier) | ServiceHub Architecture | 2026-10-05 | Implemented in source control — backup tier update recorded, runtime verification pending |
| Review and update backup, recovery, and retention coverage for `${APPS_DATA}/aiserv/openwebui` following the Open WebUI relocation | George Li | TBD | Open — path updated in source control, local backup/restore scope not re-scoped |
| Remove `compose/obsvce.yml` and its `docker-compose.yml` `include` from the OCI deployment; retain the file in source control | ServiceHub Architecture | 2026-10-05 | Implemented in source control — include removed, file retained |
| Configure Oracle APM, Monitoring, Logging, and Tracing for OCI-hosted workloads and record the configuration | ServiceHub Architecture | TBD | Moved to [ADR-010](ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md) |
| Define and document the observability strategy for locally hosted `aiserv` services after removal of the OCI `obsvce` deployment | ServiceHub Architecture | TBD | Proposed |
| Define the Confluence outbound allow list (PostgreSQL, Authentik, SMTP, DNS, NTP) and a time-boxed exception procedure | George Li | 2026-10-05 | Implemented in source control — enforced by [scripts/egress-guard.sh](../../../scripts/egress-guard.sh) from [scripts/egress-policies.conf](../../../scripts/egress-policies.conf) (`webappconf` restricted: RFC1918 and host-public-IP return, log then drop, in the Docker `DOCKER-USER` chain) plus a global block of Atlassian CIDRs via ipset; install, verification, and exception procedure recorded in [Container egress controls](../../operations/EGRESS-CONTROLS.md); rule logic verified by offline selftest plus a 21-check integration test; applied on the OCI host by the owner (2026-10-06) |
| Replace the HTTP 403 response on `traefik.<domain>` and `mail.<domain>` with a redirect to `https://login.<domain>` while retaining the IP allow list | ServiceHub Architecture | 2026-10-05 | Implemented in source control — rules generated from `.env` and hot-reloaded via the file provider; `docker compose config` verified; allowed/disallowed address test pending on a deployed target |
| Update architecture, deployment, monitoring, and service inventory documentation in the same change as the implementation | George Li | 2026-10-05 | Implemented — living documentation and service READMEs updated in the same change |
| Validate with `docker compose config` on the reduced include set and a deployment of the OCI scope, and record the evidence | ServiceHub Architecture | TBD | In progress — `docker compose config --quiet` passes locally; OCI deployment evidence outstanding |
| Define and document the local deployment entrypoint for the AI platform (`aiserv`) now that it is outside the OCI include set, including how local infrastructure is provisioned, started, and backed up | ServiceHub Architecture | TBD | Proposed |
