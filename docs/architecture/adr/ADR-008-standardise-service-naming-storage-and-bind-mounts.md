---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-008
title: Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables
version: "1.1"
status: Accepted
decision_basis: Owner discussion recorded on 2026-10-04, including the environment variable and database naming standard; owner-directed implementation on branch service-renaming on 2026-10-05; runtime validation pending
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-04
updated: 2026-10-06
tags:
  - servicehub
  - architecture
  - naming
  - storage
  - compose
  - bind-mounts
related_documents:
  - ADR-006
  - ADR-007
  - ADR-009
  - ARCHITECTURE
  - SERVICE-INVENTORY
  - BACKUP-RESTORE
  - DEPLOYMENT-ARCHITECTURE
---

# ADR-008: Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables

<!-- Allowed status: Draft, Proposed, In Review, Accepted, Rejected, Superseded, Deprecated, Archived -->

## Context

> **Superseded in part by [ADR-009](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md):** Open WebUI moves from `webapp` to `aiserv` (`aiservowui`, `${APPS_DATA}/aiserv/openwebui`, Tier 2 backup path `aiserv/openwebui`). The tables below record the state as decided in ADR-008.

The stack now spans 18 products across Traefik, PostgreSQL, MariaDB, Authentik, Forgejo and its runner, Confluence, Open WebUI, oCIS, Hermes, LiteLLM, llama.cpp, VictoriaMetrics, VictoriaLogs, Grafana Alloy, Grafana, Stalwart, and Bulwark. Service names, storage paths, compose grouping, and bind mounts have grown organically and are inconsistent in:

- Naming conventions: current services use unrelated prefixes (`route*`, `dbsvc*`, `authn*`, `depot*`, `wbapp*`, `aiagn*`, `obsvc*`, `poste*`) and product names of varying length and abbreviation.
- Directory layout: runtime state is grouped by historical origin (`databases/`, `platform/repos`, `platform/buildexec`, `webapps/`, `cloud/ocis`, `hermesagent/`) rather than by service domain.
- Service grouping: the eight compose files do not map cleanly onto operational domains, so a change to one domain requires reasoning across files.
- Backup scope identification: the ADR-007 backup scope is expressed as ad hoc paths rather than a classified tier model.
- Operational troubleshooting: names such as `postesvcinit` do not make the product they prepare obvious.
- Environment variables and database names follow historical service names (`AUTHN_*`, `DEPOT_*`, `WBHOME_*`, `LITEM_*`) rather than business domains, so replacing a product would ripple through variables, databases, documentation, and runbooks.

Several services also mount host paths and Docker sockets more broadly than their function requires, which increases host exposure.

A single standardisation decision is required before further services, routes, or storage paths are added.

## Decision

Adopt one naming, storage, grouping, and mount standard for all Compose services, apply it as a single coordinated change, and use it for all future services.

### 1. Compose domains

Adopt domain-based compose files:

| File | Services |
|---|---|
| `route.yml` | Traefik |
| `infra.yml` | PostgreSQL, MariaDB, Authentik |
| `devops.yml` | Forgejo, Forgejo Runner |
| `webapp.yml` | Confluence, Open WebUI, oCIS |
| `aiserv.yml` | Hermes, LiteLLM, llama.cpp |
| `obsvce.yml` | VictoriaMetrics, VictoriaLogs, Grafana Alloy, Grafana |
| `mailsv.yml` | Stalwart, Bulwark |

### 2. Service naming convention

- Running services use `<prefix><product>`, targeting 13 characters or fewer where practical.
- Init services use `<prefix><product>init`, with no length restriction, so the initialisation dependency is obvious from the name.
- The product name must appear in the service name.

Final service names and the current names they replace:

