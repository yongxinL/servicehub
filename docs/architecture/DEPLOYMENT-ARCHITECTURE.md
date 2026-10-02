---
project: ServiceHub
project_code: SVCHUB
document_type: ARCHITECTURE
document_id: DEPLOYMENT-ARCHITECTURE
title: ServiceHub Deployment Architecture
version: "1.0"
status: Draft
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - architecture
  - deployment
related_documents:
  - ARCHITECTURE
  - RUNBOOK
  - TEST-001
---

# ServiceHub Deployment Architecture

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

The deploy workflow accepts `environment: stag` and maps it to `STAG_*` repository secrets. It SSHes to the configured target, updates the deployment checkout, restores environment material when supplied, merges `env.example`, and deploys selected application services.

Staging TLS is described in repository documentation as self-signed when `CERTRESOLVER` is empty. The actual staging `.env`, certificate trust, DNS, and host state are secrets or runtime state and remain `Not yet verified`.

## Production Deployment

The deploy workflow accepts `environment: prod` and maps it to `PROD_*` secrets. It uses the same deployment logic as staging. Production-style TLS uses Let's Encrypt when `CERTRESOLVER=letsencrypt`.

The repository does not contain evidence that a production deployment, certificate issuance, or post-deploy validation succeeded.

## Runner Role

- `depotrunner` runs Forgejo Actions jobs in host mode on the `ssh-deploy` label.
- Jobs execute inside the runner container, not in per-job containers.
- The runner has Git, OpenSSH, `sshpass`, and deployment tooling in its image.
- It reaches Forgejo internally for checkout when the internal server URL is used.
- Remote targets use the public Forgejo URL supplied by `DEPOT_PUBLIC_URL`.
- Backup and deployment workflows share the runner's single-capacity concurrency behaviour.

## SSH Deployment Flow

1. Resolve target secrets and validate required inputs.
2. Materialise an SSH key to a temporary `0600` file or use password authentication.
3. Build an explicit known-host file from repository secrets, falling back to `ssh-keyscan` with a warning.
4. Clone or pull the selected branch into `${PREFIX}_DEPLOY_PATH`.
5. Install and unlock git-crypt when `GIT_CRYPT_KEY` is supplied.
6. Restore `.env` only when the encoded secret is newer than the remote file.
7. Run `scripts/setup.sh` to merge new variables and generate missing placeholders.
8. Restore `acme.json` only when the encoded secret is newer, using root ownership and mode `600`.
9. Run `docker compose up -d --build --no-deps` for the selected application service or all non-foundational services.

The workflow validates SSH connectivity and repository inputs, but it does not perform post-deployment application checks.

## TLS Differences

| Mode | Repository mechanism | Evidence |
|---|---|---|
| Staging/self-signed | Empty `CERTRESOLVER`; files referenced by `shared/traefik/advanced/certificates.yml`; git-crypt protection | Configuration confirmed; trust and renewal unverified |
| Production/Let's Encrypt | `CERTRESOLVER=letsencrypt`; ACME TLS challenge; `${APPS_DATA}/certs/acme.json` | Configuration confirmed; issuance and renewal unverified |

Stalwart shares the certificate store path and has ACME-related environment settings. DNS provider, propagation, rate limits, and certificate contents are not documented.

## Environment Handling

- `env.example` is the tracked variable template.
- `.env` is ignored and must contain environment-specific secret values.
- `scripts/setup.sh` creates missing `.env`, merges new keys, migrates legacy names, and can encode or decode deployment secrets.
- Forgejo repository secrets carry target details and encoded environment or certificate material.
- Repository documentation records variable names only.

## Rollback Model

No explicit rollback workflow or previous-version restoration procedure exists. A workflow can deploy another branch or service, but that is not a tested rollback model. Rollback requirements are `TBD`.

## Deployment Risks

- Password fallback and private-key fallback both depend on repository secrets.
- Falling back to `ssh-keyscan` weakens host verification when known-host secrets are absent.
- An unauthenticated repository clone is allowed with a warning when the deploy token is absent.
- `git pull` can fail on local changes or non-fast-forward state.
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

