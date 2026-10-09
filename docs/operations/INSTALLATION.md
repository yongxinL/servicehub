---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: INSTALLATION
title: ServiceHub Installation
version: "1.1"
status: Active
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-09
updated: 2026-10-09
tags:
  - servicehub
  - operations
  - installation
related_documents:
  - RUNBOOK
  - DEPLOYMENT
  - SERVICE-INVENTORY
---

# ServiceHub Installation

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

## 1. Clone the Repository

```bash
git clone https://github.com/yongxinL/servicehub.git
cd servicehub
```

## 2. Initial Setup

Run the setup script to create your `.env` from the template. It auto-generates strong passwords and API keys for all services:

```bash
bash scripts/setup.sh
```

If `.env` already exists (e.g., after pulling updates), the script merges new variables from `env.example` without overwriting existing values. Variable renames are not migrated automatically — they are a manual one-time edit.

## 3. Configure Environment Variables

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

See [Configuration](#configuration) in the root [README](../../README.md) for the variable reference. For an existing installation, retain database names and credentials rather than copying new-install defaults.

## 4. Prepare TLS

For **production** (Let's Encrypt), Traefik creates `${APPS_DATA}/shared/certs/acme.json` automatically on the first successful certificate issuance — no manual step is needed. Verify its permissions are restricted after it is created (Traefik refuses to use a world-readable file):

```bash
chmod 600 ${APPS_DATA}/shared/certs/acme.json
```

For **staging** (self-signed), place your `.pem` and `.key` files in `shared/traefik/advanced/selfsigncert/` matching `shared/traefik/advanced/certificates.yml`. These are encrypted with git-crypt before committing — see [Managing Encrypted Files (git-crypt)](development/DEVELOPMENT.md#managing-encrypted-files-git-crypt). No `acme.json` is needed.

For remote deployments via the Forgejo Actions workflow (production only), `acme.json` is restored automatically from the `*_B64ENC_ACME` secret (gzip+base64 encoded via `setup.sh --encode`) with `install -m 600 -o root -g root`, so ownership and permissions are deterministic. The restore is bootstrap-only: it runs only when `acme.json` is missing on the server and never overwrites an existing file, so certificates issued or renewed by Traefik are always preserved.

## 5. Prepare Data Directories

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

Replace `${APPS_DATA}` with the actual path you set in `.env` (default: `~/Documents/containerd`). Homepage data lives under `${APPS_DATA}/webapp/confluence`; follow the [Confluence guide](../products/confluence.md) for directory ownership.

## 6. Start the Stack

Start the base services and the default homepage (Confluence).

```bash
docker compose up -d
```

Or start a specific service:

```bash
docker compose up -d devopsforgejo
```

## Next Steps

- Day-to-day operations: [Runbook](RUNBOOK.md)
- Remote deployment: [Deployment (Forgejo Actions)](DEPLOYMENT.md)
- Encrypted certificate material: [Managing Encrypted Files (git-crypt)](development/DEVELOPMENT.md#managing-encrypted-files-git-crypt)
