---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-008
title: Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables
version: "1.4"
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
| `mailsvstalwart` | `posteservice` | `mailsv.yml` |
| `mailsvbulwark` | `postewebmail` | `mailsv.yml` |
| `mailsvbulwarkinit` | `postesvcinit` | `mailsv.yml` |
| `aiservfastcrw` | `aiagnfastcrw` | `shared/fastcrw/compose.yml` |
| `aiservsearxng` | `aiagnsearxng` | `shared/searxng/compose.yml` |
| `aiservchromum` | `aiagnchromum` | `shared/fastcrw/chromium/compose.yml` |
| `aiservlighpda` | `aiagnlighpda` | `shared/fastcrw/lightpanda/compose.yml` |
| `webappwpress` | `wbappcmswppv` | `shared/wordpress/compose.yml` |

Product mapping for abbreviated names: `webappconf` is Confluence, `webappowui` is Open WebUI, `webappocis` is oCIS, `webappwpress` is WordPress.

The last five rows are optional-stack services (FastCRW, SearXNG, renderers, WordPress) that users enable by including their compose files; they follow the same convention as the default stack.

`aiservllamacpp` is 14 characters and is retained as the practical exception to the 13-character guideline; init names are exempt by design.

### 3. Storage layout

Runtime data is organised by service domain under `${APPS_DATA}`:

```text
${APPS_DATA}/
├── infra/
│   ├── postgresql/
│   ├── mariadb/
│   └── authentik/
├── devops/
│   └── forgejo/
│       ├── data/
│       ├── runner/
│       └── workspace/
├── webapp/
│   ├── confluence/
│   ├── openwebui/
│   └── ocis/
├── aiserv/
│   ├── hermes/
│   ├── litellm/
│   └── llamacpp/
├── obsvce/
│   ├── victoriametrics/
│   ├── victorialogs/
│   └── grafana/
├── mailsv/
│   ├── stalwart/
│   └── bulwark/
└── shared/
    └── certs/
```

Current paths map to the new layout as follows:

| Current path under `${APPS_DATA}` | New path |
|---|---|
| `databases/pgsqldb` | `infra/postgresql` |
| `databases/mariadb` | `infra/mariadb` |
| `platform/authentik` | `infra/authentik` |
| `platform/repos` | `devops/forgejo/data` |
| `platform/buildexec` | `devops/forgejo/runner` |
| `platform/workspace` | `devops/forgejo/workspace` |
| `webapps/confluence` | `webapp/confluence` |
| `openwebui` | `webapp/openwebui` |
| `cloud/ocis` | `webapp/ocis` |
| `hermesagent` | `aiserv/hermes` |
| `litellm` | `aiserv/litellm` |
| `llamacpp` | `aiserv/llamacpp` |
| `victoriametrics` | `obsvce/victoriametrics` |
| `victorialogs` | `obsvce/victorialogs` |
| `grafana` | `obsvce/grafana` |
| `platform/mailbox` | `mailsv/stalwart` |
| `platform/webmail` | `mailsv/bulwark` |
| `certs` | `shared/certs` |

##### Shared storage rule

The `shared/` hierarchy is reserved for assets consumed by multiple service domains.

Examples:

- `shared/certs`
- Shared configuration repositories under `shared/`

Service-specific runtime state SHALL remain within its owning domain directory and SHALL NOT be stored under `shared/`.

Examples:

- Forgejo data belongs under `devops/`
- Authentik data belongs under `infra/`
- Stalwart data belongs under `mailsv/`
- Grafana data belongs under `obsvce/`

The purpose of `shared/` is to hold cross-domain assets only and prevent service-owned runtime data from bypassing the domain-based storage structure.

### 4. Configuration versus runtime state

- Runtime state is stored under `${APPS_DATA}` (PostgreSQL, MariaDB, Forgejo, Confluence, oCIS, Grafana, Stalwart, and the other stateful services).
- Configuration is stored in the Git repository under `shared/` (for example `shared/traefik`, `shared/forgejo`, `shared/grafana`, `shared/victoriametrics`).
- Repository-managed configuration is a source-controlled artefact, not a primary backup target; `${APPS_DATA}` content is.

### 5. Bind mount review

Removed mounts:

| Service | Removed | Reason |
|---|---|---|
| `obsvcealloy` | `/`, `/var/lib/docker`, containerd socket | Not required; reduces host exposure and attack surface |
| `aiservhermes` | Docker socket | Hermes does not manage containers |
| `devopsforgejo`, `devopsrunner`, `mailsvbulwark` | `/etc/localtime` | Replaced by `TZ=Australia/Sydney` |