| New name | Current name | File |
|---|---|---|
| `routetraefik` | `routetraefik` | `route.yml` |
| `infrapgsql` | `dbsvcpgsqldb` | `infra.yml` |
| `inframariadb` | `dbsvcmariadb` | `infra.yml` |
| `infraauth` | `authnservice` | `infra.yml` |
| `infraauthwrk` | `authnworkers` | `infra.yml` |
| `infraauthinit` | `authnsvcinit` | `infra.yml` |
| `devopsforgejo` | `depotservice` | `devops.yml` |
| `devopsrunner` | `depotrunner` | `devops.yml` |
| `devopsforgejoinit` | `depotsvcinit` | `devops.yml` |
| `webappconf` | `wbappcmshome` | `webapp.yml` |
| `webappowui` | `wbappwebchat` | `webapp.yml` |
| `webappocis` | `wbappmydrive` | `webapp.yml` |
| `webappocisinit` | `wbappdriveinit` | `webapp.yml` |
| `aiservhermes` | `aiagnherm00` | `aiserv.yml` |
| `aiservhermesinit` | `aiagnhermint` | `aiserv.yml` |
| `aiservlitellm` | `aiagnlitellm` | `aiserv.yml` |
| `aiservllamacpp` | `aiagnchatllm` | `aiserv.yml` |
| `obsvcevm` | `obsvcvicmtrx` | `obsvce.yml` |
| `obsvcevlogs` | `obsvcviclogs` | `obsvce.yml` |
| `obsvcealloy` | `obsvcgrafaly` | `obsvce.yml` |
| `obsvcegrafana` | `obsvcgrafana` | `obsvce.yml` |
| `obsvcegrafanainit` | `obsvcgrafint` | `obsvce.yml` |
| `mailsvstalwart` | `postesvctls` | `mailsv.yml` |
| `mailsvbulwark` | `postesvcbulk` | `mailsv.yml` |
| `mailsvstalwartinit` | `postesvcinit` | `mailsv.yml` |

### 3. Storage layout

`${APPS_DATA}` is the runtime state root. Each compose domain owns a subdirectory:

| Domain | Runtime state path |
|---|---|
| `route` | `${APPS_DATA}/route/` |
| `infra` | `${APPS_DATA}/infra/` |
| `devops` | `${APPS_DATA}/devops/` |
| `webapp` | `${APPS_DATA}/webapp/` |
| `aiserv` | `${APPS_DATA}/aiserv/` |
| `obsvce` | `${APPS_DATA}/obsvce/` |
| `mailsv` | `${APPS_DATA}/mailsv/` |

Shared paths:

| Purpose | Path |
|---|---|
| Certificates | `${APPS_DATA}/shared/certs/` |
| Backups | `${APPS_DATA}/backup/` |

### 4. Bind mount policy

- Bind mounts are restricted to the service's domain directory under `${APPS_DATA}/<domain>/` and `${APPS_DATA}/shared/` where cross-domain sharing is required.
- The Docker socket is mounted only for Traefik (label discovery) and Authentik workers (outpost management).
- `/etc/localtime` is replaced by the `TZ` environment variable.
- Obsolete mounts (`/etc/localtime`, broad `/var/run/docker.sock`, `platform/`, `databases/`, `cloud/`, `hermesagent/`) are removed.

### 5. Backup tier model

Under [ADR-007](ADR-007-adopt-dual-target-backup-and-recovery.md) the backup scope is classified by tier:

| Tier | Scope | Cadence |
|---|---|---|
| Tier 1 (daily) | Database dumps, configuration | Daily |
| Tier 2 (weekly) | Service runtime state under `${APPS_DATA}/<domain>/` | Weekly |
| Tier 3 (on-demand) | Full `${APPS_DATA}` archive | Manual |

Excluded from backup: caches, temporary files, and disposable container state.

### 6. Environment variable and database prefix convention

Prefix all Compose-interpolated variables and database names with the domain short name:

| Domain | Variable prefix | Database prefix |
|---|---|---|
| `route` | `ROUTE_` | — |
| `infra` | `INFRA_` | `svchub_` |
| `devops` | `DEVOPS_` | — |
| `webapp` | `WEBAPP_` | `svchub_` |
| `aiserv` | `AISERV_` | `svchub_` |
| `obsvce` | `OBSVCE_` | — |
| `mailsv` | `MAILSV_` | — |

Database names use the format `svchub_<purpose>` (e.g., `svchub_authentik`, `svchub_forgejo`, `svchub_confluence`, `svchub_litellm`, `svchub_stalwart`). The five databases replace the historical names.

### 7. Forgejo Actions secrets and variables

The Forgejo Actions deploy token and public URL are renamed to `SOURCECODE_DEPLOY_TOKEN` and `SOURCECODE_PUBLIC_URL`.

## Implementation Evidence

