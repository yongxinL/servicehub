---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: SERVICE-INVENTORY
title: ServiceHub Service Inventory
version: "1.0"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-03
tags:
  - servicehub
  - operations
  - inventory
  - services
related_documents:
  - COMPONENT-CATALOGUE
  - RUNBOOK
  - BACKUP-RESTORE
  - ADR-006
---

# ServiceHub Service Inventory

Criticality is `Requires owner review` for every service because the repository does not define service ownership or business criticality. Monitoring and backup entries describe repository configuration, not proven runtime coverage.

## Default Services

| Service | Category | Compose file | Image/build | Dependencies | Ports | Route | Authentication | Database | Persistence | Health check | Monitoring | Backup requirement | Criticality | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `routetraefik` | Ingress | `compose/route.yml` | `build shared/traefik/` | None | 80, 443 | `${TRAEFIK_DOMAIN}` | Basic auth and IP allowlist on dashboard | None | ACME store, advanced config, Docker socket | Traefik ping | Metrics and JSON access logs | Certificates required | Requires owner review | [Compose](../../compose/route.yml), [README](../../shared/traefik/README.md) |
| `dbsvcmariadb` | Database | `compose/dbsvc.yml` | `build shared/mariadb/` | None | 3306 internal | None | Database credentials | MariaDB | `databases/mariadb` | MariaDB health | Logs only confirmed | Required if optional WordPress is used | Requires owner review | [Compose](../../compose/dbsvc.yml) |
| `dbsvcpgsqldb` | Database | `compose/dbsvc.yml` | `build shared/postgresql/` | None | 5432 internal | None | Database credentials | PostgreSQL | `databases/pgsqldb` | `pg_isready` | Logs and dependent-service signals | Required; daily dumps implemented | Requires owner review | [Compose](../../compose/dbsvc.yml), [backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml) |
| `authnsvcinit` | Identity init | `compose/authn.yml` | `busybox:latest` | None | None | None | Not applicable | None | Authentik media/templates | One-shot | Container logs | Included with Authentik data | Requires owner review | [Compose](../../compose/authn.yml) |
| `authnworkers` | Identity | `compose/authn.yml` | `build shared/authentik/` | Initialiser complete; PostgreSQL healthy | None | None | Authentik application login | PostgreSQL | Authentik media/templates, Docker socket | None declared | Logs; outpost metrics TBD | Database plus files required | Requires owner review | [Compose](../../compose/authn.yml) |
| `authnservice` | Identity | `compose/authn.yml` | `build shared/authentik/` | Traefik healthy; worker started | 9000 internal | `${AUTHN_DOMAIN}` | Authentik application login | PostgreSQL | Authentik media/templates | None declared | Route and logs | Database plus files required | Requires owner review | [Compose](../../compose/authn.yml) |
| `depotsvcinit` | Developer init | `compose/depot.yml` | `busybox:latest` | None | None | None | Not applicable | None | Repositories/runner state | One-shot | Container logs | Included with Forgejo data | Requires owner review | [Compose](../../compose/depot.yml) |
| `depotservice` | Source control | `compose/depot.yml` | `build shared/forgejo/server/` | PostgreSQL healthy; Authentik healthy | 3000 internal | `${DEPOT_DOMAIN}` | Application login; registration disabled; OIDC coverage TBD | PostgreSQL | `platform/repos` | `/api/healthz` | Logs; metrics TBD | Repositories required | Requires owner review | [Compose](../../compose/depot.yml), [README](../../shared/forgejo/README.md) |
| `depotrunner` | CI/CD | `compose/depot.yml` | `build shared/forgejo/actions/` | Initialiser complete; Forgejo healthy | None | None | Runner secret | None | Runner registration and workspace | Process plus `.runner` | Workflow logs | Registration and workspace required | Requires owner review | [Compose](../../compose/depot.yml) |
| `wbappcmshome` | Web application | `compose/wbapp.yml` | `build shared/confluence/` | Authentik healthy | 8090 internal | `${WBHOME_DOMAIN}` and apex | Application login; Authentik coverage TBD | PostgreSQL | `webapps/confluence` | `/status` | Logs; metrics TBD | Required | Requires owner review | [Compose](../../compose/wbapp.yml), [README](../../shared/confluence/README.md) |
| `wbappwebchat` | AI client | `compose/wbapp.yml` | `build shared/openwebui/` | Traefik healthy | 8080 internal | `${OWEBUI_DOMAIN}` | Not yet verified | None | `openwebui` | None declared | Logs | Required if user data matters | Requires owner review | [Compose](../../compose/wbapp.yml) |
| `wbappcloudrvinit` | Cloud-drive init | `compose/wbapp.yml` | `busybox:latest` | None | None | None | Not applicable | None | `cloud/ocis/config`, `cloud/ocis/data` | One-shot | Container logs | Required with oCIS state | Requires owner review | [Compose](../../compose/wbapp.yml), [README](../../shared/ocis/README.md) |
| `wbappcloudrv` | Cloud drive | `compose/wbapp.yml` | `owncloud/ocis:${WBCLOUD_TAG}` | Initialiser complete; Authentik healthy; Traefik healthy | 9200 internal | `${WBCLOUD_DOMAIN}` | Authentik OIDC; runtime flow not validated | None | `cloud/ocis/config`, `cloud/ocis/data` | `/status.php` | Logs; metrics TBD | Configuration and file data required | Requires owner review | [Compose](../../compose/wbapp.yml), [README](../../shared/ocis/README.md) |
| `aiagnhermint` | AI init | `compose/aiagn.yml` | `busybox:latest` | None | None | None | Not applicable | None | Hermes data | One-shot | Container logs | Included with Hermes data | Requires owner review | [Compose](../../compose/aiagn.yml) |
| `aiagnherm00` | AI agent | `compose/aiagn.yml` | `build shared/hermesagent/` | Initialiser complete | 12320 host; 12330 internal | Conditional `${HERMES_WORKSPACE_DOMAIN_00}` | Workspace password and API key | LiteLLM usage is external | Hermes data, read-only Docker socket | API `/health` | Logs; metrics TBD | Required | Requires owner review | [Compose](../../compose/aiagn.yml) |
| `aiagnlitellm` | AI routing | `compose/aiagn.yml` | `build shared/litellm/` | PostgreSQL healthy | 12380 host and internal | None through Traefik | Master API key and UI credentials | PostgreSQL | `litellm` config | Authenticated liveliness | `/metrics`, routing logs | Config and database required | Requires owner review | [Compose](../../compose/aiagn.yml), [README](../../shared/litellm/README.md) |
| `aiagnchatllm` | Local inference | `compose/aiagn.yml` | `build shared/llamacpp/` | None | 12386 host and internal | None through Traefik | Default local key `none` | None | Model cache `llamacpp` | `/health` | Logs; metrics TBD | Model cache optional to back up if reproducible | Requires owner review | [Compose](../../compose/aiagn.yml) |
| `obsvcvicmtrx` | Metrics store | `compose/obsvc.yml` | `build shared/victoriametrics/` | None | 8428 host and internal | None through Traefik | Not yet verified | None | `victoriametrics` | `/health` | Self health and Grafana | Required only if history matters | Requires owner review | [Compose](../../compose/obsvc.yml) |
| `obsvcviclogs` | Log store | `compose/obsvc.yml` | `build shared/victorialogs/` | None | 9428 host and internal | None through Traefik | Not yet verified | None | `victorialogs` | `/health` | Self health and Grafana | Required only if history matters | Requires owner review | [Compose](../../compose/obsvc.yml) |
| `obsvcgrafaly` | Telemetry collector | `compose/obsvc.yml` | `build shared/grafana/alloy/` | Metrics and logs stores healthy | 9080 internal | None | Not applicable | None | Read-only config, GeoIP, host and Docker mounts | `/health` | Self metrics and logs | Repository config is in Git | Requires owner review | [Compose](../../compose/obsvc.yml), [config](../../shared/grafana/alloy/config.alloy) |
| `obsvcgrafint` | Observability init | `compose/obsvc.yml` | `busybox:latest` | None | None | None | Not applicable | None | Grafana data | One-shot | Container logs | Included with Grafana data | Requires owner review | [Compose](../../compose/obsvc.yml) |
| `obsvcgrafana` | Dashboards | `compose/obsvc.yml` | `build shared/grafana/` | Traefik, initialiser, Alloy | 3000 internal | `${OBSVC_DOMAIN}` | Authentik forward auth plus Grafana credentials | None | Grafana state, provisioning | `/api/health` | Self health and datasource logs | Required if dashboards/history matter | Requires owner review | [Compose](../../compose/obsvc.yml), [README](../../shared/grafana/README.md) |
| `posteservice` | Email | `compose/poste.yml` | `build shared/stalwart/` | Traefik healthy; PostgreSQL healthy | 8080 internal; 25/465/587/993 host | `${EMAIL_HOST}` | LDAP directory documented; recovery admin | PostgreSQL | Mailbox and certificate store | `/healthz/live` | Logs; mail metrics TBD | Required | Requires owner review | [Compose](../../compose/poste.yml), [README](../../shared/stalwart/README.md) |
| `postesvcinit` | Email init | `compose/poste.yml` | `busybox:latest` | None | None | None | Not applicable | None | Webmail state paths | One-shot | Container logs | Included with webmail data | Requires owner review | [Compose](../../compose/poste.yml) |
| `postewebmail` | Webmail | `compose/poste.yml` | `build shared/bulwark/` | Initialiser complete; Stalwart healthy | 3000 internal | `${WEBMAIL_DOMAIN}` | Password form via Stalwart | None | Four webmail state paths | `/api/health` | Logs; metrics TBD | Required | Requires owner review | [Compose](../../compose/poste.yml), [README](../../shared/bulwark/README.md) |