### 6. Docker socket usage

Socket access is restricted to services that require Docker API access:

| Service | Use |
|---|---|
| `routetraefik` | Docker service discovery |
| `infraauthwrk` | Authentik outpost deployment and lifecycle |
| `obsvcealloy` | Docker metrics, container discovery, and status collection |

`aiservhermes` loses socket access; no other service may mount a Docker socket.

#### 7. Shared certificates

- Certificates live at `${APPS_DATA}/shared/certs`.
- Consumers: `routetraefik` and `mailsvstalwart`.
- `routetraefik` is the sole certificate writer and lifecycle manager.
- `mailsvstalwart` is a certificate consumer only and mounts `${APPS_DATA}/shared/certs` as read-only.
- Additional services may consume certificates from `${APPS_DATA}/shared/certs`, but shall use read-only mounts unless write access is explicitly required and documented.
- The `shared/` hierarchy is reserved for assets consumed by multiple service domains. Service-specific runtime state shall remain within its owning domain directory.

### 8. Backup classification

| Tier | Paths | Requirement |
|---|---|---|
| Tier 1 — critical | `infra/`, `devops/forgejo/data`, `webapp/confluence`, `webapp/ocis`, `mailsv/stalwart`, `shared/certs` | Must be included in all backups |
| Tier 2 — important | `webapp/openwebui`, `aiserv/hermes`, `aiserv/litellm`, `obsvce/grafana` | Recommended backup |
| Tier 3 — rebuildable | `devops/forgejo/workspace`, `obsvce/victoriametrics`, `obsvce/victorialogs`, `mailsv/bulwark/telemetry` | Shorter retention or exclusion, depending on storage constraints |

### 9. Environment variable and database naming

Naming separates three concerns:

- **Operations → service names.** `<prefix><product>` names are optimised for Docker, logs, and monitoring (decision 2).
- **Business domains → databases and major configuration.** Names describe business capability, not the product implementing it, so a product can be replaced without renaming databases, environment variables, documentation, backup procedures, or runbooks.
- **Products → implementation-specific settings.** Settings that genuinely belong to a product keep the product's name.

#### Database names

Databases follow `svchub_<business-domain>`. Both the values and their variables are renamed:

| New variable | New value | Replaces | Consumer |
|---|---|---|---|
| `POSTOFFICE_DBNAME` | `svchub_postoffice` | `POSTE_DBNAME=svchubmboxdb` | Stalwart (`mailsvstalwart`) |
| `IDENTITY_DBNAME` | `svchub_identity` | `AUTHN_DBNAME=svchubauthtk` | Authentik (`infraauth`) |
| `SOURCECODE_DBNAME` | `svchub_sourcecode` | `DEPOT_DBNAME=svchubsvnrep` | Forgejo (`devopsforgejo`) |
| `WORKSPACE_DBNAME` | `svchub_workspace` | `WBHOME_DBNAME=svchubwbhome` | Confluence (`webappconf`) |
| `AIGATE_DBNAME` | `svchub_aigateway` | `LITEM_DBNAME=litellm` | LiteLLM (`aiservlitellm`) |

#### Database infrastructure variables

| Current | New |
|---|---|
| `SQLDB_USER` | `DB_ADMIN_USER` |
| `SQLDB_PASS` | `DB_ADMIN_PASSWORD` |
| `MySQL_HOST` | `MARIADB_HOST` |
| `MySQL_PORT` | `MARIADB_PORT` |
| `MARIADB_DB_LIST` | `MARIADB_DATABASES` |
| `PGRSQL_HOST` | `POSTGRES_HOST` |
| `PGRSQL_PORT` | `POSTGRES_PORT` |
| `PGRSQL_DBLIST` | `POSTGRES_DATABASES` |

#### Public service domains

| Current | New |
|---|---|
| `AUTHN_DOMAIN` | `IDENTITY_DOMAIN` |
| `DEPOT_DOMAIN` | `SOURCECODE_DOMAIN` |
| `WBHOME_DOMAIN` | `WORKSPACE_DOMAIN` |
| `OWEBUI_DOMAIN` | `CHAT_DOMAIN` |
| `OBSVC_DOMAIN` | `OBSERVABILITY_DOMAIN` |
| `WEBMAIL_DOMAIN` | `POSTOFFICE_DOMAIN` |
| `WBDRIVE_DOMAIN` | `CLOUD_DOMAIN` |