- `975c701` — compose files renamed to the seven domains (`route.yml`, `infra.yml`, `devops.yml`, `webapp.yml`, `aiserv.yml`, `obsvce.yml`, `mailsv.yml`) and services moved accordingly (decision 1).
- `975c701` — service names updated to `<prefix><product>` and `<prefix><product>init` (decision 2).
- `79e810a` — `${APPS_DATA}` migrated to the domain layout, bind mounts updated, Docker socket access restricted, `TZ` replaces `/etc/localtime` (decisions 3, 4).
- `79e810a` — certificates moved to `${APPS_DATA}/shared/certs` (decision 5).
- `41f6b1d` — variable and database prefixes applied to `env.example`, `compose/*.yml`, `scripts/setup.sh`, workflows, `shared/` configuration, and documentation (decision 6).
- `7f9bfe0` — the stale Hermes `README.html` guide retired (documentation hygiene; not part of the decision).
- `9e636af` — prebuilt dashboard panels for metrics disabled by the mount removals stripped (decision 5 consequence).
- `76ec13e` — the ForgeJo Actions secret and variable renamed to `SOURCECODE_DEPLOY_TOKEN` / `SOURCECODE_PUBLIC_URL` (decision 9).

Superseded baseline: the pre-change compose set (`route.yml`, `dbsvc.yml`, `authn.yml`, `depot.yml`, `wbapp.yml`, `aiagn.yml`, `obsvc.yml`, `poste.yml`), the bind mounts and labels recorded in [SERVICE-INVENTORY](../../operations/SERVICE-INVENTORY.md), and the pre-change variable prefixes in [env.example](../../../env.example).

## Related Documents

- [ADR-006 Adopt oCIS with Local Filesystem Storage](ADR-006-adopt-ocis-with-local-filesystem-storage.md) — oCIS storage paths affected by the new layout.
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](ADR-007-adopt-dual-target-backup-and-recovery.md) — backup scope and workflow affected by the tier model.
- [ADR-009 Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) — partially supersedes this ADR (Open WebUI relocation).
- [Service inventory](../../operations/SERVICE-INVENTORY.md) — current service names and mounts.
- [Backup and restore](../../operations/runbooks/BACKUP-RESTORE.md) — backup scope re-expressed with the tier model.
- [Architecture](../ARCHITECTURE.md) — component and boundary diagrams updated by this decision.

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Rename compose files to the seven domains and move each service into its domain file | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`975c701`); server validation pending |
| Apply the `<prefix><product>` and `<prefix><product>init` names, including Traefik router and service labels | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`975c701`); server validation pending |
| Migrate `${APPS_DATA}` to the domain layout and update every bind mount | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`79e810a`); host migration pending |
| Remove the listed bind mounts, restrict Docker socket access, and replace `/etc/localtime` with `TZ` | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`79e810a`); server validation pending |
| Move certificates to `${APPS_DATA}/shared/certs` and update Traefik and Stalwart consumers | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`79e810a`); host ACME migration pending |
| Apply the environment variable and database variable renames across `env.example`, `compose/*.yml`, `scripts/setup.sh`, workflows, `shared/` configuration, and documentation in one change | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`41f6b1d`); `.env` files migrated manually by the owner and the `setup.sh` migration block removed (2026-10-06); server validation pending |
| Update backup scope and exclusions to the tier classification under ADR-007 | ServiceHub Architecture | 2026-10-05 | Tier classification documented in [BACKUP-RESTORE](../../operations/runbooks/BACKUP-RESTORE.md); exclusion values remain deployment secrets |
| Rename the five databases to the `svchub_<purpose>` values and update every consumer in one maintenance window | ServiceHub Architecture | TBD | Proposed; `.env` values migrated manually — server-side database rename and grants pending |
| Update Forgejo Actions deploy and backup workflows, monitoring provisioning, and dashboards | ServiceHub Architecture | 2026-10-05 | Workflows and monitoring configuration renamed (`975c701`, `41f6b1d`, `76ec13e`); dead dashboard panels for the removed mounts stripped (`9e636af`); runtime provisioning pending |
| Rename `SOURCECODE_PUBLIC_URL` and `SOURCECODE_DEPLOY_TOKEN` in Forgejo repository Actions settings on staging and production | George Li | TBD | Superseded — the deploy workflow syncs the working tree from the runner checkout and reads neither entry; removing them from the Forgejo UI is optional (repository side applied on `service-renaming` (`76ec13e`)) |
| Update documentation, service inventory, and architecture records in the same change | George Li | 2026-10-05 | Living documentation updated across the three `service-renaming` commits |
| Validate with `docker compose config` and a staging deployment, and record the evidence | ServiceHub Architecture | TBD | Proposed |
