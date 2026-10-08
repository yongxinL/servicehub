---
project: ServiceHub
project_code: SVCHUB
document_type: ARCHITECTURE
document_id: DEPLOYMENT-ARCHITECTURE
title: ServiceHub Deployment Architecture
version: "1.1"
status: Draft
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-08
tags:
  - servicehub
  - architecture
  - deployment
related_documents:
  - ARCHITECTURE
  - RUNBOOK
  - TEST-001
  - ADR-007
---

# ServiceHub Deployment Architecture

## Deployment Scope

[ADR-009](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) scopes what the deployment workflows deploy:

| Scope | Compose includes | Where it runs |
|---|---|---|
| OCI deployment | `route`, `infra`, `devops`, `webapp`, `mailsv` | Oracle Cloud Infrastructure |
| Local infrastructure | `aiserv` (Hermes, LiteLLM, llama.cpp, Open WebUI) | Local infrastructure; entrypoint for local deployment is an open follow-up |
| Retained, not deployed | `obsvce` (VictoriaMetrics, VictoriaLogs, Grafana Alloy, Grafana) | Not deployed to any environment; OCI workloads use Oracle Cloud native monitoring per [ADR-010](../adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md), which is not yet configured |

The root [docker-compose.yml](../../docker-compose.yml) include set and the `61-deploy.yml` workflow options both reflect this scope. The AI platform compose definition stays in source control so it can be started locally with `docker compose up -d`.


## Local Development or Administration Flow

The repository documents a local Compose flow:

1. Install prerequisites listed in the root README.
2. Run `bash scripts/setup.sh` to create or merge `.env`.
3. Review environment values without copying secret values into documentation.
4. Validate configuration with `docker compose config`.
5. Start selected services or the full stack using `docker compose up -d`.
6. Inspect health and logs before routing or deployment changes are considered valid.

This flow is Confirmed from repository commands; local execution results are `Not yet verified`.

## Staging Deployment

The deploy workflow accepts `environment: stag` and maps it to the `STAG_CONFIG` variable and `STAG_*` repository secrets. It SSHes to the configured target, syncs the working tree from the runner checkout, restores environment material when supplied, merges `env.example`, and deploys selected application services.

Staging TLS is described in repository documentation as self-signed when `CERTRESOLVER` is empty. The actual staging `.env`, certificate trust, DNS, and host state are secrets or runtime state and remain `Not yet verified`.

## Production Deployment

The deploy workflow accepts `environment: prod` and maps it to the `PROD_CONFIG` variable and the `PROD_*` repository secrets. It uses the same deployment logic as staging. Production-style TLS uses Let's Encrypt when `CERTRESOLVER=letsencrypt`.

The repository does not contain evidence that a production deployment, certificate issuance, or post-deploy validation succeeded.

## Runner Role

- `devopsrunner` runs Forgejo Actions jobs in host mode on the `ssh-deploy` label.
- Jobs execute inside the runner container, not in per-job containers.
- The shared runner has Git, git-crypt, OpenSSH, `sshpass`, `rsync`, Bash, jq, Rclone, and the PostgreSQL client.
- It reaches Forgejo internally for checkout when the internal server URL is used.
- All deployment, test, and backup jobs use capacity one, so long jobs queue behind one another.

## SSH Deployment Flow

1. Resolve the `${PREFIX}_CONFIG` repository variable (all non-credential settings, including the optional `server_port`, default 22) plus credential secrets, and validate required inputs.
2. Materialise an SSH key to a temporary `0600` file or use password authentication; both connect on the configured port.
3. Build an explicit known-host file from repository secrets, falling back to `ssh-keyscan` on the configured port with a warning.
4. Check out the selected branch in the runner and unlock git-crypt files when `GIT_CRYPT_KEY` is supplied.
5. Sync the working tree to the `deploy_path` of `${PREFIX}_CONFIG` with `rsync --delete`. Repository-only files (`.git`, `.gitignore`, `.gitattributes`, `.forgejo/`, `AGENTS.md`, `docs/`) are neither transferred nor kept; `.env`, generated admin rules, and `APPS_DATA` when it resolves inside the deploy path are protected from deletion. The target needs neither git nor git-crypt.
6. Restore `.env` only when the encoded secret is newer than the remote file.
7. Run `scripts/setup.sh` to merge new variables and regenerate the admin rules.
8. Restore `acme.json` only when the encoded secret is newer, to `${APPS_DATA}/shared/certs/acme.json` with root ownership and mode `600`.
9. Run `docker compose up -d --build --no-deps` for the selected application service or, for `all`, every non-foundational service in the ADR-009 OCI scope (`aiserv*` and `obsvce*` are excluded).

The workflow validates SSH and rsync availability and target inputs, but it does not perform post-deployment application checks.

## Backup Transfer Flow

The `Backup` workflow runs on the existing `devopsrunner`. It validates protected target and retention inputs, creates database and full-data archives on the target, applies same-host retention, copies archives to the Home Server over an Rclone SFTP remote, copies archives to Google Drive through an Rclone Crypt remote, compares each destination file with the source, and applies target retention.

The repository contains this configuration. Image build, target connectivity, successful transfers, integrity results, retention execution, and restores are `Not yet verified`.

## TLS Differences

| Mode | Repository mechanism | Evidence |
|---|---|---|
| Staging/self-signed | Empty `CERTRESOLVER`; files referenced by `shared/traefik/advanced/certificates.yml`; git-crypt protection | Configuration confirmed; trust and renewal unverified |
| Production/Let's Encrypt | `CERTRESOLVER=letsencrypt`; ACME TLS challenge; `${APPS_DATA}/shared/certs/acme.json` | Configuration confirmed; issuance and renewal unverified |

Stalwart shares the certificate store path and has ACME-related environment settings. DNS provider, propagation, rate limits, and certificate contents are not documented.

## Environment Handling

- `env.example` is the tracked variable template.
- `.env` is ignored and must contain environment-specific secret values.
- `scripts/setup.sh` creates missing `.env`, merges new keys, and can encode or decode deployment secrets; variable renames are applied manually.
- Forgejo repository variables carry the combined `${PREFIX}_CONFIG` JSON per environment; repository secrets carry credentials and encoded environment or certificate material.
- Repository documentation records variable names only.

## Rollback Model

No explicit rollback workflow or previous-version restoration procedure exists. A workflow can deploy another branch or service, but that is not a tested rollback model. Rollback requirements are `TBD`.

## Deployment Risks

- Password fallback and private-key fallback both depend on repository secrets.
- Falling back to `ssh-keyscan` weakens host verification when known-host secrets are absent.
- `rsync --delete` removes target files that are not in the working tree; `.env`, generated admin rules, and (when inside the deploy path) `APPS_DATA` are explicitly excluded.
- If the git-crypt unlock is skipped, encrypted certificates are synced as-is and Traefik's staging certificates fail.
- `--no-deps` prevents foundational dependency updates during application deploys but can leave incompatible foundations in place.
- Foundational services must be updated manually.
- Environment and ACME restoration uses newest-file-wins semantics.
- Passwordless sudo is required for certificate and backup operations.
- No health, route, login, database, metrics, or log verification runs after deployment.

## Items Requiring Validation

- SSH connectivity and host-key verification for both targets.
- Docker, Compose, sudo, deploy path, and `APPS_DATA` prerequisites.
- Git-crypt unlock success.
- Environment merge correctness without exposing values.
- Certificate permissions and trust.
- Compose build and dependency health.
- HTTP redirect and HTTPS routing.
- Rollback procedure and first governed release.

Use [TEST-001](../testing/TEST-001-platform-baseline-validation.md) as the baseline validation plan.