`TRAEFIK_DOMAIN` and `HERMES_WORKSPACE_DOMAIN_00` are kept unchanged.

#### Service configuration variables

| Domain | Current | New |
|---|---|---|
| Identity | `AUTHN_TAG` | `IDENTITY_TAG` |
| Identity | `AUTHN_PASSWD` | `IDENTITY_PASSWORD` |
| Identity | `AUTHN_SECRET` | `IDENTITY_SECRET` |
| Source code | `DEPOT_VTAG` | `SOURCECODE_TAG` |
| Source code | `DEPOT_RUNNER_SECRET` | `SOURCECODE_RUNNER_SECRET` |
| Source code | `DEPOT_RUNNER_VTAG` | `SOURCECODE_RUNNER_TAG` |
| Source code | `DEPOT_PUBLIC_URL` | `SOURCECODE_PUBLIC_URL` |
| Source code | `DEPOT_DEPLOY_TOKEN` | `SOURCECODE_DEPLOY_TOKEN` |
| Workspace | `WBHOME_TAG` | `WORKSPACE_TAG` |
| Cloud | `WBDRIVE_TAG` | `CLOUD_TAG` |
| Cloud | `WBDRIVE_OIDC_ISSUER` | `CLOUD_OIDC_ISSUER` |
| Cloud | `WBDRIVE_OIDC_CLIENT_ID` | `CLOUD_OIDC_CLIENT_ID` |
| Cloud | `WBDRIVE_INSECURE` | `CLOUD_INSECURE` |
| AI gateway | `LITEM_API_KEY` | `AIGATE_API_KEY` |
| AI gateway | `LITEM_API_URL` | `AIGATE_API_URL` |
| AI gateway | `LITEM_ADMUSR` | `AIGATE_ADMIN_USER` |
| AI gateway | `LITEM_ADMPWD` | `AIGATE_ADMIN_PASSWORD` |
| AI gateway | `LITEM_HPH_APIURL` | `AIGATE_HERMES_API_URL` |
| AI gateway | `LITEM_HPH_APIKEY` | `AIGATE_HERMES_API_KEY` |
| AI gateway | `LITEM_HPH_HLTURL` | `AIGATE_HERMES_HEALTH_URL` |
| AI gateway | `LITEM_PRM_APIBASE` | `AIGATE_PROVIDER_API_BASE` |
| AI gateway | `LITEM_PRM_APIKEY` | `AIGATE_PROVIDER_API_KEY` |
| Observability | `OBSVC_ADMUSR` | `OBSERVABILITY_ADMIN_USER` |
| Observability | `OBSVC_ADMPWD` | `OBSERVABILITY_ADMIN_PASSWORD` |

`SOURCECODE_PUBLIC_URL` and `SOURCECODE_DEPLOY_TOKEN` live in Forgejo repository Actions settings rather than `.env`. They were required by the clone-based deploy workflow; the workflow now syncs the working tree from the runner checkout and reads neither entry, so renaming them in the Forgejo UI is no longer deployment-critical.

#### Product-specific variables kept as-is

`STALWART_ADMIN_USER`, `STALWART_ADMIN_PASS`, `WEBMAIL_SESSION_SECRET`, `TRAEFIK_ACMEMAIL`, `TRAEFIK_BAAUTH`, `CERTRESOLVER`, `HF_TOKEN`, `LLAMA_CHTMDL`, `LLAMA_CHTARG`, `HERMES_WORKSPACE_PASSWD_00`, `HERMES_DATA_00`.

#### Final business domains

| Business domain | Identifier |
|---|---|
| Identity | `svchub_identity` |
| Source code | `svchub_sourcecode` |
| Workspace | `svchub_workspace` |
| Cloud | oCIS cloud storage |
| Post office | `svchub_postoffice` |
| AI gateway | `svchub_aigateway` |
| Observability | Monitoring platform |

The AI Gateway business domain (`svchub_aigateway`) is hosted operationally by the `aiserv` compose domain.

Operational domains and business domains serve different purposes and are not required to use identical names.

Examples:

- `infraauth` → `svchub_identity`
- `devopsforgejo` → `svchub_sourcecode`
- `webappconf` → `svchub_workspace`
- `mailsvstalwart` → `svchub_postoffice`
- `aiservlitellm` → `svchub_aigateway`

