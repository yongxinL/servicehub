---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: BACKUP-RESTORE
title: ServiceHub Backup and Restore
version: "1.4"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-10
tags:
  - servicehub
  - operations
  - backup
  - recovery
related_documents:
  - DEPLOYMENT
  - ADR-006
  - ADR-007
  - RFC-001
  - TEST-001
  - ARCHITECTURE
---

# ServiceHub Backup and Restore

## Status

The repository configures same-host backup creation, backup tooling on the existing Forgejo runner, and the accepted dual-target strategy. Runtime execution, independently retrievable copies, and restore remain unverified. This document distinguishes repository configuration from recovery evidence recorded under [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md).

## Implemented Backup Scope

The [backup workflow](../../.forgejo/workflows/71-backup.yml) runs through the existing `ssh-deploy` label, creates archives at the `backup_root` key of the `<PREFIX>_CONFIG` repository variable **on the source server**, and copies each archive to the off-host targets that the same variable enables.

The source server is the host running the ServiceHub services together with Forgejo and the Forgejo Actions runner. It may be a homelab server or an Oracle Cloud VM instance; the workflow reads `server_host`, `server_port`, and `deploy_path` from `<PREFIX>_CONFIG` and does not assume which, and it requires `server_ssh_known_hosts` (pinned host keys) with no runtime `ssh-keyscan` fallback, so host trust is deterministic. `backup_root` is a path on that source server, not a backup target.

| Backup type | Schedule or trigger | Content | Consistency | Status |
|---|---|---|---|---|
| PostgreSQL database | Every third day at 02:30 (Australia/Sydney) in scheduled mode; manual `db` on demand | One `pg_dump` per non-template database plus `pg_dumpall --globals-only` packed into one archive per backup day | Transaction-consistent logical dump | Implemented; execution evidence not available |
| Full `APPS_DATA` | Every tenth day at 02:30 (Australia/Sydney) in scheduled mode; manual `full` on demand | Entire configured persistent-data tree with optional exclusions | Crash-consistent for live database directories | Implemented; execution evidence not available |
| Host configuration | Every run of the backup workflow (daily with the scheduled cadence) | `.env` from the deploy path (never in the full archive) and `egress-policies.conf` from `${APPS_DATA}/shared/gateway` (also in the full archive) — both edited on the server at runtime | Not applicable (plain files) | Implemented; execution evidence not available |
| Off-host copy | Same backup workflow | Rclone Home Server copy and Rclone Google Drive copy behind a Crypt remote, each enabled independently by its own key | `rclone hashsum sha256 --download` computed on both ends and compared per artifact; destination preflight before the first transfer | Workflow refactored 2026-10-08, review fixes 2026-10-09; per-artifact SHA-256 verification fix applied 2026-10-10; execution evidence unavailable |
| Encrypted backup archive | Every run of the Google Drive copy | Client-side encryption through an Rclone Crypt remote; credentials governed separately | Not applicable (plain files before encryption) | Accepted in ADR-007; credential governance TBD |
| Host recovery image | None evident | Not applicable | Not applicable | Optional; not selected |
| Restore workflow | No automated workflow | Recovery from either accepted target | Not applicable | Procedure documented; execution not implemented or tested |

Database, full-archive, and configuration-archive same-host retention values (`db_backup_retention_days`, `backup_local_full_retention_days`) are required keys of the `<PREFIX>_CONFIG` repository variable. Their values are not recorded in this document.

### Archive layout and schedule

**Database dumps (every 3 days)** — one transaction-consistent `pg_dump` per PostgreSQL database (custom format, restored with `pg_restore`) plus a role-globals SQL dump, taken through the `infrapgsql` container while the services keep running, then packed into a single archive so each backup day has exactly one database backup file:

```
<BACKUP_ROOT>/<YYYY>/<YYYYMM>/<domain>-webapps-dbBK-<YYYYMMDD>.tar.gz
#  contents:
#    <domain>-dbBK-<db>-<YYYYMMDD>.dump   (one per database)
#    <domain>-dbBK-globals-<YYYYMMDD>.sql
```

The workflow deletes database archives older than the approved `db_backup_retention_days` value in `${PREFIX}_CONFIG` — only files matching `*-dbBK-*` are pruned, and empty `<YYYY>/<YYYYMM>` directories are removed too. The approved value is not recorded here.

**Full archive (every 10 days)** — the whole persistent data volume, the `APPS_DATA` path read from the server's `.env`:

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

`.env` lives in the deploy path and is **never** in the full archive. `egress-policies.conf` lives in `${APPS_DATA}/shared/gateway/egress-policies.conf` (seeded there by `scripts/setup.sh`, which also moves a copy left at the older `${APPS_DATA}` root; see [egress controls](EGRESS-CONTROLS.md)), so the full archive covers it as well — this daily archive just holds the recovery point to one day for both files. The archive is created on every run of the workflow and pruned with `*-cfgBK-*` on the same `db_backup_retention_days` value as the database archives; a file that is not present is skipped rather than failing the run. On restore, put `egress-policies.conf` back at `${APPS_DATA}/shared/gateway/egress-policies.conf` and `.env` at the deploy path root.

