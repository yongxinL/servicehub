---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: DEPLOYMENT
title: ServiceHub Deployment (Forgejo Actions)
version: "1.1"
status: Active
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-09
updated: 2026-10-18
tags:
  - servicehub
  - operations
  - deployment
related_documents:
  - DEPLOYMENT-ARCHITECTURE
  - INSTALLATION
  - BACKUP-RESTORE
  - RUNBOOK
---

# ServiceHub Deployment (Forgejo Actions)

The Forgejo Actions workflow at [`61-deploy.yml`](../../../.forgejo/workflows/61-deploy.yml) provides a one-click deployment to staging or production over SSH. It is self-contained: inputs, secrets and variables are declared at the top and the deploy steps run inline. Jobs run in the stack's own Forgejo Actions runner (`devopsrunner`).

## Workflow Inputs

| Trigger | Behaviour |
|---|---|
| **Run workflow** button (workflow_dispatch) | Deploys a chosen **service** (`all` or a single compose service), to a chosen **environment** (`stag` or `prod`) from a chosen **branch** — the same inputs as the previous Gitea Actions workflow |

## How It Works

1. Selects the `STAG_*` or `PROD_*` secrets from the **environment** input, defaulting to staging
2. Configures SSH known hosts from the required `server_ssh_known_hosts` value (pinned keys, no runtime `ssh-keyscan` fallback)
3. Checks out the chosen branch in the runner (fully qualified `actions/checkout` URL) and decrypts git-crypt files (e.g. staging certs) in the checkout; a missing or wrong `GIT_CRYPT_KEY` aborts before any sync
4. Syncs the working tree to the deploy path with `rsync --delete` — the target keeps no `.git`, and repository-only files (`.git`, `.git-crypt`, `.gitignore`, `.gitattributes`, `.forgejo/`, `AGENTS.md`, `docs/`) are excluded while `.env` and generated files are protected from deletion
5. Restores `.env` from the `*_B64ENC_ENVS` secret only when `.env` is missing on the server (bootstrap-only; an existing file is never overwritten)
6. Runs `scripts/setup.sh` to merge any new variables from `env.example` into `.env`
7. On production only, restores `acme.json` from the `*_B64ENC_ACME` secret only when it is missing on the server (bootstrap-only)
8. Runs `docker compose up -d --build --no-deps <service>` on the remote (`all` expands to the fixed app allowlist — `webappconf`, `webappocis` — with `webappocisinit` first (mailsvstalwart/mailsvbulwark excluded; OCI blocks port 25); `aiserv*` is local-only and `obsvce*` is deployed manually)

> **Deploy scope:** databases (`infra*`), Authentik (`infra*`), DevOps / Forgejo + runner (`devops*`), Traefik (`route*`), and observability (`obsvce*`) are foundational/manual scope — they are never selected, started or recreated by the workflow (deploying Forgejo would kill the runner mid-deploy). The AI platform (`aiserv*`) runs on local infrastructure per [ADR-009](../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md); observability is restored to OCI scope by [ADR-010](../../architecture/adr/ADR-010-establish-servicehub-observability-platform.md) and remains a manual Phase 5 deployment decision. Traefik needs no restart when other services are deployed: its Docker provider watches the socket and picks up new containers/labels automatically.
>
> **Bootstrap-only restore:** `.env` and `acme.json` are restored from their secrets only when the file is missing on the server; an existing file is never overwritten. After the first deploy, `scripts/setup.sh` owns `.env` (it merges new `env.example` keys in place) and Traefik owns `acme.json` (it renews certificates in place), so neither needs a timestamp comparison to stay current.

## Encoding Secrets for Forgejo Actions

Before triggering the workflow, encode your local `.env` and `acme.json` into Forgejo Actions secrets using the helper:

```bash
# For staging
bash scripts/setup.sh --encode STAG

# For production
bash scripts/setup.sh --encode PROD
```

The script outputs `.b64` files and prints instructions for copying their content into Forgejo Actions secrets.

## Required Actions Secrets and Variables

Stored workflow configuration lives in two separate stores, both under **Forgejo → Repository → Settings → Actions**. Use this table to decide where each item goes:

| Where | Used for | Items |
|---|---|---|
| **Secrets** (Settings → Actions → **Secrets**) | Credentials, private keys and encoded `.env` / `acme.json` — encrypted and masked in logs | `GIT_CRYPT_KEY`, every `STAG_*` / `PROD_*` entry below, and the `BACKUP_*` secrets |
| **Variables** (Settings → Actions → **Variables**) | Non-sensitive configuration — plaintext, readable by anyone with repository access | `STAG_CONFIG`, `PROD_CONFIG` |
| **Neither** — selected per run in the **Run Workflow** dialog | Per-deployment choices | `service`, `environment`, `branch` |

> **Working-tree deploys:** the deploy workflow checks out the repository in the runner and syncs the working tree over SSH with rsync. `SOURCECODE_PUBLIC_URL` and `SOURCECODE_DEPLOY_TOKEN` are no longer used by the deploy workflow; they may be removed from Forgejo Actions settings.

## SSH Known Hosts

Both the deploy and backup workflows require `server_ssh_known_hosts` (in `${PREFIX}_CONFIG` JSON) and `BACKUP_HOME_SSH_KNOWN_HOSTS` (Forgejo Actions secret). The value is the output of `ssh-keyscan` with hashing (`-H`), one line per host key type, newlines escaped as `\n` for the JSON variable.

