---
project: ServiceHub
project_code: SVCHUB
document_type: ARCHITECTURE
document_id: COMPONENT-CATALOGUE
title: ServiceHub Component Catalogue
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
  - inventory
related_documents:
  - ARCHITECTURE
  - SERVICE-INVENTORY
  - DATA-FLOW
  - ADR-006
  - ADR-007
---

# ServiceHub Component Catalogue

## Default Compose Components

All default components use the `servicehub_subnet` network. “No host route” means no Traefik label is present; direct `ports` mappings are listed separately.

| Compose service | Purpose | Image or build | Compose file | Internal port | Published port | Dependencies | Persistent storage | Health check | Public route | Authentication | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `routetraefik` | HTTP ingress, TLS, discovery, metrics, logs | Build `shared/traefik/` | `compose/route.yml` | 80, 443 | 80, 443 | None declared | `${APPS_DATA}/certs`; read-only advanced config; read-only Docker socket | `traefik healthcheck --ping` | `${TRAEFIK_DOMAIN}` dashboard | Basic auth plus IP allowlist | [Compose](../../compose/route.yml), [README](../../shared/traefik/README.md) |
| `inframariadb` | Optional MySQL-compatible database | Build `shared/mariadb/` | `compose/infra.yml` | 3306 service target | None | None declared | `${APPS_DATA}/databases/mariadb` | MariaDB `healthcheck.sh` | None | Database credentials from environment | [Compose](../../compose/infra.yml) |
| `infrapgsql` | Primary relational database | Build `shared/postgresql/` | `compose/infra.yml` | 5432 service target | None | None declared | `${APPS_DATA}/databases/pgsqldb` | `pg_isready` | None | Database credentials from environment | [Compose](../../compose/infra.yml) |
| `infraauthinit` | Authentik bind-mount ownership initialiser | `busybox:latest` | `compose/infra.yml` | None | None | None declared | Authentik media and templates | One-shot, no health check | None | Not applicable | [Compose](../../compose/infra.yml) |
| `infraauthwrk` | Authentik background worker | Build `shared/authentik/` | `compose/infra.yml` | No HTTP listener | None | `infraauthinit` completed; PostgreSQL healthy | Authentik media and templates; Docker socket | None | None | Authentik application login | [Compose](../../compose/infra.yml), [README](../../shared/authentik/README.md) |
| `infraauth` | Authentik UI and API | Build `shared/authentik/` | `compose/infra.yml` | 9000 | None | Traefik healthy; worker started | Authentik media and templates | None declared | `${AUTHN_DOMAIN}` | Authentik application login | [Compose](../../compose/infra.yml) |
| `devopsforgejoinit` | Forgejo and runner directory initialiser | `busybox:latest` | `compose/devops.yml` | None | None | None declared | Repositories and runner state | One-shot, no health check | None | Not applicable | [Compose](../../compose/devops.yml) |
| `devopsforgejo` | Forgejo repositories, issues, and Actions | Build `shared/forgejo/server/` | `compose/devops.yml` | 3000 | None | PostgreSQL healthy; Authentik healthy | `${APPS_DATA}/platform/repos` | `/api/healthz` | `${DEPOT_DOMAIN}` | Application login; registration disabled; OIDC coverage not verified | [Compose](../../compose/devops.yml), [README](../../shared/forgejo/README.md) |
| `devopsrunner` | Host-mode Forgejo Actions runner | Build `shared/forgejo/actions/` | `compose/devops.yml` | No HTTP listener | None | Initialiser completed; Forgejo healthy | Runner state and workspace | Process plus non-empty `.runner` | None | Runner registration secret | [Compose](../../compose/devops.yml), [config](../../shared/forgejo/actions/config.yml) |
| `webappconf` | Confluence web application | Build `shared/confluence/` | `compose/webapp.yml` | 8090 | None | Authentik healthy | `${APPS_DATA}/webapps/confluence` | `/status` | `${WBHOME_DOMAIN}` and apex `${DOMAIN_NAME}` | Application login; Authentik directory integration not verified | [Compose](../../compose/webapp.yml), [README](../../shared/confluence/README.md) |
| `webappowui` | Open WebUI chat client | Build `shared/openwebui/` | `compose/webapp.yml` | 8080 | None | Traefik healthy | `${APPS_DATA}/openwebui` | None declared | `${OWEBUI_DOMAIN}` | Not yet verified | [Compose](../../compose/webapp.yml), [README](../../shared/openwebui/README.md) |
| `webappocisinit` | oCIS configuration and data ownership initialiser | `busybox:latest` | `compose/webapp.yml` | None | None | None declared | oCIS config and data paths | One-shot, no health check | None | Not applicable | [Compose](../../compose/webapp.yml), [README](../../shared/owncloud/README.md) |
| `webappocis` | ownCloud Infinite Scale cloud drive | `webappocis:latest` | `compose/webapp.yml` | 9200 | None | Initialiser completed; Authentik healthy; Traefik healthy | `${APPS_DATA}/cloud/ocis/config`, `${APPS_DATA}/cloud/ocis/data` | `/status.php` | `${WBDRIVE_DOMAIN}` | Authentik OIDC; runtime flow not validated | [Compose](../../compose/webapp.yml), [README](../../shared/owncloud/README.md) |
| `aiservhermesinit` | Hermes data ownership initialiser | `busybox:latest` | `compose/aiserv.yml` | None | None | None declared | Hermes data path | One-shot, no health check | None | Not applicable | [Compose](../../compose/aiserv.yml) |
| `aiservhermes` | Hermes agent and workspace | Build `shared/hermesagent/` | `compose/aiserv.yml` | 12320 workspace; 12330 API | 12320 | Initialiser completed | Hermes data path; read-only Docker socket | API `/health` | Conditional `${HERMES_WORKSPACE_DOMAIN_00}` | Workspace password; API key | [Compose](../../compose/aiserv.yml), [README](../../shared/hermesagent/README.md) |
| `aiservlitellm` | AI router, UI, metrics, and usage database | Build `shared/litellm/` | `compose/aiserv.yml` | 12380 | 12380 | PostgreSQL healthy | `${APPS_DATA}/litellm` | Bearer-authenticated `/health/liveliness` | None through Traefik | Master API key and UI credentials | [Compose](../../compose/aiserv.yml), [README](../../shared/litellm/README.md) |
| `aiservllamacpp` | Local llama.cpp inference | Build `shared/llamacpp/` | `compose/aiserv.yml` | 12386 | 12386 | None declared | `${APPS_DATA}/llamacpp` | `/health` after 120 s start period | None through Traefik | Local API key configured as `none` by default | [Compose](../../compose/aiserv.yml), [README](../../shared/llamacpp/README.md) |
| `obsvcevm` | Metrics store | Build `shared/victoriametrics/` | `compose/obsvce.yml` | 8428 | 8428 | None declared | `${APPS_DATA}/victoriametrics` | `/health` | None through Traefik | Not yet verified | [Compose](../../compose/obsvce.yml) |
| `obsvcevlogs` | Log store | Build `shared/victorialogs/` | `compose/obsvce.yml` | 9428 | 9428 | None declared | `${APPS_DATA}/victorialogs` | `/health` | None through Traefik | Not yet verified | [Compose](../../compose/obsvce.yml) |
| `obsvcealloy` | Telemetry collector | Build `shared/grafana/alloy/` | `compose/obsvce.yml` | 9080 | None | Both stores healthy | Read-only config and GeoIP; host mounts and Docker socket | `/health` | None | Not applicable | [Compose](../../compose/obsvce.yml), [config](../../shared/grafana/alloy/config.alloy) |
| `obsvcegrafanainit` | Grafana ownership initialiser | `busybox:latest` | `compose/obsvce.yml` | None | None | None declared | Grafana data | One-shot, no health check | None | Not applicable | [Compose](../../compose/obsvce.yml) |
| `obsvcegrafana` | Dashboards and Grafana UI | Build `shared/grafana/` | `compose/obsvce.yml` | 3000 | None | Traefik healthy; initialiser completed; Alloy healthy | Grafana data plus read-only provisioning | `/api/health` | `${OBSVC_DOMAIN}` | Authentik forward auth plus Grafana credentials | [Compose](../../compose/obsvce.yml) |
| `mailsvstalwart` | Stalwart mail server | Build `shared/stalwart/` | `compose/mailsv.yml` | 8080 | 25, 465, 587, 993 | Traefik healthy; PostgreSQL healthy | Mailbox state and certificate store | `/healthz/live` | `${EMAIL_HOST}` | LDAP directory documented; recovery admin fallback | [Compose](../../compose/mailsv.yml), [README](../../shared/stalwart/README.md) |
| `mailsvbulwarkinit` | Webmail state ownership initialiser | `busybox:latest` | `compose/mailsv.yml` | None | None | None declared | Webmail settings, admin, state, telemetry | One-shot, no health check | None | Not applicable | [Compose](../../compose/mailsv.yml) |
| `mailsvbulwark` | Bulwark JMAP webmail | Build `shared/bulwark/` | `compose/mailsv.yml` | 3000 | None | Initialiser completed; Stalwart healthy | Four webmail state paths | `/api/health` | `${WEBMAIL_DOMAIN}` | Password form validated by Stalwart | [Compose](../../compose/mailsv.yml), [README](../../shared/bulwark/README.md) |