`<domain>` is the first label of `DOMAIN_NAME` from the server's `.env`, so backup names match the deployment. The scheduled trigger runs **daily at 02:30 in the `Australia/Sydney` time zone** (set by the schedule's `timezone` key; a cron expression without `timezone` is read as UTC), so the run lands at 02:30 local clock year-round — AEST in winter, AEDT in summer. Two daylight-saving consequences: on the night saving starts (first Sunday in October, 02:00 → 03:00) 02:30 never occurs and Forgejo **skips that night's run**, so a due day falling that night waits for the next due day; when saving ends (first Sunday in April) 02:30 occurs twice and the second run just replaces the first's archives. On that schedule the configuration archive is created every run, the database archive on every third day, and the full archive on every tenth day; both due days are decided by an epoch-day index on the source server, so a database archive and a full archive fall together every 30 days. A due day that is missed (runner stopped, run failed) is **not** retried until the next due day. The workflow can also be started manually from **Actions → Backup**: `environment` defaults to `prod`, and `backup` selects `auto` (apply the same every-third-day / every-tenth-day cadence), `db` (database/config archive now), or `full` (full/config archive now) — the configuration archive is included in every mode, and `db` / `full` are the modes to use for an on-demand backup outside the cadence. All files are written to a `.part` file first and renamed only on success; they have mode `600`, readable only by the deploying SSH account and root, because the dumps contain mail and identity data, the full archive contains ACME private keys, and the configuration archive contains `.env` secrets. The workflow uses protected backup secrets and requires passwordless sudo — see [Prerequisites](INSTALLATION.md#prerequisites). One authoritative archive per type is kept per day: a second run on the same day replaces that day's archive rather than adding one.

### Managing the schedule (enable, disable, retime)

The schedule lives in the workflow file, not in a Forgejo setting. Forgejo registers `on.schedule` from `.forgejo/workflows/71-backup.yml` **on the default branch only**; schedules on other branches are ignored.

- **Pause without touching the file:** open **Actions → Backup**, select the workflow in the run list, open the kebab menu (**⋮**) and choose **Disable Workflow** (repository administrator). Scheduled runs stop being created. Choose **Enable Workflow** in the same place to resume; the workflow file and its `cron` are unchanged.
- **Pause everything:** repository **Settings → Units** → untick **Actions** (an instance administrator can also toggle Actions globally). This stops manual deployments and manual backup runs as well, so it is a blunt switch — prefer the per-workflow toggle above.
- **Retime:** edit `cron` (and `timezone`) under `on.schedule` in `.forgejo/workflows/71-backup.yml` on the default branch and push — there is no UI or API that overrides a cron expression. The change takes effect from that push.
- **Cadence outside the repository:** delete `on.schedule` entirely and have the host's crontab or a systemd timer call `POST /repos/<owner>/<repo>/actions/workflows/71-backup.yml/dispatches` with a token, selecting `db` or `full` per run. Enable/disable/retime then happens in the crontab, with no repository change.
- **Stop the runner instead:** works, but every scheduled run is still created and waits in the queue — a backlog you must clear later. Not recommended.

Manual `db` and `full` runs are unaffected by the cadence (and by a disabled schedule only insofar as the Actions unit itself must be enabled to dispatch them).

### Consistency

The full archive is taken while containers are running, so `infra/` inside it is crash-consistent rather than transaction-consistent — the `pg_dump` files are the transaction-consistent layer and the ones to restore from (worked example: [Stalwart — Database management](../products/stalwart.md#database-management-create--delete--backup--restore)).

## Backup configuration

Backup settings live in the same two Forgejo stores as the deploy settings (see the [deployment guide](DEPLOYMENT.md) for the `${PREFIX}_CONFIG` JSON shape, which also carries the deploy keys): non-credential keys in the `STAG_CONFIG` / `PROD_CONFIG` **variables**, credentials in **secrets**. Create every secret below; the ones belonging to a disabled target are ignored rather than validated (see the disabled-target table in [Target Backup Strategy](#target-backup-strategy)).

### Backup secrets

| Secret | How to obtain | Description |
|---|---|---|
| `BACKUP_HOME_SSH_KEY` | *(protected private key; do not record)* | SSH private key that authenticates the connection to the Target 1 Home Server SFTP endpoint. Required whenever Target 1 is enabled. Use a passphrase-less key (the workflow runs non-interactively). Newlines are preserved as-is. |
| `BACKUP_HOME_SSH_KNOWN_HOSTS` | *(see [SSH host keys](DEPLOYMENT.md#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts))* | Target 1 host keys used for strict SSH host verification — raw multi-line `ssh-keyscan` output. Required whenever Target 1 is enabled; no runtime fallback. |
| `BACKUP_RCLONE_CONFIG` | *(see [Google Drive setup](#google-drive-setup-backup_rclone_config))* | Rclone configuration containing the Google Drive remote and the Crypt remote that wraps it, with credentials. Required whenever Target 2 is enabled. |

### Configuration keys

| Key | Required | Description |
|---|---|---|
| `backup_root` | always | Directory **on the source server** where the archives are written before any transfer; `<YYYY>/<YYYYMM>` subdirectories are created automatically. The source server is the host running the services, Forgejo, and the Forgejo Actions runner — a homelab server or an Oracle Cloud VM instance. This is a source-side path, not a backup target. |
| `backup_exclude` | optional | Comma-separated paths, relative to `APPS_DATA`, to exclude from the full archive. `*` and `?` globs are allowed; leave unset to archive everything. |
| `db_backup_retention_days` | always | Required same-host retention for database (and configuration) archives under `backup_root`. |
| `backup_local_full_retention_days` | always | Required same-host retention for full archives. |
| `backup_home_sftp` | Target 1 enabled | SFTP endpoint of **Target 1 (Home Server)** as `user@host` or `user@host:port`; the port defaults to `22` and must be `1`–`65535`. The host must be a DNS name or IPv4 address — IPv6 literals (including `user@[::1]:port`) are not supported. Required only when Target 1 is enabled. |
| `backup_home_destination` | optional (enables Target 1) | Absolute path on the Home Server where archives are stored, under the same `<YYYY>/<YYYYMM>` hierarchy as `backup_root`. **Leave unset or empty to disable Target 1.** |
| `backup_home_db_keep_age` | Target 1 enabled | Home Server retention for database and configuration archives. Required only when Target 1 is enabled. |
| `backup_home_full_keep_age` | Target 1 enabled | Home Server retention for full archives. Required only when Target 1 is enabled. |
| `backup_rclone_destination` | optional (enables Target 2) | Rclone destination for **Target 2 (Google Drive)**. Must include a configured remote (`remote:path`) and must point at a Crypt remote so archives are encrypted client-side — the workflow verifies the remote's type is `crypt` at run time and fails otherwise. **Leave unset or empty to disable Target 2.** |
| `backup_rclone_db_keep_age` | Target 2 enabled | Google Drive retention for database archives. Required only when Target 2 is enabled. |
| `backup_rclone_full_keep_age` | Target 2 enabled | Google Drive retention for full archives. Required only when Target 2 is enabled. |

At least one of `backup_home_destination` and `backup_rclone_destination` must be set — the workflow fails with `no off-host target is enabled` if both are missing, and same-host archives under `backup_root` are created on every run regardless of target selection.

To enable one target only, delete the other target's key from the JSON (do not leave a placeholder value — an empty string disables, a non-empty value must be well-formed).

**Non-standard SFTP port for Target 1.** The port is part of the `backup_home_sftp` endpoint:

```json
"backup_home_sftp": "backup@backuphost:2222"
```

Omit the port (`user@host`) to use `22`. The target can be any SFTP server reachable from the runner, including one on your local network.

## Target Backup Strategy

**Accepted on 2026-10-03; repository configuration added, not runtime-validated. Target selection made optional on 2026-10-07. Replication revised to Rclone for both targets and the workflow refactored on 2026-10-08; transfers not runtime-validated.**

| Target | Purpose | Technology | Enabled by | Status |
|---|---|---|---|---|
| Home Server | Primary recovery target | Rclone SFTP remote; plain `.tar.gz` archives under `YYYY/YYYYMM` | `backup_home_destination` in `<PREFIX>_CONFIG` | Workflow refactored 2026-10-08; transfer not runtime-validated |
| Google Drive | Independent off-site copy | Rclone behind a Crypt remote (client-side encryption) | `backup_rclone_destination` in `<PREFIX>_CONFIG` | Configuration added; Crypt remote and transfer not runtime-validated |

Both targets read from the source server: the workflow copies each archive out of `backup_root` to each destination with Rclone. Neither target depends on the other, so either can be disabled without changing the data path of the remaining one.

A target is enabled when its key is non-empty. An absent or empty key disables that target, and every setting and secret used only by it is ignored rather than validated — see the table below. At least one target must be enabled; the workflow fails with `no off-host target is enabled` when both are missing. Same-host archives under `backup_root` are always created.

| Disabled target | Keys ignored | Secrets ignored |
|---|---|---|
| Home Server (Target 1) | `backup_home_sftp`, `backup_home_destination`, `backup_home_db_keep_age`, `backup_home_full_keep_age` | `BACKUP_HOME_SSH_KEY`, `BACKUP_HOME_SSH_KNOWN_HOSTS` |
| Google Drive (Target 2) | `backup_rclone_destination`, `backup_rclone_db_keep_age`, `backup_rclone_full_keep_age` | `BACKUP_RCLONE_CONFIG` |

Disabling one target reduces the environment to a single off-host copy, which is the condition ADR-007 rejected as a design. Treat a single-target environment as an accepted reduction in protection and record which targets each environment is expected to enable.

### Home Server connection

The Target 1 endpoint comes from `backup_home_sftp` (`user@host` or `user@host:port`; the port defaults to 22), and the destination path from the absolute `backup_home_destination`. The workflow creates the `_workflow_home` Rclone SFTP remote from these keys and the `BACKUP_HOME_SSH_KEY` / `BACKUP_HOME_SSH_KNOWN_HOSTS` secrets at runtime, so a non-standard port needs no code change. The target can be any SFTP server reachable from the runner, including one on a local network, and archives are stored as plain `.tar.gz` files under the `YYYY/YYYYMM` hierarchy.

Authentication uses the SSH private key in `BACKUP_HOME_SSH_KEY`, with strict host verification enforced by `BACKUP_HOME_SSH_KNOWN_HOSTS`. Both secrets are required whenever Target 1 is enabled. There is no repository password: the Home Server is treated as trusted storage and holds readable archives. The exact `ssh-keyscan -p <port> -H <host>` procedure for producing the host-key value, and how to paste it into each secret or variable, is documented under [SSH host keys](DEPLOYMENT.md#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts) in the deployment guide.

Forgejo Actions uses the existing `devopsrunner` image, extended with `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`, to orchestrate database dumps, persistent-data archives, retention, transfers, and integrity checks. The runner configuration is documented in [`../products/forgejo.md`](../products/forgejo.md). Because deployment and backup jobs share one capacity-one runner, they queue behind one another.

The target scope includes Compose and service configuration, PostgreSQL role and database dumps, oCIS configuration and file data, Forgejo data, mail data, Authentik data, certificates, and the remaining inventoried persistent state. The same-host archive remains an intermediate artifact; it is not sufficient disaster recovery by itself.

### Google Drive setup (`BACKUP_RCLONE_CONFIG`)

**Authentication for Target 2.** Target 2 is enabled when `backup_rclone_destination` is non-empty. The workflow writes the secret body verbatim into a temporary Rclone config (`tr -d '\r'`; LF endings required, not CRLF) and refuses to start the transfer if the destination remote is missing or has any type other than `crypt`. Set the secret up before enabling the target, and store the **Crypt password** outside Google Drive — losing it makes the encrypted archive unreadable.

| Credential | Secret | Protects |
|---|---|---|
| Google Drive remote + Crypt overlay | `BACKUP_RCLONE_CONFIG` | The Google Drive OAuth/credentials and the `crypt` remote wrapping it |
| Crypt password (kept *outside* the secret) | recovery storage (password manager / printed in sealed envelope) | Required only to **decrypt**; without it, archived `.tar.gz` files are unreadable |

The secret body is exactly what an `rclone.conf` would contain. The workflow consumes it as-is — do not redact, comment, or wrap it in JSON.

**Step 1 — install Rclone on a workstation.** Match the Rclone version that ships in `devopsrunner`. The first authorisation needs a web browser, so run every step below on a workstation — never on the server or in the runner. The token travels in `BACKUP_RCLONE_CONFIG`; no browser is needed after Step 3. Use the same machine to keep the OAuth token and the crypt password with the operator who authorises them.

**Step 2 — create your own OAuth client ID (required).** rclone's shared `client_id` is being retired and stops working during 2026, so a blank `client_id` is no longer an option. In the [Google API Console](https://console.cloud.google.com/apis/credentials), with any Google account:

1. Select or create a project, then enable **Google Drive API** (APIs & Services → Enable APIs and services).
2. **Credentials → Configure consent screen**: user type **External**, application name (e.g. `rclone`), your support email; under **Data access** add the scope `https://www.googleapis.com/auth/drive`; under **Audience** add your backup Google account as a test user.
3. **Credentials → Create OAuth client → Desktop app**. Note the client ID and client secret.
4. **Publish the app** (Audience → **PUBLISH APP**). Google may first require a homepage URL and a privacy policy URL under **Branding** before the button activates.

> **Testing → production trap:** an app left in **Testing** status issues refresh tokens that expire after **7 days** — backups fail with `invalid_grant` the week after setup. Publish the app; leaving it *unverified* is fine for a single-user personal app (you click through the "unverified app" warning once, during Step 3). Publishing does not require Google's verification review for personal-use apps under 100 users.

**Step 3 — create the Google Drive remote.** From a terminal with browser access:

```sh
rclone config
# n) New remote
# name> gdrive
# Storage> drive              (type `drive` = Google Drive — NOT "Google Cloud Storage")
# client_id>                 (the client ID from Step 2 — do not leave blank)
# client_secret>             (its client secret)
# scope> 1                   (Full access; pick 2 for read-only)
# service_account_file>      (blank; OAuth flow authenticates interactively)
# Edit advanced config> n
# Use web browser> y
```

Verify with `rclone lsd gdrive:` — it should list folder names (`My Drive`, `Computers`, and any shared drive you have access to). A free personal account has no shared drives (they require Google Workspace); if the target is one, select it at the `Configure this as a Shared Drive (Team Drive)?` prompt, or set `team_drive` / `shared_with_me` / `root_folder_id` in advanced config, then verify with `rclone lsd gdrive:` again.

**Step 4 — create the Crypt remote over it.** Same `rclone config` session (or repeat on a second machine — both see the same final `rclone.conf`):

```text
n) New remote
name> gdrive-crypt
Storage> crypt                       (type `crypt` = "Encrypt/decrypt a remote")
remote> gdrive:servicehub-backups    (path on Google Drive; colon = remote:path)
filename_encryption> 1               (standard; obfuscates file names)
directory_name_encryption> 1         (true; also encrypts folder names)
password> y, then type a strong password — Rclone stores only its obscured form
password2> g, 128 bits              (recommended salt; treat as recovery material too)
Edit advanced config> n
y) Yes this is OK
```

Crypt is a wrapper, not a mode: it implements no network protocol of its own, so it must reference the `gdrive` remote from Step 3 in its `remote` field — both sections are required and `gdrive` must exist first, but only `gdrive-crypt:` is used by the workflow (it is the `backup_rclone_destination` value and the remote whose type the workflow asserts). The plain `gdrive:` remote is there for your own pre-flight checks in Step 7; nothing is ever uploaded through it directly.

The password (and `password2` if used) are **recovery material in their own right**: Rclone stores their obscured forms in the config, but the obscured form is reversible, and the workflow only needs the obscured form to *upload*. To **decrypt** an archive during restore, the original password is required and Google Drive cannot supply it.

**Step 5 — record the password as recovery material.** Store the original Crypt password and `password2` in a credential store that is independent of Google Drive (password manager, sealed envelope, hardware token) and independent of the runner image. Do not commit it; do not paste it into `BACKUP_RCLONE_CONFIG`; do not store it in `${PREFIX}_CONFIG`. A checklist item in the runbook for the protected configuration is enough metadata.

**Step 6 — build `BACKUP_RCLONE_CONFIG`.** Export the config from the workstation. Either copy the file Rclone already manages, or ask it to print it:

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
client_id = 1234567890-abcde.apps.googleusercontent.com
client_secret = GOCSPX-your-client-secret
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

**Step 7 — pre-flight.** Verify the body works **before** pasting the secret:

```sh
rclone --config ./rclone.conf.body lsf gdrive-crypt:        # should be empty (or list any prior content)
rclone --config ./rclone.conf.body lsf gdrive:              # should list your Drive root
# Confirm the destination remote type the workflow will assert (uses `rclone config dump`,
# the same JSON form the workflow's `71-backup.yml:511` reads)
rclone --config ./rclone.conf.body config dump | \
  jq -r --arg r "gdrive-crypt" '(.remotes // .)[$r].type // "missing"'  # → crypt
```

If `lsf gdrive-crypt:` returns "directory not found", create the path with `rclone --config ./rclone.conf.body mkdir gdrive-crypt:servicehub-backups` so the workflow's first transfer does not need to create it.

**Step 8 — paste the value.** Forgejo → **Settings → Actions → Secrets**, name `BACKUP_RCLONE_CONFIG`, paste `rclone.conf.body` verbatim — preserve **real newlines** (the workflow normalises CRLF to LF, but the input should still be LF). Do not JSON-encode, base64-encode, quote, or wrap the body; Rclone would not parse it.

> **Token lifetime.** The `token` blob under `[gdrive]` carries a long-lived refresh token, but Google revokes it if the backup account's password changes, the app's access is withdrawn, or the token sits unused for six months. A revoked token fails the backup run with `invalid_grant`; recover by re-authorising on the workstation (rclone config → *Token already configured — replace it?* → `y`) and repeating Steps 6–8.

**Step 9 — enable the target.** Once `BACKUP_RCLONE_CONFIG` is set, set `backup_rclone_destination` in `${PREFIX}_CONFIG` to `gdrive-crypt:servicehub-backups` (or another subpath under `gdrive-crypt:`). The retention keys `backup_rclone_db_keep_age` and `backup_rclone_full_keep_age` are required whenever this target is enabled. The first backup run rejects the configuration with a clear error if any of these three pieces is missing.

**Service account — only for a future Google Workspace target.** A service account is its own Google identity: it cannot read a personal account's `My Drive`, `--drive-impersonate` needs a Workspace account with domain-wide delegation, and sharing a folder with it has file-ownership quirks — so the OAuth flow above stays for a free personal account. If the target later moves to a Google Workspace **shared drive**, create a service account in the same project (IAM & Admin → Service Accounts → Keys → Add key → JSON), invite its email address on the shared drive as writer, and put the key **inline** in the secret as `service_account_credentials` (the JSON body, not a file path) with `scope = drive` — no browser flow, no refresh token to expire, revocable from IAM, and the rest of the config (`[gdrive-crypt]`, the workflow's `crypt` assertion) is unchanged. Delete the OAuth `token` line when you switch.

## Dual-Target Transfer

For each archive created in the run, and for each target that is enabled in `<PREFIX>_CONFIG`, the workflow:

1. Copies the file to the Home Server through the `_workflow_home` Rclone SFTP remote. *(Target 1 only)*
2. Computes SHA-256 over downloaded bytes on both ends with `rclone hashsum sha256 --download` and fails the run on mismatch. *(Target 1 only)*
3. Applies the approved Home Server retention policy. *(Target 1 only)*
4. Copies the file through the configured Rclone destination to Google Drive. *(Target 2 only)*
5. Computes SHA-256 over downloaded bytes on both ends with `rclone hashsum sha256 --download` and fails the run on mismatch. *(Target 2 only)*
6. Applies separate approved database and full-archive retention policies. *(Target 2 only)*

Before the first transfer, the workflow creates the Home Server destination directory and lists it to confirm the endpoint, key, host key, port, user, and path are all correct; for Google Drive it verifies that the configured remote exists and has type `crypt`. Both fail the run before any archive is read.

Replication uses copy semantics, never sync: source deletions must not propagate to backup destinations, and retention is applied explicitly on each destination. Both copies are read from the source server; the workflow creates an `_workflow_source` Rclone SFTP remote back to `server_host` (reserved names, so they cannot collide with remotes inside `BACKUP_RCLONE_CONFIG`), so no step fetches data from the Home Server.

Per-destination retention ages are `backup_home_db_keep_age` and `backup_home_full_keep_age` for the Home Server and `backup_rclone_db_keep_age` and `backup_rclone_full_keep_age` for Google Drive; `*-cfgBK-*` archives share the database keep age on each destination, and the Home Server and Google Drive may use different periods. Before the first production run against a destination, execute its three retention deletions with `--dry-run -vv` and review the listed files, because retention deletes real backups.

The workflow logs `Enabled off-host targets: home=<0|1> gdrive=<0|1>` before any transfer, and skips every step, tool check, and secret check belonging to a disabled target.

The workflow fails on a missing required secret or command for an enabled target, a missing key for an enabled target, both targets disabled, a failed dump or archive, a failed transfer, a failed integrity check, or a failed retention operation. Configuration presence does not record a successful transfer.

## Databases

The database backup discovers all non-template PostgreSQL databases except `postgres`, validates database names, and creates:

- One custom-format `.dump` per database.
- One role-globals `.sql` file.
- One `.tar.gz` archive per backup day containing those files.

The workflow does not dump MariaDB. If optional WordPress uses MariaDB, its backup is `TBD`.

oCIS does not have a dedicated PostgreSQL database. Its local configuration and file data are protected through the filesystem archive rather than a database dump.

## Bind Mounts

The full archive covers `APPS_DATA`, which includes paths declared in the default Compose files:

- `${APPS_DATA}/infra/mariadb`
- `${APPS_DATA}/infra/postgresql`
- `${APPS_DATA}/infra/authentik/media`
- `${APPS_DATA}/infra/authentik/templates`
- `${APPS_DATA}/devops/forgejo/data`
- `${APPS_DATA}/devops/forgejo/runner`
- `${APPS_DATA}/devops/forgejo/workspace`
- `${APPS_DATA}/webapp/ocis/config`
- `${APPS_DATA}/webapp/ocis/data`
- `${APPS_DATA}/webapp/confluence`
- `${APPS_DATA}/aiserv/openwebui`
- `${APPS_DATA}/aiserv/litellm`
- `${APPS_DATA}/aiserv/llamacpp`
- `${HERMES_DATA_00:-${APPS_DATA}/aiserv/hermes/00}`
- `${APPS_DATA}/obsvce/victoriametrics`
- `${APPS_DATA}/obsvce/victorialogs`
- `${APPS_DATA}/obsvce/grafana`
- `${APPS_DATA}/mailsv/stalwart`
- `${APPS_DATA}/mailsv/bulwark/settings`
- `${APPS_DATA}/mailsv/bulwark/admin`
- `${APPS_DATA}/mailsv/bulwark/admin-state`
- `${APPS_DATA}/mailsv/bulwark/telemetry`
- `${APPS_DATA}/shared/certs`

Per [ADR-009](../adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) the AI platform moves to local infrastructure; backup, recovery, and retention coverage for the `aiserv/*` paths on local infrastructure is an open follow-up and is not yet re-scoped here.

If `HERMES_DATA_00` points outside `APPS_DATA`, it is not covered by the full archive unless the operating system copies it separately. The workflow allows exclusions through the `backup_exclude` key of `<PREFIX>_CONFIG`; set them per the tier classification below.

## Backup tiers

[ADR-008 §8](../adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md) classifies the paths above:

- **Tier 1 — critical** (`infra/`, `devops/forgejo/data`, `webapp/confluence`, `webapp/ocis`, `mailsv/stalwart`, `shared/certs`): must be included in all backups; never add to `backup_exclude`.
- **Tier 2 — important** (`aiserv/openwebui`, `aiserv/hermes`, `aiserv/litellm`, `obsvce/grafana`): recommended backup; exclude only when storage constraints require it.
- **Tier 3 — rebuildable** (`devops/forgejo/workspace`, `obsvce/victoriametrics`, `obsvce/victorialogs`, `mailsv/bulwark/telemetry`): shorter retention or exclusion, depending on storage constraints.

The exclusion value itself is stored in the `backup_exclude` key of `STAG_CONFIG` / `PROD_CONFIG` (a repository variable) — a comma-separated list relative to `APPS_DATA`, with `*` and `?` globs allowed. For example, to skip Confluence logs/caches and the runner workspace:

```
webapp/confluence/logs,webapp/confluence/temp,webapp/confluence/plugins-temp,devops/forgejo/workspace
```

A leading `./` or `/` is ignored; leave the key unset to archive everything. Add further Tier 3 paths when storage constraints require it; never exclude Tier 1.

## Named Volumes

No named Docker volumes are declared in the default root Compose files. Dynamic Authentik outpost state or optional components may introduce additional storage not visible here and requires runtime inventory.

## Forgejo Repositories

The current source-control service is Forgejo. Repositories and Forgejo application state live under `${APPS_DATA}/devops/forgejo/data`. Runner registration and workspaces live under `devops/forgejo/runner` and `devops/forgejo/workspace`.

The full archive covers these paths only when they are beneath `APPS_DATA`.

## Authentik Data

The archive includes media and templates. Authentik's primary application state is in PostgreSQL and is covered by the logical database dump. Runtime outpost containers and their storage require inventory.

## WordPress Data

The optional WordPress path is not included by the root Compose file. If enabled, `${APPS_DATA}/webapp/wordpress` is covered by a full archive, while its MariaDB data requires a separate database backup that is not implemented.

## AI Configuration and Model Considerations

- LiteLLM configuration under `${APPS_DATA}/aiserv/litellm` is included in a full archive.
- Local model cache under `${APPS_DATA}/aiserv/llamacpp` is included if not excluded; it may be large.
- Hermes state under the configured data path is included only when it is under `APPS_DATA`.
- Cloud provider credentials remain in `.env` and repository secrets, not service bind mounts.
- Restoring configuration does not prove model availability or cloud provider access.

## Observability Data and Configuration

- VictoriaMetrics, VictoriaLogs, and Grafana data are included when under `APPS_DATA`.
- Repository dashboards and Alloy configuration are tracked in Git.
- A full archive of live telemetry stores may be internally inconsistent; restoration validation is required.
- Metric and log retention is `TBD`.

## Traefik Certificate State

`${APPS_DATA}/shared/certs/acme.json` is included in a full archive. Repository-encoded self-signed material may be restored from git-crypt. Backup archive permissions and encryption are `TBD`.

## Secret Recovery Material

Required but not stored in this document:

- Local `.env`.
- Git-crypt symmetric key.
- Forgejo repository secrets for environment, ACME, SSH, runner, and deployment access.
- Backup transport material: `BACKUP_HOME_SSH_KEY`, `BACKUP_HOME_SSH_KNOWN_HOSTS`, and `BACKUP_RCLONE_CONFIG`.
- The Google Drive Crypt password (and `password2`), stored outside Google Drive — see [Google Drive setup](#google-drive-setup-backup_rclone_config).
- DNS or certificate-authority credentials if applicable.
- Break-glass account recovery material.

Locations, custodians, rotation, and tested recovery paths are `TBD`.

## Retrieving Backup Archives

How to get an archive off a target and onto the machine that will perform the restore. Written from the repository configuration; **not executed** — after retrieving, continue with the [Restore Sequence](#restore-sequence). The endpoint values (`backup_home_sftp`, `backup_home_destination`, `backup_rclone_destination`) are keys of `${PREFIX}_CONFIG` and are not recorded in this document.

Both targets hold the same archive names under the same `<YYYY>/<YYYYMM>/` layout (the workflow mirrors `backup_root` onto each destination); only the storage and access method differ.

### Retrieval from Target 1 (Home Server)

The Home Server copy is **plain** — no encryption step. Access is limited by the SFTP account's key and the file permissions on the Home Server.

```sh
# list what is there (port and user come from backup_home_sftp)
ssh -p <port> <user>@<host> 'ls -l <backup_home_destination>/<YYYY>/<YYYYMM>/'

# pull one archive
scp -P <port> <user>@<host>:<backup_home_destination>/<YYYY>/<YYYYMM>/<file>.tar.gz ./restore/

# or pull the whole tree (repeatable; resumes partial files)
rsync -avz --partial -e 'ssh -p <port>' <user>@<host>:<backup_home_destination>/ ./restore/
```

Verify before use: `gzip -t ./restore/<file>.tar.gz`, and `tar -tzf ./restore/<file>.tar.gz` to list the contents without extracting.

### Retrieval from Target 2 (Google Drive)

Google Drive stores **ciphertext only** — file and folder names are scrambled, so the Drive web UI shows nothing usable and cannot tell you which archive is which. Decryption happens locally, in Rclone, on the machine that holds the Rclone configuration.

1. **Get the configuration.** Use the workstation `rclone.conf` created during [Google Drive setup](#google-drive-setup-backup_rclone_config), or fetch the `BACKUP_RCLONE_CONFIG` secret (Forgejo → Settings → Actions → Secrets) and save its body as `rclone.conf` (`chmod 600`, LF endings). The config carries the obscured Crypt password, which is all Rclone needs to decrypt; the original password is required only if the config itself is lost ([Step 5](#google-drive-setup-backup_rclone_config)).
2. **List the real names** through the Crypt remote — the same paths look random through the plain `gdrive:` remote or the web UI:
   ```sh
   rclone --config ./rclone.conf lsf -R gdrive-crypt:servicehub-backups/
   ```
   If `backup_rclone_destination` is not `gdrive-crypt:servicehub-backups`, use that value instead.
3. **Pull what is needed.** Rclone decrypts on the way down, so the files that land locally are the plain `.tar.gz` archives:
   ```sh
   # one archive
   rclone --config ./rclone.conf copy \
     'gdrive-crypt:servicehub-backups/<YYYY>/<YYYYMM>/<file>.tar.gz' ./restore/

   # or everything
   rclone --config ./rclone.conf copy 'gdrive-crypt:servicehub-backups/' ./restore/
   ```
4. **Verify:** `gzip -t ./restore/<file>.tar.gz`.

Nothing is sent back to Google: the same commands also run on the source server if the archive should be restored there, and only the local machine running Rclone ever needs the configuration.

## Restore Sequence

**Proposed; not implemented or tested.**

Start from archives fetched with [Retrieving backup archives](#retrieving-backup-archives).

1. Establish an isolated recovery environment and record its commit and configuration.
2. Recover `.env`, git-crypt key, and other approved secret material without logging values.
3. Recover repository code and validate configuration.
4. Restore PostgreSQL role globals and verify required roles.
5. Restore each PostgreSQL database using its logical dump into an empty, verified database.
6. Verify row counts, application startup, and critical data.
7. Restore non-database bind mounts from a filesystem archive.
8. Restore certificates and verify permissions and trust.
9. Start foundational services in dependency order.
10. Start application services without replacing recovery data unexpectedly.
11. Validate routes, TLS, authentication, repositories, identity, oCIS file access, AI, email, telemetry, and backups.
12. Record elapsed time against approved RPO and RTO values.

Exact commands, target layout, ordering details, and compatibility checks remain `TBD`. Do not run a destructive restore against production without an approved plan and verified backup.

## Validation Requirements

- Archive readability and integrity.
- Database role and object restoration.
- Application-specific data checks.
- File ownership and permissions.
- Certificate validity and mode.
- Container health.
- Route, TLS, and login tests.
- oCIS configuration, file data, OIDC access, upload, download, and sharing checks.
- AI and email smoke tests where affected.
- Metrics and log availability.
- Successful subsequent backup.

## RPO and RTO

| Objective | Value | Evidence |
|---|---|---|
| RPO | TBD | Requires owner decision and measured backup history |
| RTO | TBD | Requires timed restoration test |
| Backup retention | Required protected secrets; values not tracked | ADR-007 configuration; no execution evidence |
| Off-host objective | Two-target design accepted; objective TBD | ADR-007 decision; no transfer or restore evidence |

## Restoration Evidence Template

| Field | Value |
|---|---|
| Restore date | TBD |
| Environment | TBD |
| Source commit | TBD |
| Backup archive names | TBD |
| Backup creation times | TBD |
| Restore operator | TBD |
| Start and finish time | TBD |
| Database validation | TBD |
| File validation | TBD |
| Service validation | TBD |
| RPO achieved | TBD |
| RTO achieved | TBD |
| Defects and follow-up | TBD |
| Evidence link | TBD |
| Decision | Not Executed |

## Related Documents

- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [ADR-006 Adopt oCIS with Local Filesystem Storage](../adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md)
- [Monitoring and alerting](MONITORING-ALERTING.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