**Step 1 — scan the target host.** From a trusted machine with network access to the target:

```sh
# Example for non-standard port
ssh-keyscan -p 2222 -H 203.0.113.10 | grep -v '^#'
```

**What you get (hashed):**

- `-p <port>` is required for non-standard port: without it the output records port 22 only, and verification later fails against `[host]:port`. For port 22 you may omit `-p`.
- `-H` **hashes** the hostname, so each returned line looks like this:

  ```
  |1|4WoxzcmbyVvE8gkYs2PDB...=|...= ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
  |1|2ZK6YKYzqsO296AomkX20PAy...=|...= ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbWl...
  |1|ckmnzHGkDnqGR+d0r...=|...= ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ...
  ```

  This is expected. The bracketed form `[home.example]:2222 ssh-ed25519 AAAA...` only appears when `-H` is omitted; both forms are accepted, but prefer `-H` so hostnames are not stored in plaintext. There is no lowercase `-h` flag — hashing is `-H`.
- One line per host-key type the server offers; a typical server returns **three lines** (`ssh-rsa`, `ecdsa-sha2-nistp256`, `ssh-ed25519`).

**Step 2 — verify out of band.** `ssh-keyscan` trusts whatever answers the query, so compare against the key on the target itself, e.g. `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the Home Server, before trusting the scan.

**Step 3 — paste the value.**

- `BACKUP_HOME_SSH_KNOWN_HOSTS` (Forgejo → Settings → Actions → Secrets): copy **all three lines exactly as returned**, one per line, with real newlines — do not escape or reformat them. The secret should look like:

  ```
  |1|.......=|.......= ssh-rsa AAAA...
  |1|.......=|.......= ecdsa-sha2-nistp256 AAAA...
  |1|.......=|.......= ssh-ed25519 AAAA...
  ```

- `server_ssh_known_hosts` (`STAG_CONFIG`/`PROD_CONFIG` JSON variable): same output, but the variable is a single-line JSON value, so newlines are escaped as `\n`. Generate the ready-to-paste string instead of hand-editing:

  ```sh
  ssh-keyscan -p 2222 -H 203.0.113.10 | grep -v '^#' | jq -Rs .
  ```

  Paste the quoted result as the value: `"server_ssh_known_hosts": "|1|…=|…= ssh-rsa AAAA…\n|1|…=|…= ecdsa-sha2-nistp256 AAAA…\n|1|…=|…= ssh-ed25519 AAAA…"`. The workflow converts `\n` back to real lines with `jq` at run time. Host keys are public data (any SSH client receives them during the handshake), so storing them in the plaintext variable is safe — never store the host's *private* keys anywhere.

- `server_ssh_known_hosts` is **required by both the backup and deploy workflows** — they fail fast with `PROD_CONFIG.server_ssh_known_hosts is not set` rather than trusting whatever answers a scan at run time. `BACKUP_HOME_SSH_KNOWN_HOSTS` is **required** whenever Target 1 is enabled — there is no fallback, so an incomplete paste (e.g. only one or two of the three lines) fails fast rather than silently.

## Triggering a Deployment

1. Open the repository in Forgejo (`https://${SOURCECODE_DOMAIN}`) → **Actions**
2. Select the **Deploy** workflow and click **Run workflow**
3. Set the inputs:
   - **service** — `all` (default) to deploy every app service, or one from the dropdown (`webappconf`, `webappocis`) (mailsv excluded; OCI blocks port 25). Foundational and observability services are not listed; AI platform (`aiserv*`) is local-only per [ADR-009](../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) — see [How It Works](#how-it-works).
   - **environment** — `stag` (default) or `prod`
   - **branch** — branch to deploy (default `main`; production accepts only `main`)
4. Click the green **Run workflow** button — progress and logs appear in the workflow run page

> Deployments are serialised: the workflow declares a `concurrency` group so two deploys never run at the same time, and a running deployment is never cancelled by a newer trigger.

## Backup Schedule

The companion backup workflow ([`71-backup.yml`](../../../.forgejo/workflows/71-backup.yml)) runs **daily at 02:30 (`Australia/Sydney`)**: a configuration archive on every run, a database archive every `db_backup_interval_days` days (default 1, daily), and a full archive every `full_backup_interval_days` days (default 7, weekly) — set those keys in `${PREFIX}_CONFIG` to change the cadence without a commit. To pause it without changing any file, open **Actions → Backup**, select the workflow in the run list, and use the **⋮** menu → **Disable Workflow** (repository administrator); **Enable Workflow** in the same menu resumes it. To retime the daily trigger itself, edit `cron` / `timezone` under `on.schedule` in `.forgejo/workflows/71-backup.yml` **on the default branch** and push — Forgejo has no UI or API override for a cron expression. Full options: [Managing the schedule](BACKUP-RESTORE.md#managing-the-schedule-enable-disable-retime).

## Related

- Deployment scope, risks, and architecture model: [Deployment architecture](../../architecture/DEPLOYMENT-ARCHITECTURE.md)
- Backup workflow configuration (`BACKUP_*` secrets, `backup_*` keys, schedules, retention) and restore: [Backup and restore](BACKUP-RESTORE.md)
- Server-side prerequisites: [Installation](../INSTALLATION.md)