## Optional Components

These services exist in repository files but are not included by the root Compose file.

| Compose service | Purpose | Compose file | Internal port | Route or exposure | Storage | State |
|---|---|---|---|---|---|---|
| `aiagnsearxng` | Search backend for FastCRW | `shared/searxng/compose.yml` | 12361 | Internal | Not evident in Compose | Proposed enablement |
| `aiagnlighpda` | Lightweight JavaScript renderer | `shared/fastcrw/lightpanda/compose.yml` | 12362 | Internal | Ephemeral container state | Proposed enablement |
| `aiagnchromum` | Browserless Chromium renderer | `shared/fastcrw/chromium/compose.yml` | 12363 | Internal | Bounded `/tmp` tmpfs | Proposed enablement |
| `aiagnfastcrw` | Firecrawl-compatible search and scraping API | `shared/fastcrw/compose.yml` | 12360 | Internal | Read-only configuration | Proposed enablement |
| `wbappcmswppv` | Optional WordPress homepage | `shared/wordpress/compose.yml` | 80 | `${WBHOME_DOMAIN}` and apex; `secure-chain` not declared | `${APPS_DATA}/webapps/wordpress` | Proposed alternative to Confluence |

## Unverified Values

Actual domain values, credential values, runtime image digests, firewall rules, and service ownership are intentionally omitted. They require environment-specific evidence or owner review.