## Optional Services

| Service | Category | Compose file | Image/build | Dependencies | Ports | Route | Authentication | Database | Persistence | Health check | Monitoring | Backup requirement | Criticality | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `aiagnsearxng` | Search | `shared/searxng/compose.yml` | `build shared/searxng/` | Defined in optional file | Internal | None | Not yet verified | None | No mount evident | Declared in optional file | Logs | Configuration in Git | Requires owner review | [Compose](../../shared/searxng/compose.yml) |
| `aiagnlighpda` | Renderer | `shared/fastcrw/lightpanda/compose.yml` | `build shared/fastcrw/lightpanda/` | None | 12362 internal | None | Optional API key path | None | Ephemeral | TCP 12362 | Logs | Usually reproducible | Requires owner review | [Compose](../../shared/fastcrw/lightpanda/compose.yml) |
| `aiagnchromum` | Renderer | `shared/fastcrw/chromium/compose.yml` | `build shared/fastcrw/chromium/` | None | 12363 internal | None | Token from LiteLLM key | None | Bounded tmpfs | TCP 12363 | Logs | Usually reproducible | Requires owner review | [Compose](../../shared/fastcrw/chromium/compose.yml) |
| `aiagnfastcrw` | Web tools | `shared/fastcrw/compose.yml` | `build shared/fastcrw/` | Renderer and search healthy | 12360 internal | None | API key | None | Read-only config | TCP 12360 | Logs | Configuration in Git | Requires owner review | [Compose](../../shared/fastcrw/compose.yml) |
| `wbappcmswppv` | Optional CMS | `shared/wordpress/compose.yml` | `build shared/wordpress/` | Route, MariaDB, Authentik | 80 internal | `${WBHOME_DOMAIN}` and apex | Not yet verified | MariaDB | `webapps/wordpress` | None declared | Logs | Files and separate MariaDB backup required | Requires owner review | [Compose](../../shared/wordpress/compose.yml), [README](../../shared/wordpress/README.md) |

## Inventory Notes

- No production hostname, credential, owner, criticality, or runtime result is recorded.
- Container status and monitoring coverage require [TEST-001](../testing/TEST-001-platform-baseline-validation.md).
