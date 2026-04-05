# Dockyard

> A quiet harbor where HomeLab services arrive, find their place, and don't get lost again

Dockyard is a self-hosted HomeLab services platform built on Docker Compose. It provides a curated stack of infrastructure and developer tools behind a single Traefik reverse proxy with automatic TLS — deployable to staging or production via a one-click Gitea Actions workflow.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Core Services](#core-services)
- [Web Applications](#web-applications)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Managing Encrypted Files (git-crypt)](#managing-encrypted-files-git-crypt)
- [Deployment Workflows](#deployment-workflows)
- [Usage](#usage)
- [Configuration](#configuration)

---

## Architecture Overview

All traffic enters through Traefik on ports 80/443. HTTP is redirected to HTTPS. Traefik routes requests to the appropriate service by hostname and terminates TLS using either Let's Encrypt (production) or a self-signed certificate (staging). All services communicate over an isolated Docker bridge network (`subnet`). Databases are not exposed outside the network.

```mermaid
graph TD
    Internet((Internet\n:80 / :443))
    Internet --> Traefik

    subgraph subnet[Docker Network: subnet]
        Traefik[Traefik\nReverse Proxy + TLS]
        Traefik -->|git.domain| Gitea[Gitea\nGit + Web UI]
        Traefik -->|traefik.domain| Dashboard[Traefik Dashboard]
        Gitea -->|depends on| PostgreSQL[(PostgreSQL\npgsqldb)]
        Gitea -->|triggers| Runner[Act Runner\nCI/CD Executor]
        MariaDB[(MariaDB)]
    end

    Runner -->|SSH deploy| RemoteServer[Remote Server\nStag / Prod]
```

**TLS strategy:**
- **Staging:** self-signed certificate via `shared/traefik/advanced/certificates.yml`
- **Production:** Let's Encrypt ACME challenge; `acme.json` restored from an encrypted Gitea secret

---

## Project Structure

```
servicehub/
├── .gitea/
│   └── workflows/
│       └── deploy.yml          # Gitea Actions deployment workflow
├── compose/                    # Per-service Docker Compose files
│   ├── traefik.yml             # Traefik reverse proxy
│   ├── gitea.yml               # Gitea + Act Runner
│   ├── mariadb.yml             # MariaDB database
│   └── pgsqldb.yml             # PostgreSQL database
├── shared/                     # Shared build contexts and static config
│   ├── traefik/
│   │   ├── Dockerfile
│   │   └── advanced/
│   │       └── certificates.yml  # Self-signed TLS config (staging)
│   ├── gitea/
│   │   ├── Dockerfile
│   │   ├── custom/             # Custom Gitea landing page assets
│   │   └── runner/
│   │       └── Dockerfile      # Act Runner image
│   ├── mariadb/
│   │   ├── Dockerfile
│   │   └── create-multiple-databases.sh
│   └── postgresql/
│       ├── Dockerfile
│       └── create-multiple-databases.sh
├── scripts/
│   └── setup.sh                # Local setup and secret encoding helper
├── docker-compose.yml          # Main entry point (includes all compose/ files)
├── env.example                 # Environment variable template
└── LICENSE
```

---

## Core Services

### Traefik (Reverse Proxy)

[Traefik v3](https://traefik.io/) is the single entry point for all web traffic.

| Detail | Value |
|---|---|
| HTTP port | 80 (redirects to HTTPS) |
| HTTPS port | 443 |
| Dashboard | `https://${TRAFIK_DOMAIN}` |
| TLS (prod) | Let's Encrypt via ACME |
| TLS (stag) | Self-signed from `shared/traefik/advanced/certificates.yml` |

Key behaviours:
- Automatic HTTP → HTTPS redirect for all services
- Docker provider: services opt in to routing via container labels
- Forward-auth and IP allowlist middleware stubs are in `compose/traefik.yml` (commented out) for easy activation

### MariaDB

[MariaDB 11.8](https://mariadb.org/) provides a MySQL-compatible relational database.

| Detail | Value |
|---|---|
| Internal port | 3306 (not exposed externally) |
| Multiple databases | Set `MARIADB_DB_LIST` (comma-separated) in `.env` |
| Data persistence | `${APPS_DATA}/databases/mariadb` |
| Health check | `innodb_initialized` every 10 s |

The init script `shared/mariadb/create-multiple-databases.sh` creates all databases listed in `MARIADB_DB_LIST` on first start.

### PostgreSQL

[PostgreSQL 16](https://www.postgresql.org/) is the primary relational database, used by Gitea.

| Detail | Value |
|---|---|
| Internal port | 5432 (not exposed externally) |
| Multiple databases | Set `PGRSQL_DBLIST` (comma-separated) in `.env` |
| Data persistence | `${APPS_DATA}/databases/pgsqldb` |
| Health check | `pg_isready` every 30 s (20 s startup delay) |

The init script `shared/postgresql/create-multiple-databases.sh` creates all databases listed in `PGRSQL_DBLIST` on first start.

---

## Web Applications

### Gitea

[Gitea](https://gitea.io/) is a self-hosted Git service with a GitHub-compatible web UI, issue tracker, and pull requests.

| Detail | Value |
|---|---|
| URL | `https://${GIT_DOMAIN}` |
| Database | PostgreSQL (`${GIT_DBNAME}`) |
| Data persistence | `${APPS_DATA}/webapps/repbuk/data` |
| Config persistence | `${APPS_DATA}/webapps/repbuk/config` |
| Volume ownership | **`1000:1000`** — required; Gitea runs rootless |
| Registration | Disabled (admin-only account creation) |
| Auth | Local accounts only (OpenID and passkeys disabled) |
| Default branch | `master` |
| Health check | HTTP GET on port 3000 every 30 s (20 s startup delay) |

### Gitea Act Runner

The Act Runner executes Gitea Actions workflows. It mounts the Docker socket so workflows can build and run containers.

| Detail | Value |
|---|---|
| Registration | Token set via `GIT_RUNNER_TOKEN` in `.env` |
| Instance URL | `https://${GIT_DOMAIN}` |
| Runner data | `${APPS_DATA}/webapps/repbuk/runner` |
| Labels | Inherit from Gitea runner registration |

> **Note:** The runner must be registered in Gitea (`Site Administration → Actions → Runners`) before the first workflow can execute. Set the registration token as `GIT_RUNNER_TOKEN` in your `.env`.

---

## Prerequisites

- **Docker** 24+ with the Compose plugin (`docker compose`) **or** the standalone `docker-compose` binary
- **Git** 2.x
- **git-crypt** (macOS: `brew install git-crypt`) — required to encrypt/decrypt self-signed certificates stored in the repo. The remote deploy server installs it automatically via the workflow.
- A domain name with DNS A records pointing to your server (for Let's Encrypt) **or** a local domain with a self-signed certificate (for staging)
- A Linux server with SSH access (for remote deployment)
- `openssl` (used by `setup.sh` to generate database passwords)

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yongxinL/servicehub.git
cd servicehub
```

### 2. Initial Setup

Run the setup script to create your `.env` from the template. It auto-generates a strong `SQLDB_PASS` and sets correct file permissions:

```bash
bash scripts/setup.sh
```

If `.env` already exists (e.g., after pulling updates), the script merges new variables from `env.example` without overwriting existing values.

### 3. Configure Environment Variables

Edit `.env` to match your environment:

```bash
# Required — set these before first start
DOMAIN_NAME=example.com        # Your primary domain
GIT_DOMAIN=git.example.com     # Gitea hostname
TRAFIK_DOMAIN=traefik.example.com
ACME_EMAIL=you@example.com     # Let's Encrypt registration email
APPS_DATA=/opt/containerd      # Host path for persistent data
TIME_ZONE=Australia/Sydney
```

See [Configuration](#configuration) for the full variable reference.

### 4. Prepare the Let's Encrypt Directory

The `shared/letsencrypt/` directory is already included in the repository. Traefik will create `acme.json` automatically on the first successful Let's Encrypt certificate issuance — you do not need to create it manually.

> **Important:** After Traefik starts and `acme.json` is created, verify its permissions are restricted. Traefik will refuse to use the file if permissions are too open:
> ```bash
> chmod 600 shared/letsencrypt/acme.json
> ```
> For remote deployments via the Gitea Actions workflow, `acme.json` is restored automatically from the `*_B64ENC_ACME` secret with the correct `600` permissions.

For staging (self-signed), place your `.pem` and `.key` files in `shared/letsencrypt/` and update `shared/traefik/advanced/certificates.yml` accordingly. No `acme.json` is needed.

### 5. Prepare the Gitea Data Directory

Gitea runs as a rootless container (UID/GID `1000:1000`). The data and config directories on the host **must** be owned by `1000:1000`, otherwise Gitea will fail to start or write data.

```bash
mkdir -p ${APPS_DATA}/webapps/repbuk/data
mkdir -p ${APPS_DATA}/webapps/repbuk/config
mkdir -p ${APPS_DATA}/webapps/repbuk/runner
chown -R 1000:1000 ${APPS_DATA}/webapps/repbuk
```

Replace `${APPS_DATA}` with the actual path you set in `.env` (e.g. `/opt/containerd`).

### 6. Start All Services

```bash
docker compose up -d
```

Or start a specific service:

```bash
docker compose up -d gitea
```

---

## Managing Encrypted Files (git-crypt)

Self-signed certificates for staging are stored **encrypted** in `shared/letsencrypt/` using [git-crypt](https://github.com/AGWA/git-crypt). They appear as binary blobs to anyone without the key, making it safe to commit them to a public repository. The deploy workflow decrypts them automatically on the remote server.

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

### Add Your Staging Certificates

Place your self-signed `.pem` and `.key` files in `shared/letsencrypt/` matching the filenames in `shared/traefik/advanced/certificates.yml`, then commit normally:

```bash
cp /path/to/selfcert.pem shared/letsencrypt/
cp /path/to/selfcert.key shared/letsencrypt/
cp /path/to/selfcertCA.crt shared/letsencrypt/
git add shared/letsencrypt/selfcert.pem shared/letsencrypt/selfcert.key shared/letsencrypt/selfcertCA.crt
git commit -m "add staging self-signed certificates (encrypted)"
```

git-crypt encrypts the files transparently on commit. Verify with:
```bash
# Should print non-text (encrypted) output — not your cert content
git show HEAD:shared/letsencrypt/selfcert.pem | file -
```

### Encode the Key for Gitea

The deploy workflow needs the key as a Gitea secret:

```bash
# Encode the binary key as base64
base64 -w0 servicehub.key
```

Copy the output into Gitea → Repository Settings → Secrets as **`GIT_CRYPT_KEY`**.

### Unlock on a New Machine

```bash
git-crypt unlock ./servicehub.key
```

---

## Deployment Workflows

The Gitea Actions workflow at [.gitea/workflows/deploy.yml](.gitea/workflows/deploy.yml) provides a manual, one-click deployment to staging or production over SSH.

### How It Works

1. Resolves environment-specific secrets from Gitea repository settings
2. Configures SSH known hosts from a stored secret (or falls back to `ssh-keyscan`)
3. On the remote server: clones the repo on first deploy, or pulls `main` on subsequent runs
4. Installs git-crypt on the remote server if needed, then decrypts encrypted files (e.g. staging certs)
5. Runs `scripts/setup.sh` to merge any new environment variables
6. Overlays `.env` from an encrypted Gitea secret (`*_B64ENC_ENVS`)
7. Restores `acme.json` from an encrypted Gitea secret (`*_B64ENC_ACME`) if provided
8. Runs `docker compose up --build -d [service]` on the remote

### Encoding Secrets for Gitea

Before triggering the workflow, encode your local `.env` and `acme.json` into Gitea secrets using the helper:

```bash
# For staging
bash scripts/setup.sh --encode STAG

# For production
bash scripts/setup.sh --encode PROD
```

The script outputs `.b64` files and prints instructions for copying their content into Gitea secrets.

### Required Gitea Secrets

Set these in **Repository Settings → Secrets**:

| Secret | Description |
|---|---|
| `STAG_SERVER_HOST` | Staging server IP or hostname |
| `STAG_SERVER_USER` | SSH username |
| `STAG_SERVER_PASS` | SSH password |
| `STAG_DEPLOY_PATH` | Absolute path on server (e.g. `/opt/servicehub`) |
| `STAG_B64ENC_ENVS` | Base64-encoded `.env` (from `setup.sh --encode STAG`) |
| `STAG_B64ENC_ACME` | Base64+gzip `acme.json` — leave **unset** for staging with self-signed certs |
| `STAG_SSHKWN_KEYS` | Output of `ssh-keyscan <stag-host>` — enables strict host verification (optional) |
| `GIT_CRYPT_KEY` | Base64-encoded git-crypt key (`base64 -w0 servicehub.key`) — shared across environments |
| `PROD_SERVER_HOST` | Production equivalents of all the above |
| `PROD_SERVER_USER` | |
| `PROD_SERVER_PASS` | |
| `PROD_DEPLOY_PATH` | |
| `PROD_B64ENC_ENVS` | |
| `PROD_B64ENC_ACME` | |
| `PROD_SSHKWN_KEYS` | Output of `ssh-keyscan <prod-host>` — enables strict host verification (optional) |

> `GITEA_TOKEN` is injected automatically by Gitea Actions — no manual setup needed.

### Triggering a Deployment

1. Navigate to **Repository → Actions → Deploy to Server**
2. Click **Run workflow**
3. Select the **service** (`all`, `gitea`, `mariadb`, `pgsqldb`, or `runner`) and **environment** (`stag` or `prod`)
4. Click **Run workflow**

---

## Usage

### Start / Stop Services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart a single service
docker compose restart gitea

# View logs
docker compose logs -f gitea
```

### Rebuild After a Config Change

```bash
docker compose up -d --build gitea
```

### Update All Images

```bash
docker compose pull && docker compose up -d
```

### Register the Act Runner

After Gitea starts, generate a runner token in Gitea (`Site Administration → Actions → Runners → Create new runner token`), add it to `.env` as `GIT_RUNNER_TOKEN`, then restart the runner:

```bash
docker compose restart runner
```

---

## Configuration

All settings are controlled via `.env`. The template [`env.example`](env.example) documents every variable. Key sections:

### General

| Variable | Default | Description |
|---|---|---|
| `TIME_ZONE` | `Australia/Sydney` | Container timezone |
| `APPS_DATA` | `~/Documents/containerd` | Host path for all persistent data |

### Domain & Network

| Variable | Description |
|---|---|
| `DOMAIN_NAME` | Primary domain (e.g. `example.com`) |
| `TRUSTED_IP` | CIDR ranges Traefik trusts for forwarded headers |

### TLS / Traefik

| Variable | Description |
|---|---|
| `TRAFIK_DOMAIN` | Traefik dashboard hostname |
| `ACME_EMAIL` | Let's Encrypt registration email |
| `TRAFIK_BAAUTH` | Dashboard basic-auth credentials (htpasswd format) |
| `CERTRESOLVER` | Set to `letsencrypt` for ACME; leave empty for self-signed |

### Gitea

| Variable | Description |
|---|---|
| `GIT_DOMAIN` | Gitea hostname |
| `GIT_DBNAME` | PostgreSQL database name for Gitea |
| `GIT_RUNNER_TOKEN` | Act Runner registration token |

### Databases

| Variable | Description |
|---|---|
| `SQLDB_USER` | Shared DB username for both MariaDB and PostgreSQL |
| `SQLDB_PASS` | Auto-generated by `setup.sh`; store securely |
| `MARIADB_DB_LIST` | Comma-separated list of MariaDB databases to create |
| `PGRSQL_DBLIST` | Comma-separated list of PostgreSQL databases to create |

### Email (SMTP)

| Variable | Description |
|---|---|
| `SMTP_HOST` | SMTP server hostname |
| `SMTP_PORT` | SMTP port |
| `SMTP_USER` / `SMTP_PASS` | SMTP credentials |
| `SMTP_FROM` | From address for outbound email |

---

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE) for details.
