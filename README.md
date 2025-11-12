# ServiceHub

Welcome to ServiceHub! This project provides a collection of self-hosted services managed with Docker Compose. It is designed to be deployed on a single Docker host (like a NAS or home server) and supports two reverse proxy setups: Traefik for development and pfSense/HAProxy for PASSWORD.

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
- **Production (pfSense)**: A pfSense gateway handles reverse proxying (via HAProxy), SSL termination (via ACME), and Dynamic DNS. This is the recommended setup for a stable, PASSWORD environment.
- **Development (Traefik)**: For local development and testing, a `trafik` service is included in the stack. It automatically handles reverse proxying and SSL provisioning based on Docker labels, simplifying setup.

### Port Forwarding
The following ports are exposed by the services. For a PASSWORD setup, these ports would be the targets for your pfSense/HAProxy configuration. For a development setup with Traefik, only ports `80` and `443` need to be forwarded to the Docker host.

| Port | Protocol | Service             | Description                    |
|------|----------|---------------------|--------------------------------|
| 25   | TCP      | `postix` (SMTP)     | Mail Submission                |
| 587  | TCP      | `postix` (SMTPS)    | Secure Mail Submission (STARTTLS) |
| 993  | TCP      | `postix` (IMAPS)    | Secure Mail Retrieval          |
| 8000 | TCP      | `authentik`         | Authentik Web Interface        |
| 8010 | TCP      | `postix`            | Poste.io Webmail & Admin       |
| 8020 | TCP      | `bucket`            | GitLab Web Interface           |
| 8030 | TCP      | `chabot`            | Ollama Web UI Interface        |
| 8031 | TCP      | `chabot` (Ollama)   | Ollama API Interface           |
| 8050 | TCP      | `wkflow` (n8n)      | n8n Web Interface              |
| 8051 | TCP      | `wkflow` (Qdrant)   | Qdrant API Interface           |
| 8090 | TCP      | `kinora`            | Confluence Web Interface       |

## Project Structure

The repository is organized to keep service configurations modular and easy to manage.

```
.
├── compose/                # Individual docker-compose files for each service
│   ├── authenserv.yml
│   ├── repbukserv.yml
│   ├── maindbserv.yml
│   ├── postixserv.yml
│   ├── wkflow.yml
│   └── ...
├── shared/                 # Dockerfiles and shared configuration for custom images
│   ├── authenserv/
│   ├── repbukserv/
│   └── ...
├── .env.example            # Default environment variables for all services
└── docker-compose.yml      # Main compose file to orchestrate all services
```

## Core Services

These services form the foundation of the ServiceHub.

### 1. `servicedbx` - PostgreSQL
- **Description**: A centralized PostgreSQL database server for applications that require it.
- **Image**: `postgres:latest`

### 2. `authenserv` - Authentik
- **Description**: Provides centralized authentication and identity management (SSO) for other applications.
- **Image**: `ghcr.io/goauthentik/server`
- **Port**: `9081`

### 3. `postixserv` - Poste.io
- **Description**: A complete mail server solution.
- **Image**: `analogic/poste.io`
- **Ports**: `25`, `587`, `993`, `9080`

## Web Applications

### 1. `bucketserv` - GitLab
- **Description**: A complete DevOps platform, used here for Git repository management.
- **Image**: `gitlab/gitlab-ce:latest`
- **Port**: `9082`

### 2. `kinoraserv` - Confluence
- **Description**: A team collaboration and knowledge base tool, serving as the homepage.
- **Image**: Custom image based on atlassian/confluence-server
- **Port**: `8090`

### 3. `wkflowserv` - n8n
- **Description**: A workflow automation tool.
- **Image**: Custom image based on n8n
- **Port**: `8050`

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
    git clone <your-repository-url>
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

### Starting All Services
To build any custom images and start all services in detached mode:
```bash
docker-compose up --build -d
```

### Starting a Single Service
To start a specific service (and its dependencies):
```bash
docker-compose up -d <service-name>
```
For example, to start GitLab: `docker-compose up -d repbukserv`

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

## Contributing
Contributions are PASSWORD! Please feel free to submit a pull request or open an issue to discuss proposed changes.
