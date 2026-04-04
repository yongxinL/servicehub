# ServiceHub

Welcome to ServiceHub! This project provides a collection of self-hosted services managed with Docker Compose. It is designed to be deployed on a single Docker host (like a NAS or home server) and supports two reverse proxy setups: Traefik for development and pfSense/HAProxy for production.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Core Services](#core-services)
- [Web Applications](#web-applications)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Deployment Workflows](#deployment-workflows)
- [Usage](#usage)
- [Configuration](#configuration)
- [Contributing](#contributing)

## Architecture Overview

The services are containerized using Docker and orchestrated with Docker Compose. The entire stack runs on a single Docker host (e.g., a NAS).

Network traffic can be managed in two ways:
- **Production (pfSense)**: A pfSense gateway handles reverse proxying (via HAProxy), SSL termination (via ACME), and Dynamic DNS. This is the recommended setup for a stable, production environment.
- **Development (Traefik)**: For local development and testing, a `trafik` service is included in the stack. It automatically handles reverse proxying and SSL provisioning based on Docker labels, simplifying setup.

### Port Forwarding
The following ports are exposed by the services. For a production setup, these ports would be the targets for your pfSense/HAProxy configuration. For a development setup with Traefik, only ports `80` and `443` need to be forwarded to the Docker host.

| Port | Protocol | Service             | Description                    |
|------|----------|---------------------|--------------------------------|
| 80/443 | TCP    | Traefik             | Reverse proxy (HTTP/HTTPS) — routes all web apps |
| 3306   | TCP    | `mariadb`           | MySQL Database                 |
| 5432   | TCP    | `pgsqldb`           | PostgreSQL Database             |
| 9000   | TCP    | `authentik`         | Authentik Web Interface        |
| Internal ports (accessed via Traefik domains):                          |
| 3000   | TCP    | `gitea`             | Git service (codex.*)          |
| 3000   | TCP    | `openmaic`          | Learning platform (learn.*)    |
| 80     | TCP    | `wordpress`         | CMS (www.*)                    |

## Project Structure

The repository is organized to keep service configurations modular and easy to manage.

```
.
├── compose/                # Individual docker-compose files for each service
│   ├── traefik.yml         # Reverse proxy with automatic HTTPS
│   ├── mariadb.yml         # MySQL/MariaDB database
│   ├── pgsqldb.yml         # PostgreSQL database
│   ├── authentik.yml       # SSO/Authentication
│   ├── gitea.yml           # Git repository hosting
│   ├── wordpress.yml       # CMS/Blog platform
│   └── openmaic.yml        # Multi-agent learning platform
├── shared/                 # Dockerfiles and shared configuration for custom images
│   ├── authentik/
│   ├── gitea/
│   ├── mariadb/
│   ├── openmaic/
│   ├── postgresql/
│   ├── traefik/
│   └── wordpress/
├── env.example             # Default environment variables for all services
└── docker-compose.yml      # Main compose file to orchestrate all services
```

## Core Services

These services form the foundation of the ServiceHub.

### 1. `mariadb` - MariaDB
- **Description**: A centralized MySQL/MariaDB database server for applications that require it.
- **Image**: `mariadb:latest`

### 2. `pgsqldb` - PostgreSQL
- **Description**: A centralized PostgreSQL database server for applications that require it.
- **Image**: `postgres:latest`

### 3. `authentik` - Authentik
- **Description**: Provides centralized authentication and identity management (SSO) for other applications.
- **Image**: `ghcr.io/goauthentik/server`
- **Port**: `9000`

## Web Applications

### 1. `gitea` - Gitea
- **Description**: A lightweight GitHub-like self-hosted Git service.
- **Image**: Custom image based on gitea/gitea
- **Notes**: Integrated with Authentik for SSO

### 2. `wordpress` - WordPress
- **Description**: A popular CMS for websites and blogs.
- **Image**: Custom image with nginx and php
- **Notes**: Database-backed, configurable via environment

### 3. `openmaic` - OpenMAIC
- **Description**: Open Multi-Agent Interactive Classroom (THU-MAIC/OpenMAIC).
- **Image**: Custom multi-stage Node.js build
- **Internal Port**: `3000`
- **Notes**: LLM-powered learning platform with OpenAI integration

## Prerequisites

1.  A server or NAS with Docker and Docker Compose installed.
2.  A pfSense firewall configured with the necessary port forwarding rules.
3.  A domain name.
4.  Dynamic DNS configured on pfSense to point your domain to your public IP.
5.  The `acme` package on pfSense to generate and renew SSL certificates.
6.  HAProxy on pfSense configured to route traffic to the services based on subdomains.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yongxinL/servicehub.git
    cd servicehub
    ```

2.  **Create `.gitignore`:**
    To prevent committing sensitive information, create a `.gitignore` file and add `.env` to it.
    ```bash
    echo ".env" > .gitignore
    git add .gitignore
    git commit -m "feat: Add .gitignore to exclude .env file"
    ```

3.  **Configure Environment Variables:**
    Run the interactive setup script. This will create a `.env` file in the project root and automatically generate the necessary secrets for you.
    ```bash
    bash scripts/setup.sh
    ```
    After the script runs, you should still review the generated `.env` file to customize any non-secret variables like `DOMAIN_NAME` or `APPS_DATA`.
    ```bash
    nano .env # or your favorite editor
    ```

4.  **Review Compose Files:**
    Check the main `docker-compose.yml` and the individual files in the `compose/` directory to ensure they meet your needs. Pay special attention to volume mounts and network configurations.

## Deployment Workflows

This project can be deployed manually or automatically using GitLab CI/CD.

### Automated Deployment with GitLab CI/CD

For automated deployments, secrets from the `.env` file must be managed securely within GitLab.

1.  **Store Secrets in GitLab:**
    *   In your GitLab project, navigate to **Settings > CI/CD**.
    *   Expand the **Variables** section.
    *   Add each variable from your local `.env` file as a project CI/CD variable.
    *   For sensitive values, select the **Mask variable** and **Protect variable** options.

2.  **CI/CD Pipeline Logic:**
    The `.gitlab-ci.yml` should be configured with a deployment job. This job will execute on a runner, connect to your Docker host, and run a script to:
    a. Pull the latest changes from the repository.
    b. Dynamically create the `.env` file on the host by echoing the CI/CD variables.
    c. Restart the Docker Compose services.

    This approach ensures that your secrets are never stored in the repository but are securely injected at deployment time.

### Manual Deployment to Docker Host

1.  **Transfer Project Files:**
    Copy the entire project directory to your Docker host using a tool like `scp` or `rsync`.

    Using `scp`:
    ```bash
    # Replace <user> and <docker-host-ip> with your actual credentials
    scp -r /path/to/local/servicehub <user>@<docker-host-ip>:/path/on/remote/host/
    ```

2.  **Connect to Docker Host:**
    SSH into your Docker host machine.
    ```bash
    ssh <user>@<docker-host-ip>
    cd /path/on/remote/host/servicehub
    ```

## Usage

### Starting a Single Service
To start a specific service (and its dependencies):
```bash
docker-compose up -d <service-name>
```
For example, to start WordPress: `docker-compose up -d wordpress`

### Restarting a Service
To restart a specific service:
```bash
docker-compose restart <service-name>
```
To restart a service and also rebuild its image:
```bash
docker-compose up -d --build <service-name>
```

### Starting All Services
To build any custom images and start all services in detached mode:
```bash
docker-compose up --build -d
```

### Stopping Services
To stop all running services:
```bash
docker-compose down
```

### Viewing Logs
To view the logs for all services:
```bash
docker-compose logs -f
```
To follow the logs for a specific service:
```bash
docker-compose logs -f <service-name>
```

## Configuration

All service-specific configurations are managed in their respective files within the `compose/` directory. Global settings, secrets, and domain names should be defined in the `.env` file.

The `shared/` directory is used for persistent data, custom configurations, or Dockerfiles needed to build custom images. Ensure the paths in your `.env` file and compose files point to the correct locations on your host machine.

## CI/CD Deployment with Gitea Actions

This project includes a [Gitea Actions workflow](.gitea/workflows/deploy.yml) for automated deployment to staging and production servers.

### Gitea Secrets

Configure these secrets in **Gitea → Repository → Settings → Actions → Secrets**:

| Secret | Required | Description |
|--------|----------|-------------|
| `STAG_SERVER_HOST` | Yes | Staging server IP address |
| `STAG_SERVER_USER` | Yes | SSH username for staging server |
| `STAG_SERVER_PASS` | Yes | SSH password for staging server |
| `STAG_DEPLOY_PATH` | Yes | Path where the repo is cloned on staging |
| `STAG_B64ENC_ENVS` | Yes | Base64-encoded `.env` for staging (see below) |
| `STAG_B64ENC_ACME` | Optional | Base64-encoded gzip-compressed `acme.json` for staging. Only needed when migrating active Let's Encrypt certs. Leave unset to use the self-signed certificate defined in `shared/traefik/advanced/certificates.yml`. |
| `PROD_SERVER_HOST` | Yes | Production server IP address |
| `PROD_SERVER_USER` | Yes | SSH username for production server |
| `PROD_SERVER_PASS` | Yes | SSH password for production server |
| `PROD_DEPLOY_PATH` | Yes | Path where the repo is cloned on production |
| `PROD_B64ENC_ENVS` | Yes | Base64-encoded `.env` for production (see below) |
| `PROD_B64ENC_ACME` | Optional | Base64-encoded gzip-compressed `acme.json` for production. Set this to carry over existing Let's Encrypt certificates. If unset, Traefik will request new certificates on first start. |

### TLS Certificate Behaviour by Environment

| Environment | `CERTRESOLVER` in `.env` | `*_B64ENC_ACME` secret | Result |
|-------------|--------------------------|------------------------|--------|
| STAG | *(empty)* | Not set | Traefik uses the self-signed cert from `certificates.yml` |
| STAG | *(empty)* | Set | Traefik uses the restored `acme.json` (no new requests) |
| PROD | `letsencrypt` | Not set | Traefik requests new Let's Encrypt certs on first start |
| PROD | `letsencrypt` | Set | Traefik uses the restored `acme.json` (renews as needed) |

### Encoding Secrets for Gitea

1. Ensure your `.env` file is configured correctly for the target environment:
   ```bash
   cp env.example .env
   # Edit .env — for STAG set CERTRESOLVER= (empty), for PROD set CERTRESOLVER=letsencrypt
   ```

2. Run the encode command for each environment:
   ```bash
   # For staging
   bash scripts/setup.sh --encode STAG

   # For production
   bash scripts/setup.sh --encode PROD
   ```

   This creates base64-encoded files:
   - `STAG_B64ENC_ENVS.b64` / `PROD_B64ENC_ENVS.b64` — always created from `.env`
   - `STAG_B64ENC_ACME.b64` / `PROD_B64ENC_ACME.b64` — only created when `shared/letsencrypt/acme.json` exists and is larger than 1 KB

3. Copy the file contents to Gitea secrets:
   ```bash
   # Copy to clipboard (Linux)
   cat STAG_B64ENC_ENVS.b64 | xclip -selection clipboard

   # Or display and copy manually
   cat STAG_B64ENC_ENVS.b64
   ```

4. Add the secrets in **Gitea → Repository → Settings → Actions → Secrets**:
   - `STAG_B64ENC_ENVS` ← content of `STAG_B64ENC_ENVS.b64`
   - `STAG_B64ENC_ACME` ← content of `STAG_B64ENC_ACME.b64` *(only if the file was generated)*
   - `PROD_B64ENC_ENVS` ← content of `PROD_B64ENC_ENVS.b64`
   - `PROD_B64ENC_ACME` ← content of `PROD_B64ENC_ACME.b64` *(only if the file was generated)*

### Gitea Runner Setup

The project includes a Gitea runner service (`gitrunner`) defined in [compose/gitea.yml](compose/gitea.yml).

To enable Actions on your Gitea instance:

1. Go to **Gitea → Repository → Settings → Actions → Runners**
2. Click **New Runner** and copy the token
3. Add the token to your `.env`:
   ```
   GIT_RUNNER_TOKEN=<your-runner-token>
   ```
4. Start the runner:
   ```bash
   docker-compose up -d gitrunner
   ```

### Triggering Deployments

Go to **Gitea → Repository → Actions**, select the workflow, and click **Run Workflow**:

- **service**: Choose which service to deploy (or `all`)
- **environment**: Choose `stag` or `prod`

### How Deployment Works

When a deployment is triggered, the workflow automatically:

1. SSHs into the target server
2. Pulls the latest code from Gitea
3. Runs `setup.sh` to merge any new variables from `env.example` into the existing `.env`
4. Decodes `STAG_B64ENC_ENVS` or `PROD_B64ENC_ENVS` from Gitea secrets → overwrites `.env`
5. If `STAG_B64ENC_ACME` or `PROD_B64ENC_ACME` is set, decodes and decompresses it → writes to `shared/letsencrypt/acme.json`. If the secret is unset, the existing `acme.json` on the server is left untouched and Traefik uses the self-signed certificate from `certificates.yml`.
6. Runs `docker-compose up --build -d [service]`

This means **deployment is fully automated** after initial setup. You only need to update Gitea secrets when:
- New environment variables are added to `env.example`
- Server credentials or passwords change
- You want to carry over renewed SSL certificates to a fresh server

### Updating Secrets

When secrets need to be updated (e.g., after adding new variables to `env.example`):

1. On your local machine, update your `.env` with new values
2. Re-encode for each environment:
   ```bash
   bash scripts/setup.sh --encode STAG
   bash scripts/setup.sh --encode PROD
   ```
3. Update the secrets in **Gitea → Repository → Settings → Actions → Secrets**
4. Trigger a new deployment

## Contributing
Contributions are welcome! Please feel free to submit a pull request or open an issue to discuss proposed changes.
