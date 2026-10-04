---
project: ServiceHub
project_code: SVCHUB
document_type: ARCHITECTURE
document_id: ARCHITECTURE
title: ServiceHub Architecture
version: "1.1"
status: Draft
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-04
tags:
  - servicehub
  - architecture
  - docker
related_documents:
  - SYSTEM-CONTEXT
  - COMPONENT-CATALOGUE
  - DATA-FLOW
  - DEPLOYMENT-ARCHITECTURE
  - ADR-INDEX
  - ADR-006
  - ADR-007
---

# ServiceHub Architecture

## Architecture Overview

ServiceHub is a Docker Compose project named `servicehub`. The root file includes eight domain Compose files for routing, databases, identity, developer services, web applications, AI, observability, and email. All included services join the `subnet` bridge network.

```mermaid
flowchart LR
    Users[Users and administrators] --> Internet
    Internet --> Traefik[routetraefik]
    Traefik --> Authentik[Authentik]
    Traefik --> Forgejo[Forgejo]
    Traefik --> Web[Confluence and Open WebUI]
    Traefik --> Cloud[webappocis (oCIS)]
    Traefik --> AI[Clients and Hermes]
    Traefik --> Grafana[Grafana]
    Traefik --> Email[Stalwart and Bulwark]
    AI --> LiteLLM[LiteLLM]
    LiteLLM --> Local[llama.cpp]
    LiteLLM --> CloudProvider[Configured cloud provider]
    Forgejo --> PostgreSQL[(PostgreSQL)]
    Authentik --> PostgreSQL
    Authentik -.->|OIDC| Cloud
    Cloud --> CloudData[(Local filesystem)]
    LiteLLM --> PostgreSQL
    Web --> PostgreSQL
    Email --> PostgreSQL
    Runner[Forgejo Actions runner] --> SSH[Staging or production SSH]
    Runner --> SourceSSH[Backup source SSH]
    Runner --> Home[Home Server via Restic]
    Runner --> Drive[Google Drive via Rclone]
    Collector[Alloy] --> Metrics[(VictoriaMetrics)]
    Collector --> Logs[(VictoriaLogs)]
    Metrics --> Grafana
    Logs --> Grafana
```

This diagram is an architectural summary, not a complete dependency graph. Exact conditions and persistence are in the [component catalogue](COMPONENT-CATALOGUE.md).

## Architecture Principles

- Keep implementation and documentation in the same repository.
- Use explicit Compose domains and stable service names.
- Use one HTTP ingress for routed web services.
- Keep databases off the public ingress.
- Prefer explicit persistence paths under `APPS_DATA`.
- Separate default services from optional add-ons.
- Prefer local AI processing for privacy-sensitive requests while retaining a configured cloud route.
- Treat privileged access, dynamic ports, and host mounts as reviewable risks.
- Record decisions in ADRs and significant alternatives in RFCs.

## Major Subsystems

| Subsystem | Compose domain | Principal services |
|---|---|---|
| Routing and TLS | `compose/route.yml` | `routetraefik` |
| Relational data | `compose/infra.yml` | `infrapgsql`, `inframariadb` |
| Identity | `compose/infra.yml` | `infraauth`, `infraauthwrk`, `infraauthinit` |
| Developer services | `compose/devops.yml` | `devopsforgejo`, `devopsrunner`, `devopsforgejoinit` |
| Web applications | `compose/webapp.yml` | `webappconf`, `webappowui`, `webappocis`, `webappocisinit` |
| AI platform | `compose/aiserv.yml` | `aiservhermes`, `aiservlitellm`, `aiservllamacpp`, `aiservhermesinit` |
| Observability | `compose/obsvce.yml` | `obsvcealloy`, `obsvcevm`, `obsvcevlogs`, `obsvcegrafana`, `obsvcegrafanainit` |
| Email | `compose/mailsv.yml` | `mailsvstalwart`, `mailsvbulwark`, `mailsvbulwarkinit` |

## Security Boundaries

- **External ingress:** Traefik publishes 80 and 443 and is the designed web boundary.
- **Docker network:** Included services communicate through `servicehub_subnet`; databases publish no host ports.
- **Identity boundary:** Grafana uses Authentik forward auth; oCIS uses an Authentik OIDC authorization-code flow. Authentik itself is application-authenticated. Other Authentik integrations vary and are not all configured in Compose.
- **Privileged boundary:** Traefik, Authentik's worker, and Alloy have Docker socket access; Alloy is privileged and mounts host filesystem paths.
- **Deployment and backup boundaries:** Forgejo runner jobs reach remote hosts over SSH using protected repository secrets; backup transfer credentials are supplied only to the backup workflow environment.
- **Direct-host boundary:** Hermes, LiteLLM, llama.cpp, VictoriaMetrics, VictoriaLogs, and Stalwart publish selected host ports independent of Traefik.

These boundaries are Confirmed from configuration. Their security effectiveness requires runtime review.

## Data Platforms

- **PostgreSQL 16:** default database for Authentik, Forgejo, LiteLLM, Confluence, and Stalwart; persistent path `${APPS_DATA}/infra/postgresql`.
- **MariaDB 11.8:** retained for the optional WordPress service; not used by the default stack according to `env.example`.
- **VictoriaMetrics:** Prometheus-compatible metric storage under `${APPS_DATA}/obsvce/victoriametrics`.
- **VictoriaLogs:** log storage under `${APPS_DATA}/obsvce/victorialogs`.
- **Grafana:** dashboard and alert-rendering state under `${APPS_DATA}/obsvce/grafana`.

