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
| `GIT_CRYPT_KEY` | `base64 -i servicehub.key \| tr -d '\n'` | Base64-encoded git-crypt symmetric key used to decrypt self-signed certificates in the runner checkout before the working tree is synced to the remote server. Required: the deploy fails before any sync if it is missing or wrong. Generate with `git-crypt init && git-crypt export-key ./servicehub.key` (see [Managing Encrypted Files](development/DEVELOPMENT.md#managing-encrypted-files-git-crypt)). |
| `BACKUP_HOME_SSH_KEY` | *(protected private key; do not record)* | SSH private key that authenticates the connection to the Target 1 Home Server SFTP endpoint. Required whenever Target 1 is enabled. Use a passphrase-less key (the workflow runs non-interactively). Newlines are preserved as-is. |
| `BACKUP_HOME_SSH_KNOWN_HOSTS` | *(see [SSH host keys](#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts))* | Target 1 host keys used for strict SSH host verification — raw multi-line `ssh-keyscan` output. Required whenever Target 1 is enabled; no runtime fallback. |
| `BACKUP_RCLONE_CONFIG` | *(protected Rclone configuration; do not record)* | Rclone configuration containing the Google Drive remote and the Crypt remote that wraps it, with credentials. Required whenever Target 2 is enabled. |

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
  "backup_home_sftp": "backup@home.example:2222",
  "backup_home_destination": "/srv/backups/servicehub",
  "backup_home_db_keep_age": "30d",
  "backup_home_full_keep_age": "90d",
  "backup_rclone_destination": "gdrive-crypt:servicehub-backups",
  "backup_rclone_db_keep_age": "30d",
  "backup_rclone_full_keep_age": "90d"
}
```

The example enables both off-host backup targets. Remove a key (or leave it empty) to disable that target — see the [backup and restore](BACKUP-RESTORE.md) key table. Deploy-only environments can omit the `backup_*` keys entirely.

| Key | Required by | Description |
|---|---|---|
| `server_host` | all | Hostname or address of the **source server** — the host that receives deployments and that the backup workflow SSHes into to create and read archives. Not the address of an off-host backup target. Must be a DNS name or IPv4 address — IPv6 literals are not supported (consistent with `backup_home_sftp`). |
| `server_port` | no | SSH port for the source server; defaults to `22`. Applies to every SSH use: deploy and backup archive creation. This is unrelated to the Home Server SFTP endpoint, which is part of `backup_home_sftp`. |
| `server_user` | all | SSH login account. Needs Docker access and passwordless sudo — see [Prerequisites](../operations/INSTALLATION.md#prerequisites). |
| `deploy_path` | all | Absolute path that receives the deployed working tree. Created on first deploy; no git metadata is kept there. |
| `server_ssh_known_hosts` | all | The source server's public SSH host key(s), verbatim `ssh-keyscan -p <port> -H <host>` output — see [SSH host keys](#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts). **Required by both the backup and deploy workflows** (no runtime fallback, so host trust is deterministic). |
| `backup_root` | backup | Directory **on the source server** where the archives are written before any transfer; `<YYYY>/<YYYYMM>` subdirectories are created automatically. The source server is the host running the services, Forgejo, and the Forgejo Actions runner — a homelab server or an Oracle Cloud VM instance. This is a source-side path, not a backup target. |
| `backup_exclude` | no | Comma-separated paths, relative to `APPS_DATA`, to exclude from the full archive. `*` and `?` globs are allowed; leave unset to archive everything. |
| `db_backup_retention_days` | backup | Required same-host retention for database archives under `backup_root`. |
| `backup_local_full_retention_days` | backup | Required same-host retention for full archives. |
| `backup_home_sftp` | backup* | SFTP endpoint of **Target 1 (Home Server)** as `user@host` or `user@host:port`; the port defaults to `22` and must be `1`–`65535`. The host must be a DNS name or IPv4 address — IPv6 literals (including `user@[::1]:port`) are not supported. Required only when Target 1 is enabled. |
| `backup_home_destination` | no | Absolute path on the Home Server where archives are stored, under the same `<YYYY>/<YYYYMM>` hierarchy as `backup_root`. **Leave unset or empty to disable Target 1.** |
| `backup_home_db_keep_age` | backup* | Home Server retention for database and configuration archives. Required only when Target 1 is enabled. |
| `backup_home_full_keep_age` | backup* | Home Server retention for full archives. Required only when Target 1 is enabled. |
| `backup_rclone_destination` | no | Rclone destination for **Target 2 (Google Drive)**. Must include a configured remote (`remote:path`) and must point at a Crypt remote so archives are encrypted client-side — the workflow verifies the remote's type is `crypt` at run time and fails otherwise. **Leave unset or empty to disable Target 2.** |
| `backup_rclone_db_keep_age` | backup* | Google Drive retention for database archives. Required only when Target 2 is enabled. |
| `backup_rclone_full_keep_age` | backup* | Google Drive retention for full archives. Required only when Target 2 is enabled. |

\* Required only when the target it belongs to is enabled. An absent or empty target key disables that target, and every other setting and secret that only it uses is then ignored rather than validated. At least one of `backup_home_destination` and `backup_rclone_destination` must be set — the workflow fails with `no off-host target is enabled` if both are missing. Same-host archives under `backup_root` are created on every run regardless of target selection.

To enable one target only, delete the other target's key from the JSON (do not leave a placeholder value — an empty string disables, a non-empty value must be well-formed).

**Non-standard SFTP port for Target 1.** The port is part of the `backup_home_sftp` endpoint:

```json
"backup_home_sftp": "backup@backuphost:2222"
```

Omit the port (`user@host`) to use `22`. The target can be any SFTP server reachable from the runner, including one on your local network.

**Authentication for Target 1.** The Home Server connection uses two secrets, and both are required whenever Target 1 is enabled:

| Credential | Secret | Protects |
|---|---|---|
| SSH private key | `BACKUP_HOME_SSH_KEY` | The SSH/SFTP connection to the Home Server |
| Host keys | `BACKUP_HOME_SSH_KNOWN_HOSTS` | Strict host-key verification for that connection |

Archives on the Home Server are stored as plain `.tar.gz` files — the Home Server is treated as trusted storage. The Google Drive copy is encrypted client-side by the Crypt remote in `BACKUP_RCLONE_CONFIG`; its password and configuration are recovery material and must be preserved outside Google Drive.

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

**Authentication for Target 2.** Target 2 is enabled when `backup_rclone_destination` is non-empty. The workflow writes the secret body verbatim into a temporary Rclone config (`tr -d '\r'`; LF endings required, not CRLF) and refuses to start the transfer if the destination remote is missing or has any type other than `crypt`. Set the secret up before enabling the target, and store the **Crypt password** outside Google Drive — losing it makes the encrypted archive unreadable.

| Credential | Secret | Protects |
|---|---|---|
| Google Drive remote + Crypt overlay | `BACKUP_RCLONE_CONFIG` | The Google Drive OAuth/credentials and the `crypt` remote wrapping it |
| Crypt password (kept *outside* the secret) | recovery storage (password manager / printed in sealed envelope) | Required only to **decrypt**; without it, archived `.tar.gz` files are unreadable |

#### Target 2 — Google Drive setup (`BACKUP_RCLONE_CONFIG`)

The secret body is exactly what an `rclone.conf` would contain. The workflow consumes it as-is — do not redact, comment, or wrap it in JSON.

**Step 1 — install Rclone on a workstation.** Match the Rclone version that ships in `devopsrunner`. Use the same machine to keep the OAuth token and the crypt password with the operator who authorises them.

**Step 2 — create the Google Drive remote.** From a terminal with browser access:

```sh
rclone config
# n) New remote
# name> gdrive
# Storage> drive              (23 in the picker — Google Drive)
# client_id>                 (blank for a personal account, or your OAuth client_id)
# client_secret>             (blank for a personal account, or your OAuth client_secret)
# scope> 1                   (Full access; pick 2 for read-only)
# service_account_file>      (blank; OAuth flow authenticates interactively)
# Edit advanced config> n
# Use web browser> y
```

Verify with `rclone lsd gdrive:` — it should list folder names (`My Drive`, `Computers`, shared drives you have access to). For shared drives, switch to drive's `team_drive` / `shared_with_me` / `root_folder_id` during creation; verify with `rclone lsd gdrive:` again.

**Step 3 — create the Crypt remote over it.** Same `rclone config` session (or repeat on a second machine — both see the same final `rclone.conf`):

```text
n) New remote
name> gdrive-crypt
Storage> crypt                       (24 in the picker)
remote> gdrive:servicehub-backups    (path on Google Drive; colon = remote:path)
filename_encryption> 1               (standard; obfuscates file names)
directory_name_encryption> 1         (true; also encrypts folder names)
password> y, then type a strong password — Rclone stores only its obscured form
password2> g, 128 bits              (recommended salt; treat as recovery material too)
Edit advanced config> n
y) Yes this is OK
```

The password (and `password2` if used) are **recovery material in their own right**: Rclone stores their obscured forms in the config, but the obscured form is reversible, and the workflow only needs the obscured form to *upload*. To **decrypt** an archive during restore, the original password is required and Google Drive cannot supply it.

**Step 4 — record the password as recovery material.** Store the original Crypt password and `password2` in a credential store that is independent of Google Drive (password manager, sealed envelope, hardware token) and independent of the runner image. Do not commit it; do not paste it into `BACKUP_RCLONE_CONFIG`; do not store it in `${PREFIX}_CONFIG`. A checklist item in the runbook for the protected configuration is enough metadata.

**Step 5 — build `BACKUP_RCLONE_CONFIG`.** Export the config from the workstation. Either copy the file Rclone already manages, or ask it to print it:

```sh
# Option A — copy the on-disk file directly (simplest, byte-identical)
cp "$(rclone config file)" rclone.conf.body

# Option B — let Rclone print it; same content, same obscured passwords
rclone config show > rclone.conf.body
```

The body is exactly two `[remotes]` plus their options (token lives under `[gdrive]`, the obscured `password` / `password2` under `[gdrive-crypt]`). Example shape:

```ini
[gdrive]
type = drive
client_id =
client_secret =
scope = drive
token = {"access_token":"...","refresh_token":"...","expiry":"..."}

[gdrive-crypt]
type = crypt
remote = gdrive:servicehub-backups
filename_encryption = standard
directory_name_encryption = true
password = …obscured by Rclone…
password2 = …obscured by Rclone…
```

Workflow-created remotes use reserved `_workflow_*` names (`_workflow_source`, `_workflow_home`) so the names of remotes you define here cannot collide with them.

**Step 6 — pre-flight.** Verify the body works **before** pasting the secret:

```sh
rclone --config ./rclone.conf.body lsf gdrive-crypt:        # should be empty (or list any prior content)
rclone --config ./rclone.conf.body lsf gdrive:              # should list your Drive root
# Confirm the destination remote type the workflow will assert (uses `rclone config dump`,
# the same JSON form the workflow's `71-backup.yml:511` reads)
rclone --config ./rclone.conf.body config dump | \
  jq -r --arg r "gdrive-crypt" '(.remotes // .)[$r].type // "missing"'  # → crypt
```

If `lsf gdrive-crypt:` returns "directory not found", create the path with `rclone --config ./rclone.conf.body mkdir gdrive-crypt:servicehub-backups` so the workflow's first transfer does not need to create it.

**Step 7 — paste the value.** Forgejo → **Settings → Actions → Secrets**, name `BACKUP_RCLONE_CONFIG`, paste `rclone.conf.body` verbatim — preserve **real newlines** (the workflow normalises CRLF to LF, but the input should still be LF). Do not JSON-encode, base64-encode, quote, or wrap the body; Rclone would not parse it.

**Step 8 — enable the target.** Once `BACKUP_RCLONE_CONFIG` is set, set `backup_rclone_destination` in `${PREFIX}_CONFIG` to `gdrive-crypt:servicehub-backups` (or another subpath under `gdrive-crypt:`). The retention keys `backup_rclone_db_keep_age` and `backup_rclone_full_keep_age` are required whenever this target is enabled. The first backup run rejects the configuration with a clear error if any of these three pieces is missing.

> **Migration:** earlier releases used one secret per key (`STAG_SERVER_HOST`, `STAG_BACKUP_ROOT`, …). Add `STAG_CONFIG` / `PROD_CONFIG` as repository **variables** built from those values, run one workflow to confirm, then delete the obsolete secret rows. A missing required key fails fast with `${PREFIX}_CONFIG.<key> is not set`.

| Variable | Example value | Description |
|---|---|---|
| `STAG_CONFIG` | *(JSON; see the key table above)* | All non-credential staging settings as one JSON object. |
| `PROD_CONFIG` | *(JSON; see the key table above)* | All non-credential production settings as one JSON object. |

## Triggering a Deployment

1. Open the repository in Forgejo (`https://${SOURCECODE_DOMAIN}`) → **Actions**
2. Select the **Deploy** workflow and click **Run workflow**
3. Set the inputs:
   - **service** — `all` (default) to deploy every app service, or one from the dropdown (`webappconf`, `webappocis`, `mailsvstalwart`, `mailsvbulwark`). Foundational services are not listed, and AI platform (`aiserv*`) and observability (`obsvce*`) services are outside the OCI deploy scope ([ADR-009](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)) — see [How It Works](#how-it-works).
   - **environment** — `stag` (default) or `prod`
   - **branch** — branch to deploy (default `main`; production accepts only `main`)
4. Click the green **Run workflow** button — progress and logs appear in the workflow run page

> Deployments are serialised: the workflow declares a `concurrency` group so two deploys never run at the same time, and a running deployment is never cancelled by a newer trigger.

## Data Backups (Forgejo Actions)

The `71-backup.yml` workflow runs on the existing `devopsrunner` with the `ssh-deploy` label, creates archives under the `backup_root` key of `${PREFIX}_CONFIG` **on the source server** (the host running the services, Forgejo, and the Actions runner — a homelab server or an Oracle Cloud VM instance), then copies each archive to the off-host targets that are enabled in the same JSON. Repository configuration exists; successful transfers and restores are not yet evidenced.

**Off-host targets.** Two independent copies are configured, both read from the source server — neither depends on the other:

| | Target | Enabled by | Disabled when |
|---|---|---|---|
| Target 1 | Home Server, Rclone SFTP (plain archives) | `backup_home_destination` | key absent or empty |
| Target 2 | Google Drive, Rclone behind a Crypt remote (encrypted archives) | `backup_rclone_destination` | key absent or empty |

Leave a key out to run only the other target; the workflow logs `Enabled off-host targets: home=<0|1> gdrive=<0|1>` before it creates any archive, and fails if both targets are disabled. The per-environment configuration key table above gives the SFTP endpoint form and the authentication credentials.

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

The full archive includes `${APPS_DATA}/webapp/ocis/config` and `${APPS_DATA}/webapp/ocis/data`. oCIS does not add a PostgreSQL dump; restore both filesystem paths together and follow [oCIS — Backup and recovery](../products/owncloud.md#backup-and-recovery).

**Configuration archive (daily)** — the two files operators edit at runtime:

```
<BACKUP_ROOT>/<YYYY>/<YYYYMM>/<domain>-cfgBK-<YYYYMMDD>.tar.gz
#  contents (mode 600):
#    .env                    the merged environment: every variable and secret
#    egress-policies.conf    the egress allow/deny policy map
```

`.env` lives in the deploy path and is **never** in the full archive. `egress-policies.conf` lives in `${APPS_DATA}/shared/gateway/egress-policies.conf` (seeded there by `scripts/setup.sh`, which also moves a copy left at the older `${APPS_DATA}` root; see [egress controls](EGRESS-CONTROLS.md)), so the weekly full archive covers it as well — this daily archive just holds the recovery point to one day for both files. The archive is created on every run of the workflow and pruned with `*-cfgBK-*` on the same `db_backup_retention_days` value as the database archives; a file that is not present is skipped rather than failing the run. On restore, put `egress-policies.conf` back at `${APPS_DATA}/shared/gateway/egress-policies.conf` and `.env` at the deploy path root.

`<domain>` is the first label of `DOMAIN_NAME` from the server's `.env`, so backup names match the deployment. The workflow runs **daily at 02:30 server time** — database and configuration archives every day, the full archive additionally on Sundays — and can also be started manually from **Actions → Backup**: `environment` defaults to `prod`, and `backup` selects `auto` (daily DB/config + Sunday full), `db` (DB/config), or `full` (full/config) — the configuration archive is included in every mode. All files are written to a `.part` file first and renamed only on success; they have mode `600`, readable only by the deploying SSH account and root, because the dumps contain mail and identity data, the full archive contains ACME private keys, and the configuration archive contains `.env` secrets. The workflow uses protected backup secrets and requires passwordless sudo — see [Prerequisites](../operations/INSTALLATION.md#prerequisites). One authoritative archive per type is kept per day: a second run on the same day replaces that day's archive rather than adding one.

Paths can be excluded from the **full archive** with the optional `backup_exclude` key in `STAG_CONFIG` / `PROD_CONFIG` — a comma-separated list relative to `APPS_DATA`, with `*` and `?` globs allowed. For example, to skip Confluence logs/caches and the runner workspace:

```
webapp/confluence/logs,webapp/confluence/temp,webapp/confluence/plugins-temp,devops/forgejo/workspace
```

A leading `./` or `/` is ignored; leave the secret unset to archive everything.

> **Consistency:** the weekly archive is taken while containers are running, so `infra/` inside it is crash-consistent rather than transaction-consistent — the daily `pg_dump` files are the transaction-consistent layer and the ones to restore from (worked example: [Stalwart — Database management](../products/stalwart.md#database-management-create--delete--backup--restore)). Backup and deployment jobs share the existing capacity-one runner, so long jobs queue behind one another.

## Related

- Deployment scope, risks, and architecture model: [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md)
- Backup strategy, targets, and restore: [Backup and restore](BACKUP-RESTORE.md)
- Server-side prerequisites: [Installation](../operations/INSTALLATION.md)
