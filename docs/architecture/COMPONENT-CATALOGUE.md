---
project: ServiceHub
project_code: SVCHUB
document_type: ARCHITECTURE
document_id: COMPONENT-CATALOGUE
title: ServiceHub Component Catalogue
version: "1.0"
status: Draft
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-03
tags:
  - servicehub
  - architecture
  - inventory
related_documents:
  - ARCHITECTURE
  - SERVICE-INVENTORY
  - DATA-FLOW
  - ADR-006
---

# ServiceHub Component Catalogue

## Default Compose Components

All default components use the `servicehub_subnet` network. “No host route” means no Traefik label is present; direct `ports` mappings are listed separately.

| Compose service | Purpose | Image or build | Compose file | Internal port | Published port | Dependencies | Persistent storage | Health check | Public route | Authentication | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `routetraefik` | HTTP ingress, TLS, discovery, metrics, logs | Build `shared/traefik/` | `compose/route.yml` | 80, 443 | 80, 443 | None declared | `${APPS_DATA}/certs`; read-only advanced config; read-only Docker socket | `traefik healthcheck --ping` | `${TRAEFIK_DOMAIN}` dashboard | Basic auth plus IP allowlist | [Compose](../../compose/route.yml), [README](../../shared/traefik/README.md) |
| `dbsvcmariadb` | Optional MySQL-compatible database | Build `shared/mariadb/` | `compose/dbsvc.yml` | 3306 service target | None | None declared | `${APPS_DATA}/databases/mariadb` | MariaDB `healthcheck.sh` | None | Database credentials from environment | [Compose](../../compose/dbsvc.yml) |
| `dbsvcpgsqldb` | Primary relational database | Build `shared/postgresql/` | `compose/dbsvc.yml` | 5432 service target | None | None declared | `${APPS_DATA}/databases/pgsqldb` | `pg_isready` | None | Database credentials from environment | [Compose](../../compose/dbsvc.yml) |
| `authnsvcinit` | Authentik bind-mount ownership initialiser | `busybox:latest` | `compose/authn.yml` | None | None | None declared | Authentik media and templates | One-shot, no health check | None | Not applicable | [Compose](../../compose/authn.yml) |
| `authnworkers` | Authentik background worker | Build `shared/authentik/` | `compose/authn.yml` | No HTTP listener | None | `authnsvcinit` completed; PostgreSQL healthy | Authentik media and templates; Docker socket | None | None | Authentik application login | [Compose](../../compose/authn.yml), [README](../../shared/authentik/README.md) |
| `authnservice` | Authentik UI and API | Build `shared/authentik/` | `compose/authn.yml` | 9000 | None | Traefik healthy; worker started | Authentik media and templates | None declared | `${AUTHN_DOMAIN}` | Authentik application login | [Compose](../../compose/authn.yml) |
| `depotsvcinit` | Forgejo and runner directory initialiser | `busybox:latest` | `compose/depot.yml` | None | None | None declared | Repositories and runner state | One-shot, no health check | None | Not applicable | [Compose](../../compose/depot.yml) |
| `depotservice` | Forgejo repositories, issues, and Actions | Build `shared/forgejo/server/` | `compose/depot.yml` | 3000 | None | PostgreSQL healthy; Authentik healthy | `${APPS_DATA}/platform/repos` | `/api/healthz` | `${DEPOT_DOMAIN}` | Application login; registration disabled; OIDC coverage not verified | [Compose](../../compose/depot.yml), [README](../../shared/forgejo/README.md) |
| `depotrunner` | Host-mode Forgejo Actions runner | Build `shared/forgejo/actions/` | `compose/depot.yml` | No HTTP listener | None | Initialiser completed; Forgejo healthy | Runner state and workspace | Process plus non-empty `.runner` | None | Runner registration secret | [Compose](../../compose/depot.yml), [config](../../shared/forgejo/actions/config.yml) |
| `wbappcmshome` | Confluence web application | Build `shared/confluence/` | `compose/wbapp.yml` | 8090 | None | Authentik healthy | `${APPS_DATA}/webapps/confluence` | `/status` | `${WBHOME_DOMAIN}` and apex `${DOMAIN_NAME}` | Application login; Authentik directory integration not verified | [Compose](../../compose/wbapp.yml), [README](../../shared/confluence/README.md) |
| `wbappwebchat` | Open WebUI chat client | Build `shared/openwebui/` | `compose/wbapp.yml` | 8080 | None | Traefik healthy | `${APPS_DATA}/openwebui` | None declared | `${OWEBUI_DOMAIN}` | Not yet verified | [Compose](../../compose/wbapp.yml), [README](../../shared/openwebui/README.md) |
| `wbappcloudrinit` | oCIS configuration and data ownership initialiser | `busybox:latest` | `compose/wbapp.yml` | None | None | None declared | oCIS config and data paths | One-shot, no health check | None | Not applicable | [Compose](../../compose/wbapp.yml), [README](../../shared/ocis/README.md) |
| `wbappcloudr` | ownCloud Infinite Scale cloud drive | `owncloud/ocis:${WBCLOUD_TAG}` | `compose/wbapp.yml` | 9200 | None | Initialiser completed; Authentik healthy; Traefik healthy | `${APPS_DATA}/cloud/ocis/config`, `${APPS_DATA}/cloud/ocis/data` | `/status.php` | `${WBCLOUD_DOMAIN}` | Authentik OIDC; runtime flow not validated | [Compose](../../compose/wbapp.yml), [README](../../shared/ocis/README.md) |
| `aiagnhermint` | Hermes data ownership initialiser | `busybox:latest` | `compose/aiagn.yml` | None | None | None declared | Hermes data path | One-shot, no health check | None | Not applicable | [Compose](../../compose/aiagn.yml) |
| `aiagnherm00` | Hermes agent and workspace | Build `shared/hermesagent/` | `compose/aiagn.yml` | 12320 workspace; 12330 API | 12320 | Initialiser completed | Hermes data path; read-only Docker socket | API `/health` | Conditional `${HERMES_WORKSPACE_DOMAIN_00}` | Workspace password; API key | [Compose](../../compose/aiagn.yml), [README](../../shared/hermesagent/README.md) |
| `aiagnlitellm` | AI router, UI, metrics, and usage database | Build `shared/litellm/` | `compose/aiagn.yml` | 12380 | 12380 | PostgreSQL healthy | `${APPS_DATA}/litellm` | Bearer-authenticated `/health/liveliness` | None through Traefik | Master API key and UI credentials | [Compose](../../compose/aiagn.yml), [README](../../shared/litellm/README.md) |
| `aiagnchatllm` | Local llama.cpp inference | Build `shared/llamacpp/` | `compose/aiagn.yml` | 12386 | 12386 | None declared | `${APPS_DATA}/llamacpp` | `/health` after 120 s start period | None through Traefik | Local API key configured as `none` by default | [Compose](../../compose/aiagn.yml), [README](../../shared/llamacpp/README.md) |
| `obsvcvicmtrx` | Metrics store | Build `shared/victoriametrics/` | `compose/obsvc.yml` | 8428 | 8428 | None declared | `${APPS_DATA}/victoriametrics` | `/health` | None through Traefik | Not yet verified | [Compose](../../compose/obsvc.yml) |
| `obsvcviclogs` | Log store | Build `shared/victorialogs/` | `compose/obsvc.yml` | 9428 | 9428 | None declared | `${APPS_DATA}/victorialogs` | `/health` | None through Traefik | Not yet verified | [Compose](../../compose/obsvc.yml) |
| `obsvcgrafaly` | Telemetry collector | Build `shared/grafana/alloy/` | `compose/obsvc.yml` | 9080 | None | Both stores healthy | Read-only config and GeoIP; host mounts and Docker socket | `/health` | None | Not applicable | [Compose](../../compose/obsvc.yml), [config](../../shared/grafana/alloy/config.alloy) |
| `obsvcgrafint` | Grafana ownership initialiser | `busybox:latest` | `compose/obsvc.yml` | None | None | None declared | Grafana data | One-shot, no health check | None | Not applicable | [Compose](../../compose/obsvc.yml) |
| `obsvcgrafana` | Dashboards and Grafana UI | Build `shared/grafana/` | `compose/obsvc.yml` | 3000 | None | Traefik healthy; initialiser completed; Alloy healthy | Grafana data plus read-only provisioning | `/api/health` | `${OBSVC_DOMAIN}` | Authentik forward auth plus Grafana credentials | [Compose](../../compose/obsvc.yml) |
| `posteservice` | Stalwart mail server | Build `shared/stalwart/` | `compose/poste.yml` | 8080 | 25, 465, 587, 993 | Traefik healthy; PostgreSQL healthy | Mailbox state and certificate store | `/healthz/live` | `${EMAIL_HOST}` | LDAP directory documented; recovery admin fallback | [Compose](../../compose/poste.yml), [README](../../shared/stalwart/README.md) |
| `postesvcinit` | Webmail state ownership initialiser | `busybox:latest` | `compose/poste.yml` | None | None | None declared | Webmail settings, admin, state, telemetry | One-shot, no health check | None | Not applicable | [Compose](../../compose/poste.yml) |
| `postewebmail` | Bulwark JMAP webmail | Build `shared/bulwark/` | `compose/poste.yml` | 3000 | None | Initialiser completed; Stalwart healthy | Four webmail state paths | `/api/health` | `${WEBMAIL_DOMAIN}` | Password form validated by Stalwart | [Compose](../../compose/poste.yml), [README](../../shared/bulwark/README.md) |

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
