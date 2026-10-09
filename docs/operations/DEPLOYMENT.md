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
updated: 2026-10-10
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

The Forgejo Actions workflow at [`61-deploy.yml`](../../.forgejo/workflows/61-deploy.yml) provides a one-click deployment to staging or production over SSH. It is self-contained: inputs, secrets and variables are declared at the top and the deploy steps run inline. Jobs run in the stack's own Forgejo Actions runner (`devopsrunner`).

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
8. Runs `docker compose up -d --build --no-deps <service>` on the remote (`all` expands to the fixed app allowlist — `webappconf`, `webappocis`, `mailsvstalwart`, `mailsvbulwark` — with `webappocisinit` first; `aiserv*` and `obsvce*` are never deployed by CI)

> **Deploy scope:** databases (`infra*`), Authentik (`infra*`), DevOps / Forgejo + runner (`devops*`) and Traefik (`route*`) are foundational and deployed manually — they are never selected, started or recreated by the workflow (deploying Forgejo would kill the runner mid-deploy). AI platform (`aiserv*`) and observability (`obsvce*`) services are outside the OCI deployment altogether per [ADR-009](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md): the AI platform runs on local infrastructure and the observability stack is retained in source control only. Traefik needs no restart when other services are deployed: its Docker provider watches the socket and picks up new containers/labels automatically.
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

> **Working-tree deploys:** the deploy workflow checks out the repository in the runner and syncs the working tree over SSH with rsync. `SOURCECODE_PUBLIC_URL` and `SOURCECODE_DEPLOY_TOKEN` are no longer read by any workflow and can be removed from **Forgejo → Settings → Actions**.

### Secrets (Settings → Actions → Secrets)

Set these in **Forgejo → Repository → Settings → Actions → Secrets**.

> Forgejo secrets are available to every workflow of the repository — no per-event enablement is needed. Create **all** secrets listed below; leave unused ones (e.g. `STAG_B64ENC_ACME` on staging) empty.

#### Shared (both environments)

