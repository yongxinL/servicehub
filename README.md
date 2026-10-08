# ServiceHub

> A quiet harbor where HomeLab services arrive, find their place, and don't get lost again

ServiceHub is a self-hosted HomeLab services platform built on Docker Compose. It provides a curated stack of infrastructure, developer tools, an AI agent platform and an observability stack behind a single Traefik reverse proxy with automatic TLS — deployable to staging or production via a one-click Forgejo Actions workflow.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Core Services](#core-services)
- [DevOps (Source Control + CI)](#devops-source-control--ci)
- [AI Agent Platform (aiserv)](#ai-agent-platform-aiserv)
- [Web Applications](#web-applications)
- [Observability Stack (obsvce)](#observability-stack-obsvce)
- [Email Stack (mailsv)](#email-stack-mailsv)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Managing Encrypted Files (git-crypt)](#managing-encrypted-files-git-crypt)
- [Deployment (Forgejo Actions)](#deployment-forgejo-actions)
- [Usage](#usage)
- [Configuration](#configuration)
- [License](#license)

---

## Documentation

Repository-backed project documentation is authoritative:

- [Documentation home](docs/README.md)
- [Architecture](docs/architecture/ARCHITECTURE.md)
- [Architecture decisions](docs/adr/README.md)
- [RFCs](docs/rfc/README.md)
- [Development phases](docs/phases/README.md)
- [Operations](docs/operations/README.md)
- [Releases](docs/releases/README.md)

Use the [documentation home](docs/README.md) for requirements, testing, investigations, lessons, and templates. The Forgejo Wiki and Confluence are not sources of truth.

---

## Architecture Overview

All traffic enters through Traefik on ports 80/443. HTTP is redirected to HTTPS. Traefik routes requests to the appropriate service by hostname and terminates TLS using either Let's Encrypt (production) or a self-signed certificate (staging). All services communicate over an isolated Docker bridge network (`subnet`); Confluence's outbound traffic is further restricted to private destinations by a host firewall rule ([ADR-009 §5](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)). Databases are not exposed outside the network.

Compose files are split by functional domain:

| File | Prefix | Purpose |
|---|---|---|
| `compose/route.yml` | `route*` | Edge routing + TLS termination (Traefik) |
| `compose/infra.yml` | `infra*` | Relational databases (MariaDB + PostgreSQL) |
| `compose/infra.yml` | `infra*` | Authentication / SSO (Authentik) |
| `compose/devops.yml` | `devops*` | Source control, CI, and backups (Forgejo plus its Actions runner) |
| `compose/webapp.yml` | `webapp*` | Homepage / CMS (Confluence) and oCIS cloud drive |
| `compose/aiserv.yml` | `aiserv*` | AI platform (Open WebUI + Hermes + LiteLLM + llama.cpp) — hosted on local infrastructure, not deployed to OCI ([ADR-009](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)) |
| `compose/obsvce.yml` | `obsvce*` | Observability (metrics + logs + Grafana) — retained in the repository, not deployed to OCI ([ADR-009](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)) |
| `compose/mailsv.yml` | `mailsv*` | Email services (Stalwart mail server + Bulwark webmail) |

```mermaid
graph TD
    Internet((Internet\n:80 / :443))
    Internet --> Traefik

    subgraph subnet[Docker Network: subnet]
        Traefik[routetraefik\nReverse Proxy + TLS]
        Traefik -->|traefik.domain| Dashboard[Traefik Dashboard]
        Traefik -->|login.domain| Authentik[infraauth\nIdP / SSO]
        Traefik -->|git.domain| Forgejo[devopsforgejo\nForgejo + Actions]
        Traefik -->|www.domain + apex| Confluence[webappconf\nConfluence]
        Traefik -->|chats.domain| OpenWebUI[aiservowui\nOpen WebUI]
        Traefik -->|drive.domain| Cloud[webappocis\nownCloud Infinite Scale]
        Traefik -->|space0.domain| Hermes[aiservhermes\nHermes Agent]
        Traefik -->|stats.domain| Grafana[obsvcegrafana\nGrafana]
        Traefik -->|mail.domain| Stalwart[mailsvstalwart\nStalwart Mail Server]
        Traefik -->|webmail.domain| Bulwark[mailsvbulwark\nBulwark Webmail]
        Bulwark -->|JMAP via Docker DNS| Stalwart
        Authentik -.->|forward-auth| Grafana
        Authentik -.->|OIDC| Cloud
        Cloud --> CloudData[(Local filesystem)]
        Forgejo -->|depends on| PostgreSQL[(infrapgsql\nPostgreSQL)]
        Authentik -->|depends on| PostgreSQL
        Confluence -->|depends on| Authentik
        Forgejo -->|dispatches| Runner[devopsrunner\nForgejo Actions Runner]
        Hermes -->|hermes| LiteLLM[aiservlitellm\nComplexity Router]
        LiteLLM -->|depends on| PostgreSQL
        LiteLLM -->|hephaestus| Gemma[aiservllamacpp\nllama.cpp Gemma-4 local]
        LiteLLM -->|prometheus| MiniMax[MiniMax 2.7\nCloud API]
        Grafana -.->|metrics| VM[obsvcevm\nVictoriaMetrics]
        Grafana -.->|logs| VL[obsvcevlogs\nVictoriaLogs]
        VM -.->|scrapes| Alloy[obsvcealloy\nGrafana Alloy]
        VL -.->|receives| Alloy
    end

    Runner -->|executes| WPDeploy[deploy workflow\n.forgejo/workflows/61-deploy.yml]
    Runner -->|executes| BackupFlow[backup workflow\n.forgejo/workflows/71-backup.yml]
    WPDeploy -->|SSH deploy| RemoteServer[Remote Server\nStag / Prod]
    BackupFlow -->|SSH create + transfer| Home[Home Server\nRestic]
    BackupFlow -->|Rclone| Drive[Google Drive]
```

**TLS strategy:**
- **Staging:** self-signed certificate from `shared/traefik/advanced/selfsigncert/` (git-crypt encrypted, referenced by `shared/traefik/advanced/certificates.yml`)
- **Production:** Let's Encrypt ACME TLS challenge; `acme.json` is stored at `${APPS_DATA}/shared/certs/acme.json` and restored from an encrypted Actions secret on deploy

---

## Project Structure

```
servicehub/
├── .forgejo/
│   └── workflows/
│       ├── 61-deploy.yml                 # Forgejo Actions deployment workflow (self-contained)
│       └── 71-backup.yml                 # Dual-target backup creation, transfer, integrity, and retention workflow
├── compose/                    # Per-domain Docker Compose files
│   ├── route.yml               # Traefik (routetraefik)
│   ├── infra.yml               # MariaDB + PostgreSQL
│   ├── infra.yml               # Authentik server + worker + init
│   ├── webapp.yml               # Confluence + oCIS cloud drive
│   ├── aiserv.yml               # Open WebUI + Hermes agents + LiteLLM + llama.cpp
│   ├── devops.yml               # Forgejo + Forgejo Actions runner
│   ├── obsvce.yml               # Observability stack (VictoriaMetrics + VictoriaLogs + Grafana), not deployed to OCI
│   └── mailsv.yml               # Email services (Stalwart mail server + Bulwark webmail)
├── shared/                     # Shared build contexts and static config
│   ├── traefik/
│   │   ├── README.md                     # Traefik service documentation
│   │   ├── Dockerfile
│   │   └── advanced/
│   │       ├── certificates.yml          # Self-signed TLS config (staging)
│   │       ├── middlewares-authentik.yml # Authentik forward-auth middleware
│   │       ├── metrics.yml               # Traefik Prometheus metrics config
│   │       └── selfsigncert/             # git-crypt encrypted cert/key material
│   ├── authentik/
│   │   ├── README.md                     # Authentik service documentation
│   │   └── Dockerfile
│   ├── forgejo/
│   │   ├── README.md                     # Forgejo service + Actions runner documentation
│   │   ├── server/Dockerfile             # Forgejo server image
│   │   └── actions/Dockerfile            # Forgejo Actions runner image
│   ├── confluence/
│   │   ├── README.md                     # Confluence service documentation
│   │   ├── Dockerfile
│   │   └── plugins/
│   ├── hermesagent/
│   │   ├── README.md                     # Hermes Agent documentation
│   │   ├── Dockerfile
│   │   ├── start-gateways.sh             # Entrypoint: seeds defaults, starts gateway + workspace
│   │   ├── init-profile.sh               # One-shot profile seeder (run on first container exec)
│   │   ├── apply-overlay.sh              # Replays persisted /opt/hermes edits at startup
│   │   ├── overlay-*                     # Overlay tooling (track / save / patch)
│   │   └── default/                      # Default profile files baked into the image
│   ├── litellm/
│   │   ├── README.md                     # LiteLLM service documentation
│   │   ├── Dockerfile
│   │   ├── config.default.yaml           # LiteLLM routing config (baked into image)
│   │   ├── smartrouter.py                # Content-based routing hook (privacy + complexity)
│   │   └── entrypoint.sh
│   ├── llamacpp/
│   │   ├── README.md                     # llama.cpp chat inference documentation
│   │   ├── Dockerfile
│   │   └── entrypoint.sh                 # Reads LLAMA_* env vars
│   ├── openwebui/
│   │   ├── README.md                     # Open WebUI service documentation
│   │   └── Dockerfile
│   ├── owncloud/
│   │   ├── README.md                     # ownCloud Infinite Scale documentation
│   │   ├── Dockerfile                    # webappocis image build
│   │   └── entrypoint.sh                 # oCIS init and server startup
│   ├── fastcrw/                          # Optional web-search stack (not included by default)
│   │   ├── README.md                     # FastCRW + renderers + SearXNG documentation
│   │   ├── Dockerfile                    # aiservfastcrw image build
│   │   ├── compose.yml                   # aiservfastcrw
│   │   ├── config.docker.toml
│   │   ├── entrypoint.sh
│   │   ├── chromium/                     # aiservchromum — browserless stealth renderer
│   │   │   ├── compose.yml
│   │   │   └── Dockerfile
│   │   └── lightpanda/                   # aiservlighpda — LightPanda JS renderer
│   │       ├── compose.yml
│   │       └── Dockerfile
│   ├── searxng/                          # Optional search backend
│   │   ├── compose.yml                   # aiservsearxng
│   │   └── Dockerfile
│   ├── grafana/
│   │   ├── README.md                     # Grafana service documentation
│   │   ├── Dockerfile
│   │   ├── alloy/                        # Grafana Alloy config + README
│   │   ├── dashboards/                   # Pre-built observability dashboards
│   │   ├── geoip/                        # GeoIP database for log enrichment
│   │   └── provisioning/                 # Grafana datasources + dashboard provisioning
│   ├── victoriametrics/
│   │   ├── README.md                     # VictoriaMetrics documentation
│   │   ├── Dockerfile
│   │   └── scrape.yaml                   # Metrics scrape configuration
│   ├── victorialogs/
│   │   ├── README.md                     # VictoriaLogs documentation
│   │   └── Dockerfile
│   ├── mariadb/
│   │   ├── README.md                     # MariaDB service documentation
│   │   ├── Dockerfile
│   │   └── create-multiple-databases.sh
│   ├── postgresql/
│   │   ├── README.md                     # PostgreSQL service documentation
│   │   ├── Dockerfile
│   │   └── create-multiple-databases.sh
│   ├── stalwart/                          # Stalwart Mail Server (mailsvstalwart)
│   │   ├── README.md                      # Stalwart service documentation
│   │   ├── Dockerfile
│   │   ├── config.json                    # Stalwart PostgreSQL DataStore template (rendered at container start)
│   │   ├── entrypoint.sh                  # Bootstrap cert + privilege drop
│   │   └── acme-export.sh                 # Extracts certs from Traefik's acme.json
│   ├── bulwark/                           # Bulwark Webmail (mailsvbulwark)
│   │   ├── README.md                      # Bulwark service documentation
│   │   └── Dockerfile
│   └── wordpress/                        # Optional alternative homepage (not included by default)
│       ├── README.md
│       ├── compose.yml
│       └── ...
├── scripts/
│   └── setup.sh                 # Local setup, env merge and secret encoding helper
├── docker-compose.yml          # Main entry point (includes all compose/ files)
├── env.example                 # Environment variable template
└── LICENSE
```

---

## Core Services

| Service | Runs as | Full documentation |
|---|---|---|
| Traefik v3 — edge router + TLS termination | `routetraefik` | [shared/traefik/README.md](shared/traefik/README.md) |
| MariaDB 11.8 — MySQL-compatible database | `inframariadb` | [shared/mariadb/README.md](shared/mariadb/README.md) |
| PostgreSQL 16 — primary database | `infrapgsql` | [shared/postgresql/README.md](shared/postgresql/README.md) |

> Service-specific configuration, data layout, first-boot steps and operations notes live in each service's own `README.md` under `shared/`.

---

## DevOps (Source Control + CI)

| Service | Runs as | Full documentation |
|---|---|---|
| Forgejo — self-hosted Git service + Actions | `devopsforgejo`, `devopsrunner` | [shared/forgejo/README.md](shared/forgejo/README.md) |

Setup, configuration, Actions runner registration and operations are documented in the service README. Forgejo Actions also deploys the application services (databases, Authentik, Forgejo and Traefik are foundational and deployed manually) — see [Deployment (Forgejo Actions)](#deployment-forgejo-actions).

---

## AI Agent Platform (aiserv)

Local and cloud LLM services power the Hermes AI agents. The llama.cpp server provides fast, private on-device inference; LiteLLM acts as a unified API gateway and complexity router between local and cloud providers. All AI services live in [`compose/aiserv.yml`](compose/aiserv.yml). Per [ADR-009](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) the AI platform runs on local infrastructure and is excluded from the OCI deployment.

| Service | Runs as | Full documentation |
|---|---|---|
| Open WebUI — AI platform chat interface | `aiservowui` | [shared/openwebui/README.md](shared/openwebui/README.md) |
| Hermes Agent — single shared agent workspace + gateway | `aiservhermes` (+ one-shot `aiservhermesinit`) | [shared/hermesagent/README.md](shared/hermesagent/README.md) |
| LiteLLM Proxy — unified API gateway + complexity router | `aiservlitellm` | [shared/litellm/README.md](shared/litellm/README.md) |
| llama.cpp chat inference — local Gemma tier | `aiservllamacpp` | [shared/llamacpp/README.md](shared/llamacpp/README.md) |

**At a glance:**

| Detail | Value |
|---|---|
| Hermes workspace port | 12320 (login with `HERMES_WORKSPACE_PASSWD_00`) |
| Hermes gateway API port | 12330 (internal) |
| LiteLLM admin UI | `http://<host>:12380/ui` |
| Local model | Gemma 4 GGUF on llama.cpp (`hephaestus`) |
| Cloud model | MiniMax 2.7 (`prometheus`) |

**LLM routing from Hermes:** all agent requests use `model: hermes`; the LiteLLM proxy routes to hephaestus (local Gemma) or prometheus (MiniMax 2.7) based on message content. Users can override by prefixing their message:

```
[cloud] write a grant proposal for the school...   → prometheus / MiniMax 2.7
[c] debug this system architecture...              → prometheus / MiniMax 2.7 (shorthand)
[edge] summarise my tax return                    → hephaestus / Gemma (stays private)
[e] translate this paragraph                       → hephaestus / Gemma (shorthand)
```

See [shared/litellm/README.md](shared/litellm/README.md#routing-logic) for the full routing rules, and [shared/hermesagent/README.md](shared/hermesagent/README.md) for the workspace, overlay system and profiles.

### Multi-user & scaling

Hermes Agent is **single-user / single-tenant**: one container serves exactly one login and one agent identity. Everything under a Hermes home — sessions, `MEMORY.md`, `USER.md`, skills and `state.db` — is shared by anyone logged into that container. Upstream is explicit that profiles are *configuration, not a person* and that profile multiplexing "does not authenticate or authorize end users". See [shared/hermesagent/README.md](shared/hermesagent/README.md#multi-user-support) for the full findings.

The stack therefore ships **one** Hermes Agent (`aiservhermes`) that acts as a shared team assistant. When more people need their **own** private agent, add another isolated container rather than sharing one login. To scale to N users, replicate the `aiservhermes` pattern in [`compose/aiserv.yml`](compose/aiserv.yml):

1. **Add a data volume + init entry** — extend `aiservhermesinit` with `/data0X`, or add a sibling init container, pointing at `${APPS_DATA}/aiserv/hermes/0X`.
2. **Duplicate the `aiservhermes` service** as `aiservhermes0X`, with:
   - its own `${HERMES_DATA_0X}:/opt/data` volume,
   - its own `HERMES_WORKSPACE_PASSWD_0X` and (optionally) `HERMES_WORKSPACE_DOMAIN_0X`,
   - a unique host port (`1232X:12320`).
3. **Add the matching `HERMES_WORKSPACE_PASSWD_0X`, `HERMES_DATA_0X` and `HERMES_WORKSPACE_DOMAIN_0X`** variables to `.env` / [`env.example`](env.example).
4. **Recreate** with `docker compose up -d --build aiservhermes0X`.

All agents share the same `aiservlitellm` router and `aiservllamacpp` model, so GPU/RAM scaling is handled centrally there — only per-user data and the workspace need duplicating. For identity-aware routing you can front the agents with Authentik and map each user to a container, but do **not** point multiple people at a single Hermes login.

---

## Web Applications

| Service | Runs as | Full documentation |
|---|---|---|
| Authentik — IdP / SSO | `infraauth`, `infraauthwrk` (+ one-shot `infraauthinit`) | [shared/authentik/README.md](shared/authentik/README.md) |
| Confluence Data Center — homepage / CMS | `webappconf` | [shared/confluence/README.md](shared/confluence/README.md) |
| ownCloud Infinite Scale — family cloud drive | `webappocis` (+ one-shot `webappocisinit`) | [shared/owncloud/README.md](shared/owncloud/README.md) |

Confluence serves `WORKSPACE_DOMAIN` (default `www.${DOMAIN_NAME}`) and the apex `${DOMAIN_NAME}` through Traefik, backed by PostgreSQL (`${WORKSPACE_DBNAME}`). Open WebUI (AI platform, `compose/aiserv.yml`) is served at `https://${CHAT_DOMAIN}`. oCIS is served at `https://${CLOUD_DOMAIN}`, authenticates through Authentik OIDC, and uses local filesystem paths without a dedicated PostgreSQL database.

> **Database lists only initialize empty data directories.** Updating `POSTGRES_DATABASES` or `MARIADB_DATABASES` does not create databases or change credentials in an existing installation; provision any missing database and grants explicitly without resetting existing data.
>
> An optional [WordPress homepage](shared/wordpress/README.md) can replace Confluence; the two must never run together.

---

## Observability Stack (obsvce)

A full metrics and log observability stack built on Grafana, VictoriaMetrics, VictoriaLogs, and Grafana Alloy. All components live in [`compose/obsvce.yml`](compose/obsvce.yml). Per [ADR-009](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) this stack is retained in the repository but is not deployed to OCI; [ADR-010](docs/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md) records the Oracle Cloud APM, Monitoring, and Logging replacement for OCI-hosted workloads, which is not yet configured.

| Component | Runs as | Full documentation |
|---|---|---|
| VictoriaMetrics — time-series metrics store | `obsvcevm` | [shared/victoriametrics/README.md](shared/victoriametrics/README.md) |
| VictoriaLogs — log aggregation | `obsvcevlogs` | [shared/victorialogs/README.md](shared/victorialogs/README.md) |
| Grafana Alloy — host/container/metrics/log collector | `obsvcealloy` | [shared/grafana/alloy/README.md](shared/grafana/alloy/README.md) |
| Grafana — dashboards for metrics and logs | `obsvcegrafana` (+ one-shot `obsvcegrafanainit`) | [shared/grafana/README.md](shared/grafana/README.md) |

```mermaid
graph LR
    subgraph Collectors[Collection]
        Alloy[obsvcealloy\nHost + Container + Traefik]
    end
    subgraph Storage[Storage]
        VM[obsvcevm\nTime-series metrics]
        VL[obsvcevlogs\nLog aggregation]
    end
    subgraph Visualization[Visualization]
        Grafana[obsvcegrafana\nDashboards]
    end
    Alloy -->|metrics push| VM
    Alloy -->|logs push| VL
    Grafana -->|query| VM
    Grafana -->|query| VL
```

Grafana is reachable at `https://${OBSERVABILITY_DOMAIN}` behind Authentik forward-auth and ships pre-built dashboards for node, Docker/cAdvisor, Traefik, VictoriaMetrics, LiteLLM and VictoriaLogs.

---

## Email Stack (mailsv)

A self-hosted email stack: [Stalwart](https://github.com/stalwartlabs/stalwart) provides SMTP, IMAP and JMAP in one server; [Bulwark](https://github.com/bulwarkmail/webmail) provides the JMAP webmail UI. All services live in [`compose/mailsv.yml`](compose/mailsv.yml).

| Service | Runs as | Full documentation |
|---|---|---|
| Stalwart Mail Server — SMTP / IMAP / JMAP + web admin | `mailsvstalwart` | [shared/stalwart/README.md](shared/stalwart/README.md) |
| Bulwark Webmail — JMAP webmail client | `mailsvbulwark` | [shared/bulwark/README.md](shared/bulwark/README.md) |

**At a glance:**

| Detail | Value |
|---|---|
| Mail server (Stalwart admin) | `https://${EMAIL_HOST}` — reachable from trusted IPs only |
| Webmail (Bulwark) | `https://${POSTOFFICE_DOMAIN}` |
| Ports published to the host | 25 / 465 / 587 / 993 (SMTP server-to-server, submission ×2, IMAP) |
| Storage | PostgreSQL (`${POSTOFFICE_DBNAME}` on `infrapgsql`) holds all mail data — accounts, messages, indexes, blobs |
| TLS | Reused from Traefik's shared `acme.json` via an in-container certificate exporter |
| Webmail → Stalwart | JMAP at `https://${EMAIL_HOST}` — browser-side, so Stalwart needs **Permissive CORS** (`usePermissiveCors`) and a trusted certificate (see [Bulwark — Login prerequisites](shared/bulwark/README.md#login-prerequisites-stalwart-side)) |
| Single sign-on | Authentik serves the directory: webmail users log in with their Authentik password through the JMAP password form, IMAP/SMTP/JMAP logins bind against Authentik's LDAP outpost |

The SMTP/IMAP ports are reachable directly (bypassing Traefik); DNS `MX`/`A` records for `${EMAIL_HOST}` must point at the host. Other stack components send mail through Stalwart using the `EMAIL_*` variables documented in [Configuration](#configuration). Accounts come from Authentik over LDAP for every path — webmail, IMAP, SMTP, JMAP (webmail OIDC SSO is not used; it requires an OIDC-backed Stalwart directory — see [Bulwark — SSO/OIDC](shared/bulwark/README.md#sso--oidc-not-used)) — setup walkthrough in the [Stalwart README](shared/stalwart/README.md#initial-provisioning-walkthrough), with the full [Authentik LDAP directory setup](shared/stalwart/README.md#directory-authentik-ldap-sso) (provider, service account, outpost) documented there as well.

---

## Prerequisites

- **Docker** 24+ with **Compose 2.20+** (`docker compose` or standalone `docker-compose` v2) for `include` support
- **python3** 3.8+ (required by `scripts/setup.sh`)
- **Git** 2.x
- **git-crypt** (macOS: `brew install git-crypt`) — required to encrypt/decrypt self-signed certificates stored in the repo. The deploy workflow decrypts them in the runner checkout; the deploy server needs neither git nor git-crypt.
- A domain name with DNS A records pointing to your server (for Let's Encrypt) **or** a local domain with a self-signed certificate (for staging)
- A Linux server with SSH access (for remote deployment). The deploy user needs Docker access, `rsync`, and **passwordless sudo** (`NOPASSWD`) — the workflow syncs the working tree with rsync and installs the root-owned ACME store (`${APPS_DATA}/shared/certs/acme.json`, mode `600`, contains private keys):

  ```bash
  echo "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/servicehub-deploy
  ```
- `openssl` (used by `setup.sh` to generate database passwords)

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yongxinL/servicehub.git
cd servicehub
```

### 2. Initial Setup

Run the setup script to create your `.env` from the template. It auto-generates strong passwords and API keys for all services:

```bash
bash scripts/setup.sh
```

If `.env` already exists (e.g., after pulling updates), the script merges new variables from `env.example` without overwriting existing values. Variable renames are not migrated automatically — they are a manual one-time edit.

### 3. Configure Environment Variables

Edit `.env` to match your environment:

```bash
# Required — set these before first start
DOMAIN_NAME=example.com          # Your primary domain
TRAEFIK_DOMAIN=traefik.${DOMAIN_NAME}   # keep the ${DOMAIN_NAME} form: a later domain change follows it
IDENTITY_DOMAIN=login.${DOMAIN_NAME}    # Authentik hostname
SOURCECODE_DOMAIN=git.${DOMAIN_NAME}    # Forgejo hostname
TRAEFIK_ACMEMAIL=you@example.com # Let's Encrypt registration email
APPS_DATA=~/Documents/containerd # Default host path for persistent data
TIME_ZONE=Australia/Sydney
WORKSPACE_DOMAIN=www.${DOMAIN_NAME}
WORKSPACE_DBNAME=svchub_workspace
WORKSPACE_TAG=10.2
```

See [Configuration](#configuration) for the variable reference. For an existing installation, retain database names and credentials rather than copying new-install defaults.

### 4. Prepare TLS

For **production** (Let's Encrypt), Traefik creates `${APPS_DATA}/shared/certs/acme.json` automatically on the first successful certificate issuance — no manual step is needed. Verify its permissions are restricted after it is created (Traefik refuses to use a world-readable file):

```bash
chmod 600 ${APPS_DATA}/shared/certs/acme.json
```

For **staging** (self-signed), place your `.pem` and `.key` files in `shared/traefik/advanced/selfsigncert/` matching `shared/traefik/advanced/certificates.yml`. These are encrypted with git-crypt before committing. No `acme.json` is needed.

For remote deployments via the Forgejo Actions workflow, `acme.json` is restored automatically from the `*_B64ENC_ACME` secret (gzip+base64 encoded via `setup.sh --encode`) with `install -m 600 -o root -g root`, so ownership and permissions are deterministic. The restore only overwrites the existing file if the secret is newer, preserving certificates renewed by Traefik since the last encode.

### 5. Prepare Data Directories

Service init containers (`infraauthinit`, `devopsforgejoinit`, `aiservhermesinit`, `obsvcegrafanainit`) fix ownership on every boot. To prepare directories ahead of time:

```bash
mkdir -p ${APPS_DATA}/infra/{mariadb,postgresql}
mkdir -p ${APPS_DATA}/infra/authentik/{media,templates}
mkdir -p ${APPS_DATA}/shared/certs
mkdir -p ${APPS_DATA}/devops/forgejo/{data,runner}
mkdir -p ${APPS_DATA}/aiserv/hermes/00
mkdir -p ${APPS_DATA}/mailsv/{stalwart,bulwark}
chown -R 1000:1000 ${APPS_DATA}/devops/forgejo/{data,runner}
```

Replace `${APPS_DATA}` with the actual path you set in `.env` (default: `~/Documents/containerd`). Homepage data lives under `${APPS_DATA}/webapp/confluence`; follow the service README for directory ownership.

### 6. Start the Stack

Start the base services and the default homepage (Confluence).

```bash
docker compose up -d
```

Or start a specific service:

```bash
docker compose up -d devopsforgejo
```

---

## Managing Encrypted Files (git-crypt)

Self-signed certificates for staging are stored **encrypted** in `shared/traefik/advanced/selfsigncert/` using [git-crypt](https://github.com/AGWA/git-crypt). They appear as binary blobs to anyone without the key, making it safe to commit them. The deploy workflow decrypts them in the runner checkout before syncing the working tree to the remote server.

### One-time Setup (new repository)

```bash
# 1. Initialise git-crypt in the repo (only needed once)
git-crypt init

# 2. Export the symmetric key — back this up securely (password manager, etc.)
#    Losing this key means losing access to all encrypted files permanently.
git-crypt export-key ./servicehub.key

# 3. Verify .gitattributes is present (already included in this repo)
cat .gitattributes
```

`.gitattributes` encrypts every certificate file under the self-signed cert directory:

```
shared/traefik/advanced/selfsigncert/*.pem filter=git-crypt diff=git-crypt
shared/traefik/advanced/selfsigncert/*.key filter=git-crypt diff=git-crypt
shared/traefik/advanced/selfsigncert/*.crt filter=git-crypt diff=git-crypt
shared/traefik/advanced/selfsigncert/*.pfx filter=git-crypt diff=git-crypt
```

### Add Your Staging Certificates

Place your self-signed files in `shared/traefik/advanced/selfsigncert/` matching the names in `shared/traefik/advanced/certificates.yml`, then commit normally:

```bash
cp /path/to/selfcert.pem    shared/traefik/advanced/selfsigncert/
cp /path/to/selfcert.key    shared/traefik/advanced/selfsigncert/
cp /path/to/selfcertCA.crt  shared/traefik/advanced/selfsigncert/
git add shared/traefik/advanced/selfsigncert/
git commit -m "add staging self-signed certificates (encrypted)"
```

git-crypt encrypts the files transparently on commit. Verify with:
```bash
# Should print non-text (encrypted) output — not your cert content
git show HEAD:shared/traefik/advanced/selfsigncert/selfcert.pem | file -
```

### Encode the Key for Forgejo Actions

The deploy workflow needs the key as a Forgejo Actions secret:

```bash
# Encode the binary key as base64 (single line, no trailing newline)
base64 -i servicehub.key | tr -d '\n'   # macOS / BSD
base64 -w0 servicehub.key               # Linux (GNU coreutils)
```

Copy the output into Forgejo → Repository → Settings → Actions → Secrets as **`GIT_CRYPT_KEY`**.

### Unlock on a New Machine

```bash
git-crypt unlock ./servicehub.key
```

---

## Deployment (Forgejo Actions)

The Forgejo Actions workflow at [.forgejo/workflows/61-deploy.yml](.forgejo/workflows/61-deploy.yml) provides a one-click deployment to staging or production over SSH. It is self-contained: inputs, secrets and variables are declared at the top and the deploy steps run inline. Jobs run in the stack's own Forgejo Actions runner (`devopsrunner`).

| Trigger | Behaviour |
|---|---|
| **Run workflow** button (workflow_dispatch) | Deploys a chosen **service** (`all` or a single compose service), to a chosen **environment** (`stag` or `prod`) from a chosen **branch** — the same inputs as the previous Gitea Actions workflow |

### How It Works

1. Selects the `STAG_*` or `PROD_*` secrets from the **environment** input, defaulting to staging
2. Configures SSH known hosts from a stored secret (or falls back to `ssh-keyscan`)
3. Checks out the chosen branch in the runner and decrypts git-crypt files (e.g. staging certs) in the checkout
4. Syncs the working tree to the deploy path with `rsync --delete` — the target keeps no `.git`, and repository-only files (`.git`, `.gitignore`, `.gitattributes`, `.forgejo/`, `AGENTS.md`, `docs/`) are excluded while `.env` and generated files are protected from deletion
5. Restores `.env` from the `*_B64ENC_ENVS` secret if the secret is newer than the existing file
6. Runs `scripts/setup.sh` to merge any new variables from `env.example` into `.env`
7. Restores `acme.json` from the `*_B64ENC_ACME` secret if the secret is newer than the existing file
8. Runs `docker compose up -d --build --no-deps <service>` on the remote (`all` expands to every non-foundational service in the ADR-009 OCI scope; `aiserv*` and `obsvce*` are never deployed by CI)

> **Deploy scope:** databases (`infra*`), Authentik (`infra*`), DevOps / Forgejo + runner (`devops*`) and Traefik (`route*`) are foundational and deployed manually — they are never selected, started or recreated by the workflow (deploying Forgejo would kill the runner mid-deploy). AI platform (`aiserv*`) and observability (`obsvce*`) services are outside the OCI deployment altogether per [ADR-009](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md): the AI platform runs on local infrastructure and the observability stack is retained in source control only. Traefik needs no restart when other services are deployed: its Docker provider watches the socket and picks up new containers/labels automatically.
>
> **Timestamp-based restore:** Both `.env` and `acme.json` are gzip-compressed before base64-encoding, which preserves the file's original mtime in the gzip header. On deploy, the workflow compares that mtime against the existing file on the server — the newer file always wins. This prevents a stale secret from overwriting a `.env` edited directly on the server or an `acme.json` renewed by Traefik since the last encode.

### Encoding Secrets for Forgejo Actions

Before triggering the workflow, encode your local `.env` and `acme.json` into Forgejo Actions secrets using the helper:

```bash
# For staging
bash scripts/setup.sh --encode STAG

# For production
bash scripts/setup.sh --encode PROD
```

The script outputs `.b64` files and prints instructions for copying their content into Forgejo Actions secrets.

### Required Actions Secrets and Variables

Stored workflow configuration lives in two separate stores, both under **Forgejo → Repository → Settings → Actions**. Use this table to decide where each item goes:

| Where | Used for | Items |
|---|---|---|
| **Secrets** (Settings → Actions → **Secrets**) | Credentials, private keys and encoded `.env` / `acme.json` — encrypted and masked in logs | `GIT_CRYPT_KEY`, every `STAG_*` / `PROD_*` entry below, and the `BACKUP_*` secrets |
| **Variables** (Settings → Actions → **Variables**) | Non-sensitive configuration — plaintext, readable by anyone with repository access | `STAG_CONFIG`, `PROD_CONFIG` |
| **Neither** — selected per run in the **Run Workflow** dialog | Per-deployment choices | `service`, `environment`, `branch` |

> **Working-tree deploys:** the deploy workflow checks out the repository in the runner and syncs the working tree over SSH with rsync. `SOURCECODE_PUBLIC_URL` and `SOURCECODE_DEPLOY_TOKEN` are no longer read by any workflow and can be removed from **Forgejo → Settings → Actions**.

#### Secrets (Settings → Actions → Secrets)

Set these in **Forgejo → Repository → Settings → Actions → Secrets**.

> Forgejo secrets are available to every workflow of the repository — no per-event enablement is needed. Create **all** secrets listed below; leave unused ones (e.g. `STAG_B64ENC_ACME` on staging) empty.

##### Shared (both environments)

| Secret | How to obtain | Description |
|---|---|---|
| `GIT_CRYPT_KEY` | `base64 -i servicehub.key \| tr -d '\n'` | Base64-encoded git-crypt symmetric key used to decrypt self-signed certificates in the runner checkout before the working tree is synced to the remote server. Generate with `git-crypt init && git-crypt export-key ./servicehub.key`. |
| `BACKUP_RESTIC_PASSWORD` | *(protected value; do not record)* | Restic repository password. Encrypts the repository content; required whenever Target 1 is enabled, and independent of the SSH private key. |
| `BACKUP_HOME_SSH_KEY` | *(protected private key; do not record)* | SSH private key that authenticates the connection to the Target 1 SFTP server. Does not encrypt the repository. Required whenever Target 1 is enabled. |
| `BACKUP_HOME_SSH_KNOWN_HOSTS` | *(verified SSH host keys; do not record)* | Target 1 host keys used for strict SSH host verification. Required whenever Target 1 is enabled. |
| `BACKUP_RCLONE_CONFIG` | *(protected Rclone configuration; do not record)* | Rclone configuration containing the Google Drive remote and credentials. Required whenever Target 2 is enabled. |

##### Staging (`STAG_*`)

| Secret | Example value | Description |
|---|---|---|
| `STAG_SERVER_PASS` | `••••••••` | SSH password for `server_user`. **Either this or `STAG_SERVER_KEY` must be set** — not both required. Ignored if `STAG_SERVER_KEY` is also set. |
| `STAG_SERVER_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | SSH private key for passwordless login. Alternative to `STAG_SERVER_PASS`. The matching public key must already be in `~/.ssh/authorized_keys` on the staging server. Use a passphrase-less key (the workflow runs non-interactively). Newlines are preserved as-is. |
| `STAG_B64ENC_ENVS` | *(output of `setup.sh --encode STAG`)* | Gzip+base64-encoded `.env` file. Restored on deploy only if the secret is newer than the existing `.env` on the server. |
| `STAG_B64ENC_ACME` | *(leave the value empty for staging)* | Gzip+base64-encoded `acme.json` (Let's Encrypt certificates). For staging, create the secret with an **empty value** — Traefik uses the self-signed cert from `shared/traefik/advanced/selfsigncert/` instead. |

##### Production (`PROD_*`)

| Secret | Example value | Description |
|---|---|---|
| `PROD_SERVER_PASS` | `••••••••` | SSH password for `server_user`. **Either this or `PROD_SERVER_KEY` must be set** — not both required. Ignored if `PROD_SERVER_KEY` is also set. |
| `PROD_SERVER_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | SSH private key for passwordless login. Alternative to `PROD_SERVER_PASS`. The matching public key must already be in `~/.ssh/authorized_keys` on the production server. Use a passphrase-less key (the workflow runs non-interactively). Newlines are preserved as-is. |
| `PROD_B64ENC_ENVS` | *(output of `setup.sh --encode PROD`)* | Gzip+base64-encoded production `.env`. Restored on deploy only if the secret is newer than the existing `.env` on the server. |
| `PROD_B64ENC_ACME` | *(output of `setup.sh --encode PROD`)* | Gzip+base64-encoded `acme.json` containing your Let's Encrypt certificates. Generated by `setup.sh --encode PROD` when `acme.json` is larger than 1 KB (i.e. after Traefik has issued real certificates). Restored only if the secret is newer than the existing file. |

#### Variables (Settings → Actions → Variables)

Set these in **Forgejo → Repository → Settings → Actions → Variables**. Variables are plaintext — anyone with repository read access can see them — so credentials stay in secrets.

##### Per-environment configuration (`${PREFIX}_CONFIG`)

All non-credential target settings live in **one JSON variable per environment** — `STAG_CONFIG` and `PROD_CONFIG` — instead of one value per key. Values may be strings or numbers; multi-line values (host keys) use `\n` escapes. Example:

```json
{
  "server_host": "203.0.113.10",
  "server_port": "2222",
  "server_user": "deploy",
  "deploy_path": "/srv/servicehub",
  "sshkwn_keys": "ssh-ed25519 AAAA... host\nssh-rsa BBBB... host",
  "backup_root": "/srv/backups/servicehub",
  "backup_exclude": "webapp/confluence/logs,devops/forgejo/workspace",
  "db_backup_retention_days": "14",
  "backup_local_full_retention_days": "90",
  "backup_restic_repository": "sftp:backup@home.example:/srv/restic/servicehub",
  "backup_restic_keep_within": "30d",
  "backup_rclone_destination": "gdrive:servicehub-backups",
  "backup_rclone_db_keep_age": "30d",
  "backup_rclone_full_keep_age": "90d"
}
```

The example enables both off-host targets. Remove a key (or leave it empty) to disable that target — see the key table below.

| Key | Required by | Description |
|---|---|---|
| `server_host` | all | Hostname or address of the **source server** — the host that receives deployments and that the backup workflow SSHes into to create and read archives. Not the address of an off-host backup target. |
| `server_port` | no | SSH port for the source server; defaults to `22`. Applies to every SSH use: deploy, connectivity test and backup transfers. This is unrelated to the port of the Restic/SFTP backup target, which is part of `backup_restic_repository`. |
| `server_user` | all | SSH login account. Needs Docker access and passwordless sudo — see [Prerequisites](#prerequisites). |
| `deploy_path` | all | Absolute path that receives the deployed working tree. Created on first deploy; no git metadata is kept there. |
| `sshkwn_keys` | no | The server's public SSH host key(s), verbatim `ssh-keyscan` output (use `ssh-keyscan -p <port> <host>` for a non-default port so entries use the `[host]:port` form). If unset, the workflows fall back to `ssh-keyscan` at runtime with a warning. |
| `backup_root` | backup | Directory **on the source server** where the archives are written before any transfer; `<YYYY>/<YYYYMM>` subdirectories are created automatically. The source server is the host running the services, Forgejo, and the Forgejo Actions runner — a homelab server or an Oracle Cloud VM instance. This is a source-side path, not a backup target. |
| `backup_exclude` | no | Comma-separated paths, relative to `APPS_DATA`, to exclude from the full archive. `*` and `?` globs are allowed; leave unset to archive everything. |
| `db_backup_retention_days` | backup | Required same-host retention for database archives under `backup_root`. |
| `backup_local_full_retention_days` | backup | Required same-host retention for full archives. |
| `backup_restic_repository` | no | Restic repository for **Target 1 (Home Server)**. Must start with `sftp:` and contain no whitespace. **Leave unset or empty to disable Target 1.** |
| `backup_restic_keep_within` | backup* | Restic snapshot retention applied after integrity checking. Required only when Target 1 is enabled. |
| `backup_rclone_destination` | no | Rclone destination for **Target 2 (Google Drive)**. Must include a configured remote (`remote:path`). **Leave unset or empty to disable Target 2.** |
| `backup_rclone_db_keep_age` | backup* | Rclone retention for database archives. Required only when Target 2 is enabled. |
| `backup_rclone_full_keep_age` | backup* | Rclone retention for full archives. Required only when Target 2 is enabled. |

\* Required only when the target it belongs to is enabled. An absent or empty target key disables that target, and every other setting and secret that only it uses is then ignored rather than validated. At least one of `backup_restic_repository` and `backup_rclone_destination` must be set — the workflow fails with `no off-host target is enabled` if both are missing. Same-host archives under `backup_root` are created on every run regardless of target selection.

To enable one target only, delete the other target's key from the JSON (do not leave a placeholder value — an empty string disables, a non-empty value must be well-formed).

**Non-standard SFTP port for Target 1.** Restic does not take a port in the `sftp:user@host:/path` form. Use its URL form instead, where the first slash separates the connection settings from the path and the second begins the path:

```json
"backup_restic_repository": "sftp://backup@backuphost:2222//srv/restic/servicehub"
```

A relative path (relative to the remote user's home) uses a single slash: `sftp://backup@backuphost:2222/srv/restic/servicehub`. The target can be any SFTP server reachable from the runner, including one on your local network. The alternative is an SSH configuration alias carrying `Port`, but the workflow generates the `~/.ssh/config` it uses, so the URL form is the one that needs no code change. The `sftp:` prefix is required in both forms.

**Authentication for Target 1.** Two independent credentials are required, and neither replaces the other:

| Credential | Secret | Protects |
|---|---|---|
| SSH private key | `BACKUP_HOME_SSH_KEY` | The SSH/SFTP connection to the target |
| Repository password | `BACKUP_RESTIC_PASSWORD` | The encrypted repository content — without it the stored snapshots cannot be read back |

> **Migration:** earlier releases used one secret per key (`STAG_SERVER_HOST`, `STAG_BACKUP_ROOT`, …). Add `STAG_CONFIG` / `PROD_CONFIG` as repository **variables** built from those values, run one workflow to confirm, then delete the obsolete secret rows. A missing required key fails fast with `${PREFIX}_CONFIG.<key> is not set`.

| Variable | Example value | Description |
|---|---|---|
| `STAG_CONFIG` | *(JSON; see the key table above)* | All non-credential staging settings as one JSON object. |
| `PROD_CONFIG` | *(JSON; see the key table above)* | All non-credential production settings as one JSON object. |

### Triggering a Deployment

1. Open the repository in Forgejo (`https://${SOURCECODE_DOMAIN}`) → **Actions**
2. Select the **deploy** workflow and click **Run workflow**
3. Set the inputs:
   - **service** — `all` (default) to deploy every app service, or one from the dropdown (`webappconf`, `webappocis`, `mailsvstalwart`, `mailsvbulwark`). Foundational services are not listed, and AI platform (`aiserv*`) and observability (`obsvce*`) services are outside the OCI deploy scope ([ADR-009](docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)) — see [Deploy scope](#how-it-works).
   - **environment** — `stag` (default) or `prod`
   - **branch** — branch to deploy (default `main`)
4. Click the green **Run workflow** button — progress and logs appear in the workflow run page

> Deployments are serialised: the workflow declares a `concurrency` group so two deploys never run at the same time, and a running deployment is never cancelled by a newer trigger.

### Data Backups (Forgejo Actions)

The `71-backup.yml` workflow runs on the existing `devopsrunner` with the `ssh-deploy` label, creates archives under the `backup_root` key of `${PREFIX}_CONFIG` **on the source server** (the host running the services, Forgejo, and the Actions runner — a homelab server or an Oracle Cloud VM instance), then copies each archive to the off-host targets that are enabled in the same JSON. Repository configuration exists; successful transfers and restores are not yet evidenced.

**Off-host targets.** Two independent copies are configured, both read from the source server — neither depends on the other:

| | Target | Enabled by | Disabled when |
|---|---|---|---|
| Target 1 | Home Server, Restic over SSH/SFTP | `backup_restic_repository` | key absent or empty |
| Target 2 | Google Drive, Rclone | `backup_rclone_destination` | key absent or empty |

Leave a key out to run only the other target; the workflow logs `Enabled off-host targets: restic=<0|1> rclone=<0|1>` before it creates any archive, and fails if both targets are disabled. The per-environment configuration key table above gives the SFTP port form and the authentication credentials.

**Database dumps (daily)** — one transaction-consistent `pg_dump` per PostgreSQL database (custom format, restored with `pg_restore`) plus a role-globals SQL dump, taken through the `infrapgsql` container while the services keep running, then packed into a single daily archive so each day has exactly one database backup file:

```
<BACKUP_ROOT>/<YYYY>/<YYYYMM>/<domain>-webapps-dbBK-<YYYYMMDD>.tar.gz
#  contents:
#    <domain>-dbBK-<db>-<YYYYMMDD>.dump   (one per database)
#    <domain>-dbBK-globals-<YYYYMMDD>.sql
```

The workflow deletes database archives older than the approved `db_backup_retention_days` value in `${PREFIX}_CONFIG` — only files matching `*-dbBK-*` are pruned, and empty `<YYYY>/<YYYYMM>` directories are removed too. The approved value is not recorded here.

**Full archive (weekly, Sunday)** — the whole persistent data volume, the `APPS_DATA` path read from the server's `.env`:

```
<BACKUP_ROOT>/<YYYY>/<YYYYMM>/<domain>-webapps-fullBK-<YYYYMMDD>.tar.gz
```

The full archive includes `${APPS_DATA}/webapp/ocis/config` and `${APPS_DATA}/webapp/ocis/data`. oCIS does not add a PostgreSQL dump; restore both filesystem paths together and follow [shared/owncloud/README.md](shared/owncloud/README.md#backup-and-recovery).

**Configuration archive (daily)** — the two files operators edit at runtime:

```
<BACKUP_ROOT>/<YYYY>/<YYYYMM>/<domain>-cfgBK-<YYYYMMDD>.tar.gz
#  contents (mode 600):
#    .env                    the merged environment: every variable and secret
#    egress-policies.conf    the egress allow/deny policy map
```

`.env` lives in the deploy path and is **never** in the full archive. `egress-policies.conf` lives in `${APPS_DATA}/shared/gateway/egress-policies.conf` (seeded there by `scripts/setup.sh`, which also moves a copy left at the older `${APPS_DATA}` root; see [egress controls](docs/operations/EGRESS-CONTROLS.md)), so the weekly full archive covers it as well — this daily archive just holds the recovery point to one day for both files. The archive is created on every run of the workflow and pruned with `*-cfgBK-*` on the same `db_backup_retention_days` value as the database archives; a file that is not present is skipped rather than failing the run. On restore, put `egress-policies.conf` back at `${APPS_DATA}/shared/gateway/egress-policies.conf` and `.env` at the deploy path root.

`<domain>` is the first label of `DOMAIN_NAME` from the server's `.env`, so backup names match the deployment. The workflow runs **daily at 02:30 server time** — database dumps every day, the full archive additionally on Sundays — and can also be started manually from **Actions → backup-data**: `environment` defaults to `prod`, and `backup` selects `auto` (daily db dumps, Sunday full archive), `db`, or `full`. All files are written to a `.part` file first and renamed only on success; they have mode `600`, readable only by the deploying SSH account and root, because the dumps contain mail and identity data, the full archive contains ACME private keys, and the configuration archive contains `.env` secrets. The workflow uses protected backup secrets and requires passwordless sudo — see [Prerequisites](#prerequisites).

Paths can be excluded from the **full archive** with the optional `backup_exclude` key in `STAG_CONFIG` / `PROD_CONFIG` — a comma-separated list relative to `APPS_DATA`, with `*` and `?` globs allowed. For example, to skip Confluence logs/caches and the runner workspace:

```
webapp/confluence/logs,webapp/confluence/temp,webapp/confluence/plugins-temp,devops/forgejo/workspace
```

A leading `./` or `/` is ignored; leave the secret unset to archive everything.

> **Consistency:** the weekly archive is taken while containers are running, so `infra/` inside it is crash-consistent rather than transaction-consistent — the daily `pg_dump` files are the transaction-consistent layer and the ones to restore from (worked example: [Stalwart — Database management](shared/stalwart/README.md#database-management-create--delete--backup--restore)). Backup and deployment jobs share the existing capacity-one runner, so long jobs queue behind one another.

---

## Usage

### Security baseline

Every inbound route is fronted by Traefik with the `secure-chain` middleware — security headers (HSTS, nosniff, referrer policy) and a per-client-IP rate limit (20 req/s, burst 50) — defined in [`shared/traefik/advanced/middlewares-security.yml`](shared/traefik/advanced/middlewares-security.yml) and documented in [Traefik — Security middlewares](shared/traefik/README.md#security-middlewares). Admin surfaces (Traefik dashboard, Stalwart admin) additionally carry IP allowlists built from `TRUSTED_IP` and Host rules built from `TRAEFIK_DOMAIN` / `EMAIL_HOST` / `IDENTITY_DOMAIN` (themselves `${DOMAIN_NAME}` references), generated into [`shared/traefik/advanced/admin-routers.yml`](shared/traefik/advanced/admin-routers.yml) and hot-reloaded by Traefik — edit `.env` (including `DOMAIN_NAME`), re-run `scripts/setup.sh`, no restart. Per-service hardening steps (Authentik MFA, Confluence anonymous access, Forgejo registration/OIDC, Stalwart auto-ban, Bulwark dashboard) live in each service's README under **Security hardening**.

### Start / Stop Services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart a single service
docker compose restart devopsforgejo

# View logs
docker compose logs -f devopsforgejo
```

### Rebuild After a Config Change

```bash
docker compose up -d --build devopsforgejo
```

### Update All Images

```bash
docker compose pull && docker compose up -d
```

---

## Configuration

All settings are controlled via `.env`. The template [`env.example`](env.example) documents every variable. Key sections:

> Services with a dedicated README ([Traefik](shared/traefik/README.md), [Authentik](shared/authentik/README.md), [MariaDB](shared/mariadb/README.md), [PostgreSQL](shared/postgresql/README.md), [Forgejo + Actions](shared/forgejo/README.md), [Confluence](shared/confluence/README.md), [oCIS](shared/owncloud/README.md), [Hermes Agent](shared/hermesagent/README.md), [LiteLLM](shared/litellm/README.md), [llama.cpp](shared/llamacpp/README.md), [Open WebUI](shared/openwebui/README.md), [VictoriaMetrics](shared/victoriametrics/README.md), [VictoriaLogs](shared/victorialogs/README.md), [Grafana](shared/grafana/README.md), [Stalwart](shared/stalwart/README.md), [Bulwark](shared/bulwark/README.md)) also document their own variables there.

### General

| Variable | Default | Description |
|---|---|---|
| `TIME_ZONE` | `Australia/Sydney` | Container timezone |
| `APPS_DATA` | `~/Documents/containerd` | Host path for all persistent data |

### Domain & Network

| Variable | Description |
|---|---|
| `DOMAIN_NAME` | Primary domain (e.g. `example.com`); the derived hosts (`TRAEFIK_DOMAIN`, `EMAIL_HOST`, `IDENTITY_DOMAIN`, …) reference it as `${DOMAIN_NAME}`, and re-running `scripts/setup.sh` after changing it regenerates `admin-routers.yml` with the new Host rules |
| `TRUSTED_IP` | CIDR ranges for forwarded-header trust and the admin allow lists (re-run `scripts/setup.sh` after changing to regenerate `admin-routers.yml`) |

### TLS / Traefik (route)

| Variable | Description |
|---|---|
| `TRAEFIK_DOMAIN` | Traefik dashboard hostname (default: `traefik.${DOMAIN_NAME}`); one of the hosts generated into `admin-routers.yml` |
| `TRAEFIK_ACMEMAIL` | Let's Encrypt registration email |
| `TRAEFIK_BAAUTH` | Dashboard basic-auth credentials (htpasswd format) |
| `CERTRESOLVER` | Set to `letsencrypt` for ACME; leave empty for self-signed |

### Authentik (infra)

| Variable | Description |
|---|---|
| `IDENTITY_TAG` | Authentik image tag (e.g. `2026.8`) |
| `IDENTITY_DOMAIN` | Authentik hostname (e.g. `login.example.com`) |
| `IDENTITY_DBNAME` | PostgreSQL database name for Authentik (default: `svchub_identity`) |
| `IDENTITY_PASSWORD` | Auto-generated by `setup.sh`; Authentik DB password |
| `IDENTITY_SECRET` | Auto-generated by `setup.sh`; Authentik secret key |

### Web Applications (webapp)

| Variable | Description |
|---|---|
| `WORKSPACE_DOMAIN` | Shared homepage hostname (default: `www.${DOMAIN_NAME}`); the apex is served as well |
| `WORKSPACE_DBNAME` | Workspace database name (default: `svchub_workspace`) |
| `WORKSPACE_TAG` | Confluence image tag (default: `10.2`) |
| `CLOUD_DOMAIN` | oCIS cloud-drive hostname (default: `drive.${DOMAIN_NAME}`) |
| `CLOUD_TAG` | Pinned oCIS image tag (default: `8.2.0`) |
| `CLOUD_OIDC_ISSUER` | Authentik OIDC issuer for the `ocis` application |
| `CLOUD_OIDC_CLIENT_ID` | Public Authentik OIDC client ID |
| `CLOUD_INSECURE` | `true` only when Authentik uses a self-signed certificate |

### AI Agent Platform (aiserv)

The agent platform variables are documented in the service READMEs — see [Hermes Agent](shared/hermesagent/README.md#configuration-in-env), [LiteLLM](shared/litellm/README.md#configuration) and [llama.cpp](shared/llamacpp/README.md#configuration). In short:

| Variable | Description |
|---|---|
| `CHAT_DOMAIN` | Open WebUI hostname (e.g. `chats.example.com`) |
| `HERMES_WORKSPACE_PASSWD_00` | Workspace web UI password (port 12320) |
| `HERMES_DATA_00` | Agent data directory (default `${APPS_DATA}/aiserv/hermes/00`) |
| `HERMES_WORKSPACE_DOMAIN_00` | Optional Traefik domain (empty = IP:port only) |
| `AIGATE_API_KEY` | LiteLLM master API key, shared by Hermes and other in-stack clients |
| `AIGATE_*` | LiteLLM proxy, admin UI and provider routing settings |
| `LLAMA_CHTMDL` / `LLAMA_CHTARG` / `HF_TOKEN` | llama.cpp model, server flags, HuggingFace token |

### Observability (obsvce)

| Variable | Description |
|---|---|
| `OBSERVABILITY_DOMAIN` | Grafana hostname (e.g. `stats.example.com`) |
| `OBSERVABILITY_ADMIN_USER` | Grafana admin username |
| `OBSERVABILITY_ADMIN_PASSWORD` | Grafana admin password |

### Databases

| Variable | Description |
|---|---|
| `DB_ADMIN_USER` | Shared DB username for both MariaDB and PostgreSQL |
| `DB_ADMIN_PASSWORD` | Auto-generated by `setup.sh`; store securely |
| `MARIADB_HOST` / `MARIADB_PORT` | MariaDB hostname / port (internal) |
| `POSTGRES_HOST` / `POSTGRES_PORT` | PostgreSQL hostname / port (internal) |
| `MARIADB_DATABASES` | Comma-separated MariaDB databases to initialize (default: `${WORKSPACE_DBNAME}`) |
| `POSTGRES_DATABASES` | Comma-separated PostgreSQL databases to initialize, including `${AIGATE_DBNAME}` |

For new installations:

```bash
MARIADB_DATABASES="${WORKSPACE_DBNAME}"
POSTGRES_DATABASES="${IDENTITY_DBNAME},${SOURCECODE_DBNAME},${AIGATE_DBNAME},${WORKSPACE_DBNAME},${POSTOFFICE_DBNAME}"
```

These lists only initialize empty database data directories. Preserve existing database names and passwords; create missing databases and grants explicitly on existing installations. See the [PostgreSQL](shared/postgresql/README.md) and [MariaDB](shared/mariadb/README.md) READMEs.

### Email (SMTP)

| Variable | Description |
|---|---|
| `EMAIL_HOST` | SMTP server hostname — also the Stalwart mail server hostname and its container hostname |
| `EMAIL_PORT` | SMTP port (465 by default, Stalwart's implicit-TLS submission port) |
| `EMAIL_USER` / `EMAIL_PASS` | SMTP credentials used by stack components to send mail through Stalwart |
| `EMAIL_FROM` | From address for outbound email (display name + address) |

### Email Services (mailsv)

The webmail variables are documented in the service READMEs — see [Bulwark](shared/bulwark/README.md#configuration-env) and [Stalwart](shared/stalwart/README.md#configuration-env). In short:

| Variable | Description |
|---|---|
| `POSTOFFICE_DOMAIN` | Bulwark hostname (must differ from `${EMAIL_HOST}`) |
| `WEBMAIL_SESSION_SECRET` | Session cookie encryption; auto-generated by `setup.sh` |
| `POSTOFFICE_DBNAME` | PostgreSQL database holding all Stalwart mail data (must be in `POSTGRES_DATABASES`) |
| `STALWART_ADMIN_USER` / `STALWART_ADMIN_PASS` | Stalwart recovery admin (`STALWART_RECOVERY_ADMIN`); pass auto-generated by `setup.sh`, empty disables |

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.