The `webappocis` oCIS service uses local filesystem storage and has no dedicated PostgreSQL database. PostgreSQL continues to store Authentik identity data used by the OIDC flow. Repository configuration is recorded in [ADR-006](../adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md); runtime authentication and file operations remain unvalidated.

## Identity Architecture

Authentik runs a server, worker, and permission-initialisation service. PostgreSQL stores Authentik state; media and templates use bind mounts. The repository documents:

- Grafana Traefik forward authentication.
- Stalwart LDAP authentication through an Authentik LDAP outpost.
- Recommended Authentik delegation for Forgejo and Confluence.
- oCIS authorization-code OIDC configuration using the Authentik provider issuer and public client ID.

The Compose files do not prove that every application integration has been configured at runtime. Identity coverage beyond Grafana and the documented Stalwart path is `Not yet verified`.

Bulwark uses a password form validated by Stalwart, not OIDC. The Traefik dashboard uses basic authentication and an IP allowlist.

## AI Architecture

Hermes calls LiteLLM using the virtual model `hermes`. LiteLLM routes to:

- `hephaestus`: local llama.cpp Gemma service by default and for privacy-sensitive content.
- `prometheus`: configured cloud provider for explicit cloud tags, large inputs, complexity signals, unhealthy local inference, and configured fallback conditions.

Open WebUI is a separate client surface. FastCRW, SearXNG, LightPanda, and Chromium are optional and excluded from the default root include.

The routing configuration is Confirmed; provider availability, privacy enforcement at runtime, and fallback outcomes are `Requires runtime validation`.

## Observability Architecture

Grafana Alloy collects host metrics, container metrics, Traefik metrics, LiteLLM metrics, Alloy metrics, and Docker container logs. It remote-writes metrics to VictoriaMetrics and pushes logs to VictoriaLogs. Grafana provisions both data sources and repository dashboards.

Grafana alerting is enabled with `render_only_panels=true`. No notification channel, severity model, ownership list, or alert test evidence is present in the repository.

## Deployment Architecture

Forgejo Actions deployment workflows run on the host-mode `ssh-deploy` runner. Deployment SSHes to a staging or production target, updates a Git checkout, restores git-crypt and environment material when configured, and rebuilds application services with `--no-deps`. Foundational services are excluded from CI deployment.

The backup workflow runs on the existing `devopsrunner` with the `ssh-deploy` label. It SSHes to the target to create PostgreSQL dumps and a periodic `APPS_DATA` archive, then configures Restic transfer to the Home Server and Rclone transfer to Google Drive under [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md). Repository configuration is present; image build, transfers, integrity checks, retention, and restores are not runtime-validated.

See [deployment architecture](DEPLOYMENT-ARCHITECTURE.md) for details and validation gaps.

## Persistence Architecture

The default stack uses host bind mounts rather than named Docker volumes:

- Relational data: `${APPS_DATA}/infra/postgresql` and `${APPS_DATA}/infra/mariadb`
- Identity: `${APPS_DATA}/infra/authentik/...`
- Repositories and runner state: `${APPS_DATA}/devops/forgejo/data`, `.../runner`, and `.../workspace`
- Web applications: `${APPS_DATA}/webapp/confluence` and `${APPS_DATA}/webapp/openwebui`
- Cloud drive: `${APPS_DATA}/webapp/ocis/config` and `${APPS_DATA}/webapp/ocis/data`
- AI: `${APPS_DATA}/aiserv/litellm`, `${APPS_DATA}/aiserv/llamacpp`, and `${HERMES_DATA_00:-${APPS_DATA}/aiserv/hermes/00}`
- Observability: `${APPS_DATA}/obsvce/victoriametrics`, `.../victorialogs`, and `.../grafana`
- Email: `${APPS_DATA}/mailsv/stalwart` and `${APPS_DATA}/mailsv/bulwark/...`
- Certificates: `${APPS_DATA}/shared/certs`

Configuration files under `shared/` are mostly read-only mounts. Off-host durability and restore capability are not yet verified.

## Known Constraints

- Compose `include` requires Compose 2.20+.
- Remote deployment requires SSH credentials, repository secrets, and passwordless sudo.
- Forgejo is not deployed by CI because doing so would disrupt the runner.
- Traefik's Docker provider requires Docker socket access.
- Local inference is resource intensive and has a longer health-check start period.
- Several APIs publish host ports without a documented host firewall rule.
- Optional FastCRW and WordPress are not included by the root Compose file.

## Open Architecture Concerns

- Runtime validation of routes, TLS, identity, health, AI routing, telemetry, and backups.
- Runtime validation of the configured ADR-007 transfers and retention, plus execution of the restore procedure, RPO, and RTO evidence.
- Alert notification, ownership, and testing.
- High-privileged container and host mount review.
- Authentik application coverage and break-glass account controls.
- Direct port exposure and network policy.
- The optional WordPress router does not declare `secure-chain` in its tracked Compose file.
- Rollback model and first governed release.
- Runtime validation of the configured family file-cloud service and its recovery path.

Related records: [system context](SYSTEM-CONTEXT.md), [data flow](DATA-FLOW.md), [ADR register](../adr/README.md), and [baseline test plan](../testing/TEST-001-platform-baseline-validation.md).