| Secret | How to obtain | Description |
|---|---|---|
| `GIT_CRYPT_KEY` | `base64 -i servicehub.key \| tr -d '\n'` | Base64-encoded git-crypt symmetric key used to decrypt self-signed certificates in the runner checkout before the working tree is synced to the remote server. Required: the deploy fails before any sync if it is missing or wrong. Generate with `git-crypt init && git-crypt export-key ./servicehub.key` (see [Managing Encrypted Files](DEVELOPMENT.md#managing-encrypted-files-git-crypt)). |

> The three backup secrets — `BACKUP_HOME_SSH_KEY`, `BACKUP_HOME_SSH_KNOWN_HOSTS` and `BACKUP_RCLONE_CONFIG` — are set in the same store but belong to the backup workflow; they are documented under [Backup secrets](BACKUP-RESTORE.md#backup-secrets).

#### Staging (`STAG_*`)

| Secret | Example value | Description |
|---|---|---|
| `STAG_SERVER_PASS` | `••••••••` | SSH password for `server_user`. **Either this or `STAG_SERVER_KEY` must be set** — not both required. Ignored if `STAG_SERVER_KEY` is also set. |
| `STAG_SERVER_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | SSH private key for passwordless login. Alternative to `STAG_SERVER_PASS`. The matching public key must already be in `~/.ssh/authorized_keys` on the staging server. Use a passphrase-less key (the workflow runs non-interactively). Newlines are preserved as-is. |
| `STAG_B64ENC_ENVS` | *(output of `setup.sh --encode STAG`)* | Gzip+base64-encoded `.env` file. Restored on deploy only when `.env` is missing on the server (bootstrap-only). |
| `STAG_B64ENC_ACME` | *(leave the value empty for staging)* | Gzip+base64-encoded `acme.json` (Let's Encrypt certificates). For staging, create the secret with an **empty value** — Traefik uses the self-signed cert from `shared/traefik/advanced/selfsigncert/` instead. |

#### Production (`PROD_*`)

| Secret | Example value | Description |
|---|---|---|
| `PROD_SERVER_PASS` | `••••••••` | SSH password for `server_user`. **Either this or `PROD_SERVER_KEY` must be set** — not both required. Ignored if `PROD_SERVER_KEY` is also set. |
| `PROD_SERVER_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | SSH private key for passwordless login. Alternative to `PROD_SERVER_PASS`. The matching public key must already be in `~/.ssh/authorized_keys` on the production server. Use a passphrase-less key (the workflow runs non-interactively). Newlines are preserved as-is. |
| `PROD_B64ENC_ENVS` | *(output of `setup.sh --encode PROD`)* | Gzip+base64-encoded production `.env`. Restored on deploy only when `.env` is missing on the server (bootstrap-only). |
| `PROD_B64ENC_ACME` | *(output of `setup.sh --encode PROD`)* | Gzip+base64-encoded `acme.json` containing your Let's Encrypt certificates. Generated by `setup.sh --encode PROD` when `acme.json` is larger than 1 KB (i.e. after Traefik has issued real certificates). Restored only when `acme.json` is missing on the server (bootstrap-only, production). |

### Variables (Settings → Actions → Variables)

Set these in **Forgejo → Repository → Settings → Actions → Variables**. Variables are plaintext — anyone with repository read access can see them — so credentials stay in secrets.

#### Per-environment configuration (`${PREFIX}_CONFIG`)

All non-credential target settings live in **one JSON variable per environment** — `STAG_CONFIG` and `PROD_CONFIG` — instead of one value per key. Values may be strings or numbers; multi-line values (host keys) use `\n` escapes. Example:

```json
{
  "server_host": "203.0.113.10",
  "server_port": "2222",
  "server_user": "deploy",
  "deploy_path": "/srv/servicehub",
  "server_ssh_known_hosts": "ssh-ed25519 AAAA... host\nssh-rsa BBBB... host",
  "backup_root": "/srv/backups/servicehub",
  "backup_exclude": "webapp/confluence/logs,devops/forgejo/workspace",
  "db_backup_retention_days": "14",
  "backup_local_full_retention_days": "90",
  "db_backup_interval_days": "1",
  "full_backup_interval_days": "7",
  "backup_home_sftp": "backup@home.example:2222",
  "backup_home_destination": "/srv/backups/servicehub",
  "backup_home_db_keep_age": "30d",
  "backup_home_full_keep_age": "90d",
  "backup_rclone_destination": "gdrive-crypt:servicehub-backups",
  "backup_rclone_db_keep_age": "30d",
  "backup_rclone_full_keep_age": "90d"
}
```

The example also carries the `backup_*` keys of the [backup workflow](BACKUP-RESTORE.md#configuration-keys) — `backup_root`, `backup_exclude`, the retention values, the cadence intervals, and both off-host targets. Remove a `backup_*` key (or leave it empty) to disable that backup target, or omit the `backup_*` keys entirely: a deploy-only environment needs the five keys below and nothing else, and an environment that omits both off-host targets takes local-only backups under `backup_root`.

| Key | Required by | Description |
|---|---|---|
| `server_host` | all | Hostname or address of the **source server** — the host that receives deployments and that the backup workflow SSHes into to create and read archives. Not the address of an off-host backup target. Must be a DNS name or IPv4 address — IPv6 literals are not supported (consistent with `backup_home_sftp`). |
| `server_port` | no | SSH port for the source server; defaults to `22`. Applies to every SSH use: deploy and backup archive creation. This is unrelated to the Home Server SFTP endpoint, which is part of `backup_home_sftp`. |
| `server_user` | all | SSH login account. Needs Docker access and passwordless sudo — see [Prerequisites](../operations/INSTALLATION.md#prerequisites). |
| `deploy_path` | all | Absolute path that receives the deployed working tree. Created on first deploy; no git metadata is kept there. |
| `server_ssh_known_hosts` | all | The source server's public SSH host key(s), verbatim `ssh-keyscan -p <port> -H <host>` output — see [SSH host keys](#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts). **Required by both the backup and deploy workflows** (no runtime fallback, so host trust is deterministic). |

> **Migration:** earlier releases used one secret per key (`STAG_SERVER_HOST`, `STAG_BACKUP_ROOT`, …). Add `STAG_CONFIG` / `PROD_CONFIG` as repository **variables** built from those values, run one workflow to confirm, then delete the obsolete secret rows. A missing required key fails fast with `${PREFIX}_CONFIG.<key> is not set`.

| Variable | Example value | Description |
|---|---|---|
| `STAG_CONFIG` | *(JSON; see the key table above)* | All non-credential staging settings as one JSON object. |
| `PROD_CONFIG` | *(JSON; see the key table above)* | All non-credential production settings as one JSON object. |

#### SSH host keys (`server_ssh_known_hosts` and `BACKUP_HOME_SSH_KNOWN_HOSTS`)

Both values are the same kind of data: `ssh-keyscan` output for the host you are verifying — the **source server** for `server_ssh_known_hosts`, the **Home Server** for `BACKUP_HOME_SSH_KNOWN_HOSTS`.

**Step 1 — scan the host.** Run from any trusted machine, replacing the port and host with your values:

```sh
ssh-keyscan -p 2222 -H home.example
```

- The port flag is **`-p` (lowercase)** — there is no `-P`. It is required for any non-standard port: without it the output records port 22 only, and verification later fails against `[host]:port`. For port 22 you may omit `-p`.
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
   - **service** — `all` (default) to deploy every app service, or one from the dropdown (`webappconf`, `webappocis`, `mailsvstalwart`, `mailsvbulwark`). Foundational services are not listed, and AI platform (`aiserv*`) and observability (`obsvce*`) services are outside the OCI deploy scope ([ADR-009](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)) — see [How It Works](#how-it-works).
   - **environment** — `stag` (default) or `prod`
   - **branch** — branch to deploy (default `main`; production accepts only `main`)
4. Click the green **Run workflow** button — progress and logs appear in the workflow run page

> Deployments are serialised: the workflow declares a `concurrency` group so two deploys never run at the same time, and a running deployment is never cancelled by a newer trigger.

## Backup Schedule

The companion backup workflow ([`71-backup.yml`](../../.forgejo/workflows/71-backup.yml)) runs **daily at 02:30 (`Australia/Sydney`)**: a configuration archive on every run, a database archive every `db_backup_interval_days` days (default 1, daily), and a full archive every `full_backup_interval_days` days (default 7, weekly) — set those keys in `${PREFIX}_CONFIG` to change the cadence without a commit. To pause it without changing any file, open **Actions → Backup**, select the workflow in the run list, and use the **⋮** menu → **Disable Workflow** (repository administrator); **Enable Workflow** in the same menu resumes it. To retime the daily trigger itself, edit `cron` / `timezone` under `on.schedule` in `.forgejo/workflows/71-backup.yml` **on the default branch** and push — Forgejo has no UI or API override for a cron expression. Full options: [Managing the schedule](BACKUP-RESTORE.md#managing-the-schedule-enable-disable-retime).

## Related

- Deployment scope, risks, and architecture model: [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md)
- Backup workflow configuration (`BACKUP_*` secrets, `backup_*` keys, schedules, retention) and restore: [Backup and restore](BACKUP-RESTORE.md)
- Server-side prerequisites: [Installation](../operations/INSTALLATION.md)
