---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: SERVICE-INVENTORY
title: ServiceHub Service Inventory
version: "1.1"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-04
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
| `inframariadb` | Database | `compose/infra.yml` | `build shared/mariadb/` | None | 3306 internal | None | Database credentials | MariaDB | `databases/mariadb` | MariaDB health | Logs only confirmed | Required if optional WordPress is used | Requires owner review | [Compose](../../compose/infra.yml) |
| `infrapgsql` | Database | `compose/infra.yml` | `build shared/postgresql/` | None | 5432 internal | None | Database credentials | PostgreSQL | `databases/pgsqldb` | `pg_isready` | Logs and dependent-service signals | Required; daily dumps implemented | Requires owner review | [Compose](../../compose/infra.yml), [backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml) |
| `infraauthinit` | Identity init | `compose/infra.yml` | `busybox:latest` | None | None | None | Not applicable | None | Authentik media/templates | One-shot | Container logs | Included with Authentik data | Requires owner review | [Compose](../../compose/infra.yml) |
| `infraauthwrk` | Identity | `compose/infra.yml` | `build shared/authentik/` | Initialiser complete; PostgreSQL healthy | None | None | Authentik application login | PostgreSQL | Authentik media/templates, Docker socket | None declared | Logs; outpost metrics TBD | Database plus files required | Requires owner review | [Compose](../../compose/infra.yml) |
| `infraauth` | Identity | `compose/infra.yml` | `build shared/authentik/` | Traefik healthy; worker started | 9000 internal | `${AUTHN_DOMAIN}` | Authentik application login | PostgreSQL | Authentik media/templates | None declared | Route and logs | Database plus files required | Requires owner review | [Compose](../../compose/infra.yml) |
| `devopsforgejoinit` | Developer init | `compose/devops.yml` | `busybox:latest` | None | None | None | Not applicable | None | Repositories/runner state | One-shot | Container logs | Included with Forgejo data | Requires owner review | [Compose](../../compose/devops.yml) |
| `devopsforgejo` | Source control | `compose/devops.yml` | `build shared/forgejo/server/` | PostgreSQL healthy; Authentik healthy | 3000 internal | `${DEPOT_DOMAIN}` | Application login; registration disabled; OIDC coverage TBD | PostgreSQL | `platform/repos` | `/api/healthz` | Logs; metrics TBD | Repositories required | Requires owner review | [Compose](../../compose/devops.yml), [README](../../shared/forgejo/README.md) |
| `devopsrunner` | CI/CD | `compose/devops.yml` | `build shared/forgejo/actions/` | Initialiser complete; Forgejo healthy | None | None | Runner secret | None | Runner registration and workspace | Process plus `.runner` | Workflow logs | Registration and workspace required | Requires owner review | [Compose](../../compose/devops.yml) |
| `webappconf` | Web application | `compose/webapp.yml` | `build shared/confluence/` | Authentik healthy | 8090 internal | `${WBHOME_DOMAIN}` and apex | Application login; Authentik coverage TBD | PostgreSQL | `webapps/confluence` | `/status` | Logs; metrics TBD | Required | Requires owner review | [Compose](../../compose/webapp.yml), [README](../../shared/confluence/README.md) |
| `webappowui` | AI client | `compose/webapp.yml` | `build shared/openwebui/` | Traefik healthy | 8080 internal | `${OWEBUI_DOMAIN}` | Not yet verified | None | `openwebui` | None declared | Logs | Required if user data matters | Requires owner review | [Compose](../../compose/webapp.yml) |
| `webappocisinit` | Cloud-drive init | `compose/webapp.yml` | `busybox:latest` | None | None | None | Not applicable | None | `cloud/ocis/config`, `cloud/ocis/data` | One-shot | Container logs | Required with oCIS state | Requires owner review | [Compose](../../compose/webapp.yml), [README](../../shared/owncloud/README.md) |
| `webappocis` | Cloud drive | `compose/webapp.yml` | `webappocis:latest` | Initialiser complete; Authentik healthy; Traefik healthy | 9200 internal | `${WBDRIVE_DOMAIN}` | Authentik OIDC; runtime flow not validated | None | `cloud/ocis/config`, `cloud/ocis/data` | `/status.php` | Logs; metrics TBD | Configuration and file data required | Requires owner review | [Compose](../../compose/webapp.yml), [README](../../shared/owncloud/README.md) |
| `aiservhermesinit` | AI init | `compose/aiserv.yml` | `busybox:latest` | None | None | None | Not applicable | None | Hermes data | One-shot | Container logs | Included with Hermes data | Requires owner review | [Compose](../../compose/aiserv.yml) |
| `aiservhermes` | AI agent | `compose/aiserv.yml` | `build shared/hermesagent/` | Initialiser complete | 12320 host; 12330 internal | Conditional `${HERMES_WORKSPACE_DOMAIN_00}` | Workspace password and API key | LiteLLM usage is external | Hermes data, read-only Docker socket | API `/health` | Logs; metrics TBD | Required | Requires owner review | [Compose](../../compose/aiserv.yml) |
| `aiservlitellm` | AI routing | `compose/aiserv.yml` | `build shared/litellm/` | PostgreSQL healthy | 12380 host and internal | None through Traefik | Master API key and UI credentials | PostgreSQL | `litellm` config | Authenticated liveliness | `/metrics`, routing logs | Config and database required | Requires owner review | [Compose](../../compose/aiserv.yml), [README](../../shared/litellm/README.md) |
| `aiservllamacpp` | Local inference | `compose/aiserv.yml` | `build shared/llamacpp/` | None | 12386 host and internal | None through Traefik | Default local key `none` | None | Model cache `llamacpp` | `/health` | Logs; metrics TBD | Model cache optional to back up if reproducible | Requires owner review | [Compose](../../compose/aiserv.yml) |
| `obsvcevm` | Metrics store | `compose/obsvce.yml` | `build shared/victoriametrics/` | None | 8428 host and internal | None through Traefik | Not yet verified | None | `victoriametrics` | `/health` | Self health and Grafana | Required only if history matters | Requires owner review | [Compose](../../compose/obsvce.yml) |
| `obsvcevlogs` | Log store | `compose/obsvce.yml` | `build shared/victorialogs/` | None | 9428 host and internal | None through Traefik | Not yet verified | None | `victorialogs` | `/health` | Self health and Grafana | Required only if history matters | Requires owner review | [Compose](../../compose/obsvce.yml) |
| `obsvcealloy` | Telemetry collector | `compose/obsvce.yml` | `build shared/grafana/alloy/` | Metrics and logs stores healthy | 9080 internal | None | Not applicable | None | Read-only config, GeoIP, host and Docker mounts | `/health` | Self metrics and logs | Repository config is in Git | Requires owner review | [Compose](../../compose/obsvce.yml), [config](../../shared/grafana/alloy/config.alloy) |
| `obsvcegrafanainit` | Observability init | `compose/obsvce.yml` | `busybox:latest` | None | None | None | Not applicable | None | Grafana data | One-shot | Container logs | Included with Grafana data | Requires owner review | [Compose](../../compose/obsvce.yml) |
| `obsvcegrafana` | Dashboards | `compose/obsvce.yml` | `build shared/grafana/` | Traefik, initialiser, Alloy | 3000 internal | `${OBSVC_DOMAIN}` | Authentik forward auth plus Grafana credentials | None | Grafana state, provisioning | `/api/health` | Self health and datasource logs | Required if dashboards/history matter | Requires owner review | [Compose](../../compose/obsvce.yml), [README](../../shared/grafana/README.md) |
| `mailsvstalwart` | Email | `compose/mailsv.yml` | `build shared/stalwart/` | Traefik healthy; PostgreSQL healthy | 8080 internal; 25/465/587/993 host | `${EMAIL_HOST}` | LDAP directory documented; recovery admin | PostgreSQL | Mailbox and certificate store | `/healthz/live` | Logs; mail metrics TBD | Required | Requires owner review | [Compose](../../compose/mailsv.yml), [README](../../shared/stalwart/README.md) |
| `mailsvbulwarkinit` | Email init | `compose/mailsv.yml` | `busybox:latest` | None | None | None | Not applicable | None | Webmail state paths | One-shot | Container logs | Included with webmail data | Requires owner review | [Compose](../../compose/mailsv.yml) |
| `mailsvbulwark` | Webmail | `compose/mailsv.yml` | `build shared/bulwark/` | Initialiser complete; Stalwart healthy | 3000 internal | `${WEBMAIL_DOMAIN}` | Password form via Stalwart | None | Four webmail state paths | `/api/health` | Logs; metrics TBD | Required | Requires owner review | [Compose](../../compose/mailsv.yml), [README](../../shared/bulwark/README.md) |

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