Service names are optimised for operations and deployment boundaries; database names and major configuration identifiers are optimised for business capability and long-term product independence.

Global, email, and optional-stack variables are outside this decision and keep their current names: `TIME_ZONE`, `APPS_DATA`, `TRUSTED_IP`, `DOMAIN_NAME`, `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_USER`, `EMAIL_PASS`, `EMAIL_FROM`, and `FCRW_API_URL`.

`MARIADB_DATABASES` and `POSTGRES_DATABASES` reference the database variables, so the initialisation lists follow the new values without a separate edit. A variable rename does not propagate by itself: every reference in `env.example`, `compose/*.yml`, `scripts/setup.sh`, the Forgejo Actions workflows, `shared/` configuration, and documentation must change in the same commit, and each live database must be renamed in place (for example `ALTER DATABASE … RENAME TO …`) or dumped and restored under the new name, with every consumer updated in the same maintenance window.

## Decision Drivers

- Consistent, product-oriented service names that make dependencies and troubleshooting obvious.
- A storage hierarchy that mirrors the compose domains so backup scope and recovery steps follow the same structure.
- Reduced Docker socket and host filesystem exposure.
- A clear separation between runtime state (backed up) and repository-managed configuration (not a primary backup target).
- Business-domain names for databases and major configuration, so a product can be replaced without renaming databases, variables, documentation, backups, or runbooks.
- A single coordinated migration rather than repeated partial renames.

## Options Considered

1. Retain the current organic naming and layout, documenting the inconsistencies only.
2. Standardise naming, compose grouping, storage layout, bind mounts, and backup tiers together (selected).
3. Standardise service names first and defer storage and mount changes to a later change.

## Rationale

Option 2 satisfies every driver in one migration window. Renaming services without moving storage would leave backup scope and mount paths inconsistent with the new domains, and moving storage without renaming would leave Traefik labels, workflow service choices, and dashboards describing the old names. Option 1 leaves the identified inconsistencies in place and lets them spread to new services. The coordinated change costs one migration but avoids a second pass over the same files.

## Positive Consequences

- Consistent service naming and storage hierarchy across all domains.
- Simpler backup management and disaster recovery because tiers follow the directory tree.
- Reduced Docker socket and host filesystem exposure.
- Clear separation between runtime state and repository-managed configuration.
- Easier troubleshooting through product-oriented service names.

## Negative Consequences

- One-time migration of service names and storage directories.
- Required updates to Docker Compose files, `env.example`, `scripts/setup.sh`, Traefik labels, monitoring dashboards, backup jobs, documentation, and Forgejo Actions workflows.
- A rebuild of affected service topology (routers, containers, and registration state) rather than an in-place upgrade.

## Risks

- Data migration of `${APPS_DATA}` may lose or corrupt state; mitigate with a full ADR-007 backup taken immediately before the move and a verified restore path, with residual uncertainty until a restore is rehearsed.
- Traefik router and middleware label renames may break routes; mitigate by re-checking every host route after the rename.
- Backup continuity may break while paths change; mitigate by running a backup before and immediately after the migration and confirming both target copies.
- Monitoring dashboards and log discovery may go stale; mitigate by updating Alloy and Grafana provisioning in the same change.
- An environment variable renamed in only some of its reference sites breaks configuration at deploy time; mitigate by changing every reference in one commit and validating with `docker compose config` plus a `scripts/setup.sh` run before deployment.
- The 13-character target cannot hold for every name (`aiservllamacpp` is 14); accepted as a documented exception.

## Implementation Evidence

Repository changes applied on branch `service-renaming` as atomic commits:

- `975c701` — compose files restructured into the seven domains; the 25 services, Traefik labels, `depends_on` references, workflows, and documentation renamed (decisions 1 and 2).
- `79e810a` — `${APPS_DATA}` migrated to the domain layout with hardened mounts (`:ro`, removal of `/etc/localtime` and the Hermes Docker socket mount, Alloy rootfs mount reduction) and certificates moved to `${APPS_DATA}/shared/certs` (decisions 3–7).
- `41f6b1d` — environment variables and database names renamed across `env.example`, `compose/*.yml`, `scripts/setup.sh`, Forgejo workflows, `shared/` configuration, and living documentation, including a `setup.sh` migration block that rewrites ADR-007-era `.env` files (decision 9); hardened by `e60088a` (stale `WBCLOUD_*` oCIS keys and quoted database values migrate correctly). The migration block has since been removed: the owner applied the `.env` rename manually, and variable renames are no longer automatic.
- `55e37ac` — optional-stack services (`aiservfastcrw`, `aiservsearxng`, `aiservchromum`, `aiservlighpda`, `webappwpress`) brought onto the same convention (decision 2).
- `76ec13e` — the Forgejo Actions secret and variable renamed to `SOURCECODE_DEPLOY_TOKEN` / `SOURCECODE_PUBLIC_URL` (decision 9).
- `9e636af` — prebuilt dashboard panels for metrics disabled by the mount removals stripped (decision 5 consequence).
- `7f9bfe0` — the stale Hermes `README.html` guide retired (documentation hygiene; not part of the decision).

Static validation on the branch: every compose file parses as YAML, all `depends_on` targets resolve, every compose-interpolated `${VAR}` exists in `env.example`, and no superseded service, path, or variable names remain outside historical records. Pending and owner-run: `docker compose config` and a `setup.sh` merge check on a server, plus the database renames in their maintenance window.

Superseded baseline: the pre-change compose set (`route.yml`, `dbsvc.yml`, `authn.yml`, `depot.yml`, `wbapp.yml`, `aiagn.yml`, `obsvc.yml`, `poste.yml`), the bind mounts and labels recorded in [SERVICE-INVENTORY](../operations/SERVICE-INVENTORY.md), and the pre-change variable prefixes in [env.example](../../env.example).

## Related Documents

- [ADR-006 Adopt oCIS with Local Filesystem Storage](ADR-006-adopt-ocis-with-local-filesystem-storage.md) — oCIS storage paths affected by the new layout.
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](ADR-007-adopt-dual-target-backup-and-recovery.md) — backup scope and workflow affected by the tier model.
- [Service inventory](../operations/SERVICE-INVENTORY.md) — current service names and mounts.
- [Backup and restore](../operations/BACKUP-RESTORE.md) — backup scope re-expressed with the tier model.
- [Architecture](../architecture/ARCHITECTURE.md) — component and boundary diagrams updated by this decision.

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Rename compose files to the seven domains and move each service into its domain file | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`975c701`); server validation pending |
| Apply the `<prefix><product>` and `<prefix><product>init` names, including Traefik router and service labels | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`975c701`); server validation pending |
| Migrate `${APPS_DATA}` to the domain layout and update every bind mount | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`79e810a`); host migration pending |
| Remove the listed bind mounts, restrict Docker socket access, and replace `/etc/localtime` with `TZ` | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`79e810a`); server validation pending |
| Move certificates to `${APPS_DATA}/shared/certs` and update Traefik and Stalwart consumers | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`79e810a`); host ACME migration pending |
| Apply the environment variable and database variable renames across `env.example`, `compose/*.yml`, `scripts/setup.sh`, workflows, `shared/` configuration, and documentation in one change | ServiceHub Architecture | 2026-10-05 | Repository change applied on `service-renaming` (`41f6b1d`); `.env` files migrated manually by the owner and the `setup.sh` migration block removed (2026-10-06); server validation pending |
| Update backup scope and exclusions to the tier classification under ADR-007 | ServiceHub Architecture | 2026-10-05 | Tier classification documented in [BACKUP-RESTORE](../operations/BACKUP-RESTORE.md); exclusion values remain deployment secrets |
| Rename the five databases to the `svchub_<purpose>` values and update every consumer in one maintenance window | ServiceHub Architecture | TBD | Proposed; `.env` values migrated manually — server-side database rename and grants pending |
| Update Forgejo Actions deploy and backup workflows, monitoring provisioning, and dashboards | ServiceHub Architecture | 2026-10-05 | Workflows and monitoring configuration renamed (`975c701`, `41f6b1d`, `76ec13e`); dead dashboard panels for the removed mounts stripped (`9e636af`); runtime provisioning pending |
| Rename `SOURCECODE_PUBLIC_URL` and `SOURCECODE_DEPLOY_TOKEN` in Forgejo repository Actions settings on staging and production | George Li | TBD | Superseded — the deploy workflow syncs the working tree from the runner checkout and reads neither entry; removing them from the Forgejo UI is optional (repository side applied on `service-renaming` (`76ec13e`)) |
| Update documentation, service inventory, and architecture records in the same change | George Li | 2026-10-05 | Living documentation updated across the three `service-renaming` commits |
| Validate with `docker compose config` and a staging deployment, and record the evidence | ServiceHub Architecture | TBD | Proposed |
