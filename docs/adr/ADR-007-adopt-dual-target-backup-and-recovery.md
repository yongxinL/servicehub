---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-007
title: Adopt Dual-Target Backup and Disaster Recovery
version: "1.1"
status: Accepted
decision_basis: Owner decision recorded on 2026-10-03 and runner consolidation revised on 2026-10-04; repository configuration added; target selection, source-host scope, non-standard SFTP port, and key-based authentication recorded on 2026-10-07; replication revised on 2026-10-08 to use Rclone for both targets and to place Google Drive behind an Rclone Crypt remote; runtime validation pending
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-03
updated: 2026-10-08
tags:
  - servicehub
  - architecture
  - backup
  - disaster-recovery
  - rclone
related_documents:
  - ADR-006
  - RFC-001
  - BACKUP-RESTORE
  - PHASE-004
  - TEST-001
  - ROADMAP-001
---

# ADR-007: Adopt Dual-Target Backup and Disaster Recovery

## Context

The repository implements daily PostgreSQL dumps and a weekly or on-demand `APPS_DATA` archive through Forgejo Actions. Those artifacts are written under a configured backup root on the target host, with configured Rclone transfers to both off-host targets. No successful off-site transfer or tested restore is recorded.

ServiceHub must be able to recover from VM loss, an Oracle Cloud outage, accidental deletion, data corruption, and configuration error. Protection must include service configuration, PostgreSQL databases, and persistent filesystem paths for oCIS, Forgejo, email, Authentik, and the other stateful services already in scope.

Recovery objectives are not yet approved or measured. The one-to-two-hour recovery estimate in the decision discussion is a planning estimate only; it is not an approved RTO or evidence of recovery capability.

### Backup artifacts

The workflow produces three archive types before any replication occurs, so each archive is already a self-contained recovery artifact:

- **Database backup (`dbBK`):** PostgreSQL database dumps and PostgreSQL global roles; created daily when database backup is enabled.
- **Configuration backup (`cfgBK`):** deployment `.env` and `egress-policies.conf` when present; created on every backup run.
- **Full backup (`fullBK`):** persistent application data under `APPS_DATA`; created weekly during automatic operation or manually on request.

Archives follow the existing date hierarchy under `backup_root`:

```text
<backup_root>/
└── YYYY/
    └── YYYYMM/
        ├── <domain>-webapps-dbBK-YYYYMMDD.tar.gz
        ├── <domain>-cfgBK-YYYYMMDD.tar.gz
        └── <domain>-webapps-fullBK-YYYYMMDD.tar.gz
```

## Decision

Use Forgejo Actions to create database dumps and self-contained persistent-data archives, then copy each protected backup set to two destinations with Rclone:

1. **Home Server:** primary recovery target using an Rclone SFTP remote. The original `.tar.gz` archives are stored directly under the existing `YYYY/YYYYMM` hierarchy, so recovery is locate, copy, extract, restore — with no repository reconstruction.
2. **Google Drive:** independent off-site recovery copy using Rclone behind a Crypt remote, so archives are encrypted client-side before upload and decrypted transparently when accessed through the crypt remote.

Run every Forgejo Actions job on the existing `depotrunner` using the `ssh-deploy` label. Extend that runner image with `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`. The shared runner will create database dumps, enforce retention, copy the Home Server copy, copy the encrypted Google Drive copy, verify each transfer, and support disaster-recovery procedures. Legacy tooling from the earlier replication design is removed from the image and the workflow during the refactor.

The owner revised the runner portion of the decision on 2026-10-04 to avoid a second runner service and registration identity. The repository now configures the shared runner and dual-target workflow. Successful image build, scheduled execution, transfers, integrity checks, retention, and restores remain unverified until recorded runtime evidence exists. Same-host artifacts must not be treated as sufficient disaster recovery.

The owner added the following operational detail on 2026-10-07, and revised the replication technology on 2026-10-08.

3. **Target selection:** each off-host target is enabled by its own key in `${PREFIX}_CONFIG`. Setting `backup_home_destination` enables Target 1; setting `backup_rclone_destination` enables Target 2; setting both enables both. An absent or empty key disables that target, and every other setting and secret used only by that target is then ignored rather than validated. Target 1 additionally requires `backup_home_sftp` (the `user@host[:port]` endpoint), `backup_home_db_keep_age`, and `backup_home_full_keep_age`; the workflow creates the `servicehub-home` SFTP remote at runtime. At least one off-host target must be enabled, and same-host archives under `backup_root` are created on every run regardless of target selection.
4. **Non-standard SFTP port:** Target 1 MAY use an SSH port other than 22, including an SFTP server on the local network, without a repository code change. The port is part of the `backup_home_sftp` endpoint (`user@host:port`); omitting it uses port 22.
5. **Transport authentication:** Target 1 authenticates the SSH connection with the private key in `BACKUP_HOME_SSH_KEY` and enforces host verification with `BACKUP_HOME_SSH_KNOWN_HOSTS`. There is no repository password: the Home Server holds readable archives, consistent with treating it as trusted storage.
6. **Replication semantics:** replication uses `rclone copy` or `rclone copyto`, never `rclone sync`. Source deletions must not propagate to backup destinations; retention stays under the explicit backup retention policy applied per destination.
7. **Off-site encryption:** the Google Drive remote is wrapped by an Rclone Crypt remote providing client-side encryption of file contents and, as configured, filenames. The Crypt password and configuration are recovery material and must be preserved in a protected location separate from Google Drive itself.

## Decision Drivers

- Recover from loss of the Oracle VM or cloud environment.
- Maintain a primary target that can be used directly for restoration.
- Maintain an independent off-site copy.
- Include databases, configuration, and persistent application data.
- Automate retention and transfers through repository-hosted workflows.
- Consolidate deployment, test, and backup jobs on one existing runner.
- Keep credentials outside tracked documentation.
- Minimise the number of distinct tools, secrets, and recovery steps an operator must master during a disaster.
- Support oCIS once it is deployed under [ADR-006](ADR-006-adopt-ocis-with-local-filesystem-storage.md).

## Backup Scope

Backups are created on the **source host**: the server that runs the ServiceHub services together with Forgejo and the Forgejo Actions runner that executes the workflow. That host may be a homelab server or an Oracle Cloud VM instance; the workflow reads `server_host` and `deploy_path` from `${PREFIX}_CONFIG` and does not assume which. The `backup_root` key names the directory on that source host where archives are written before any transfer, and it is a source-side path — not a target. The same-host copy under `backup_root` is an intermediate artifact and is not a recovery target.

### Service Configuration

- Docker Compose files.
- Environment files, without documenting secret values.
- Traefik configuration and certificate state.
- oCIS, Authentik, Forgejo, Stalwart, and related service configuration.
- Recovery material for `.env`, git-crypt keys, ACME state, and repository secrets, stored and governed separately from normal documentation.

### PostgreSQL Databases

Create transaction-consistent logical dumps for all non-template ServiceHub PostgreSQL databases, including databases used by Authentik, Forgejo, LiteLLM, Confluence, and Stalwart. Preserve the role-globals dump and validate database names before transfer. oCIS does not add a dedicated PostgreSQL database; its configuration and file data are protected as filesystem paths.

### Persistent Data

Protect the complete persistent-data inventory, including:

- oCIS configuration under `${APPS_DATA}/cloud/ocis/config`.
- oCIS file data under `${APPS_DATA}/cloud/ocis/data`.
- Forgejo repositories and application state.
- Mail data.
- Authentik media, templates, and any inventoried runtime state.
- Certificates, observability data, AI configuration, and other stateful bind mounts already covered by ServiceHub backup scope.

The implementation must record actual paths and exclusions. Storage outside the protected data root requires a separate copy rule.

## Backup Targets

| Target | Purpose | Technology | Enabled by | Implementation status |
|---|---|---|---|---|
| Home Server | Primary recovery target | Rclone SFTP remote; plain `.tar.gz` archives under `YYYY/YYYYMM` | `backup_home_destination` in `${PREFIX}_CONFIG` | Workflow refactored 2026-10-08; transfer not runtime-validated |
| Google Drive | Independent off-site copy | Rclone behind a Crypt remote (client-side encryption) | `backup_rclone_destination` in `${PREFIX}_CONFIG` | Configuration added; Crypt remote and transfer not runtime-validated |

Both targets are read from the source host: the workflow copies each archive out of `backup_root` to each destination with Rclone. Neither target depends on the other, so either can be disabled without changing the data path of the remaining one. Selection is per environment, because `STAG_CONFIG` and `PROD_CONFIG` are separate variables.

Both targets are enabled in the default configuration. Disabling one reduces the design to a single off-host copy, which is the condition option 2 in [Options Considered](#options-considered) was rejected for; treat a single-target configuration as an accepted reduction in protection rather than an equivalent design.

Target locations, account identifiers, hostnames, credentials, remote names, and retention values must remain in approved secret or environment configuration and must not be invented in documentation.

### Connection details

| Setting | Where it lives | Notes |
|---|---|---|
| SFTP endpoint for Target 1 | `backup_home_sftp` (`user@host[:port]`) and `backup_home_destination` (absolute path) in `${PREFIX}_CONFIG` | The workflow creates the `servicehub-home` Rclone SFTP remote from these keys at runtime; a non-standard port needs no code change. |
| SSH private key for Target 1 | `BACKUP_HOME_SSH_KEY` secret | Authenticates the SSH connection only; required whenever Target 1 is enabled. |
| Host keys for Target 1 | `BACKUP_HOME_SSH_KNOWN_HOSTS` secret | Enforces strict host verification; required whenever Target 1 is enabled. |
| Rclone remotes for Target 2 | `BACKUP_RCLONE_CONFIG` secret | Required whenever Target 2 is enabled; includes the Google Drive remote and the Crypt remote wrapping it. |
| Crypt password for Target 2 | Crypt configuration within `BACKUP_RCLONE_CONFIG` | Recovery material in its own right; must be duplicated to protected storage separate from Google Drive. |

### Why the targets deliberately differ

The two destinations are optimised for different jobs, and the difference is intentional.

**Home Server** is optimised for simple and immediate recovery: locate the archive, copy it, extract it, restore. Archives are stored as created, so any mechanism that can read a file — Rclone, SFTP, SCP — can retrieve them.

**Google Drive** is optimised for secure off-site disaster recovery: the copy is made through the Crypt remote, so the underlying storage never holds readable archives or a readable filename hierarchy. Recovery through the crypt remote transparently decrypts the logical hierarchy again.

## Backup Workflow

```text
Forgejo Actions
      |
      v
Database dumps and persistent-data archives
      |
      v
backup_root: YYYY/YYYYMM/*.tar.gz
      |
      +--> Rclone SFTP copy ----------------> Home Server (plain archives)
      |
      +--> Rclone copy --> Crypt remote ----> Google Drive (encrypted archives)
```

The configured workflow fails when required inputs, dumps, archives, transfers, retention operations, or integrity checks fail. Transfer and restore credentials are supplied only as protected Forgejo Actions secrets. Target locations, credentials, and approved retention values remain outside tracked documentation.

A branch whose enabling key is absent or empty is skipped entirely: its tooling, secrets, validation, transfer, integrity check, and retention steps do not run and are not validated. The workflow fails when neither branch is enabled, so a configuration that disables both targets cannot produce a run that looks successful while keeping archives on the source host only.

### Copy semantics

Replication uses `rclone copy` (or `rclone copyto` for a single named artifact), not `rclone sync`. This is deliberate: backup retention must remain controlled by the explicit retention policy rather than by propagating source deletions to the destinations. The workflow therefore creates archives, copies newly created archives to each enabled target, verifies each transfer, and applies explicit retention cleanup on each destination independently.

### Integrity verification

Replication verification must not assume that a successful upload means a recoverable backup. After each transfer the workflow runs `rclone check ... --download` against the destination copy for both targets, so comparison is against downloaded bytes rather than size and hash metadata alone. A separate periodic restore test is required in addition to per-transfer checks.

### Retention

Retention stays independent per archive type and per destination:

- `db_backup_retention_days` applies to `*-dbBK-*`; `*-cfgBK-*` archives are produced daily and share the same period.
- `backup_local_full_retention_days` applies to `*-fullBK-*` on the source host.
- Per-destination retention ages are applied explicitly on each off-host destination: `backup_home_db_keep_age` and `backup_home_full_keep_age` for the Home Server, `backup_rclone_db_keep_age` and `backup_rclone_full_keep_age` for Google Drive.

The Home Server and Google Drive may use different retention periods if desired. Retention values remain approved protected configuration.

## Recovery Procedures

### Scenario 1: Home Server Used for Recovery

The Home Server is the preferred recovery path because it requires the fewest components.

1. Select the required archive under `serviceHub/YYYY/YYYYMM/`.
2. Retrieve it using Rclone, SFTP, SCP, or another available mechanism.
3. Extract it: `tar -xzf <archive>.tar.gz`.
4. Perform the appropriate restoration: `dbBK` to PostgreSQL, `cfgBK` to `.env` and egress configuration, `fullBK` to application persistent data.
5. Start and validate the platform.

No backup repository reconstruction is required. In the wider VM-loss scenario, provisioning, configuration, certificate, and secret-recovery steps proceed as in Scenario 2.

**Planning estimate:** one to two hours. This estimate is untested and does not establish an RTO.

### Scenario 2: Google Drive Used for Recovery

Google Drive is the secondary disaster-recovery source.

1. Provision a replacement VM.
2. Provide the Rclone configuration and the Crypt password/configuration.
3. Retrieve the required archive through the Crypt remote, which downloads and decrypts it.
4. Validate archive integrity before restoration.
5. Restore configuration, databases, volumes, certificates, and secret recovery material.
6. Start and validate the platform as in Scenario 1.

Crypt credentials and configuration are recovery material and must exist outside Google Drive; access can be recreated only when the Crypt password and associated configuration are retained.

**Planning estimate:** subject to the same untested one-to-two-hour estimate; download duration, decryption, and access recovery must be measured.

### Periodic recovery testing

A backup is not fully validated because the archive was created and replication succeeded; the final validation is that it can be restored. The workflow or its operator performs a scheduled restore verification:

- **Monthly:** retrieve a recent `cfgBK` and a recent `dbBK`, verify the tar archive, extract to a temporary location, verify the expected contents, and remove the temporary data.
- **Less frequently:** full `fullBK` recovery tests, because of their potentially much greater size.

Complete recovery tests are executed against both targets: one Home Server recovery test and one Google Drive Crypt recovery test.

## Options Considered

1. Retain same-host PostgreSQL and filesystem archives only.
2. Replicate backups to one off-host destination.
3. Replicate backups to a Home Server primary target and a Google Drive off-site target.

Option 1 was rejected because host or cloud loss can remove both service data and backups. Option 2 was rejected because a single off-host destination becomes a single point of backup failure or credential loss. Option 3 was accepted because it separates primary recovery from off-site continuity without introducing cluster infrastructure.

The 2026-10-07 amendment does not reverse that evaluation. It makes each target individually selectable so an operator can defer one credential set or destination, while option 3 remains the default configuration and the recommended one.

The 2026-10-08 amendment keeps option 3 unchanged and changes only the transfer technology inside it: both targets are replicated with Rclone, with an Rclone Crypt remote wrapping Google Drive. Because ServiceHub already compresses archives before replication, a repository-based backup engine was considered and rejected for this design — it would have added a second reconstruction layer plus password, repository, and SSH-subprocess administration while providing little deduplication or snapshot value over already-compressed archives. Rclone for both targets preserves every destination property while collapsing the recovery path to a single tool.

## Rationale

The dual-target design addresses host-loss and cloud-outage scenarios while preserving a filesystem-visible primary recovery path. Because archives are already self-contained before replication, plain file copy is sufficient for the trusted primary target, and client-side encryption covers the untrusted off-site target. One replication technology covers both destinations, so operators learn one configuration model and one recovery tool, and the disaster-recovery path no longer depends on reconstructing a backup repository before the archives can be read. Repository-hosted automation keeps backup behaviour reviewable and reusable across environments.

## Positive Consequences

- Primary and off-site recovery paths are independent.
- Simpler disaster recovery: backup files are directly visible on the Home Server, with no repository reconstruction.
- One replication technology for both destinations, with one configuration and recovery model.
- No backup-repository administration: no repository passwords, initialisation, pruning, or backup-tool SSH subprocesses.
- Database and filesystem layers have distinct consistency roles.
- Retention and transfer behaviour can be automated and alerted.
- The design can cover existing stateful services and the configured oCIS filesystem paths.
- Backup creation and transfer remain traceable to Forgejo Actions history after execution evidence is available.
- Google Drive remains protected for off-site disaster recovery through Rclone Crypt.

## Negative Consequences

- No snapshot browsing: the `.tar.gz` archive is the only recovery unit, with no per-file history or backup metadata queries.
- No repository-level deduplication; archives are stored in full at each destination.
- Integrity checking depends on `rclone check --download` plus periodic restore tests rather than a dedicated repository check.
- Home Server backup archives are readable at rest unless filesystem or storage-level encryption is provided.
- Google Drive disaster recovery depends on retaining the Rclone Crypt credentials and configuration separately from Google Drive.
- Two transfer paths increase runtime, storage, credential, and monitoring overhead.
- Google Drive recovery depends on external service availability and account access.
- Large filesystem archives may consume significant Home Server and network capacity.
- Retention and verification must be managed explicitly by the workflow rather than by a backup engine.
- Backup creation alone does not provide recovery assurance without restore tests.
- Deployment and backup jobs queue behind one another because the shared runner has capacity one.
- Optional targets mean a single-target configuration is reachable by deleting one key, with no separate approval step.

## Risks

- **No tested restore:** implement recovery procedures and record an isolated restore test before claiming recovery capability.
- **Undefined RPO, RTO, and retention:** approve objectives only from measured backup history and timed restoration evidence.
- **Credential or key loss:** define protected storage, custodians, rotation, and break-glass recovery without placing values in documentation.
- **Crypt credential loss:** Google Drive content is unrecoverable without the Crypt password and configuration; mitigate by keeping a protected copy separate from Google Drive and testing retrieval from it.
- **Readable archives on the Home Server:** acceptable only while the Home Server is classified as trusted storage; revisit if the threat model changes or the device leaves trusted control.
- **Transfer failure remains unnoticed:** alert on missing, stale, failed, or integrity-checked backups.
- **Integrity regression:** `rclone check --download` after each transfer plus scheduled restore tests must be enforced, not assumed.
- **Inconsistent live archives:** use transaction-consistent PostgreSQL dumps and validate filesystem or oCIS-aware consistency rules.
- **External Google Drive limitations:** test retrieval, quotas, authentication recovery, and off-site retention before relying on the copy.
- **Single-target drift:** a disabled target raises no error and runs no credential check, so an environment can silently drop to one off-host copy after a single edit to `${PREFIX}_CONFIG`; mitigate by recording which targets each environment is expected to enable and by alerting when a run reports a changed enabled-target count.

## Implementation Evidence

The current repository contains:

- [Daily and weekly backup workflow](../../.forgejo/workflows/71-backup.yml)
- [Shared Forgejo runner image and configuration](../../shared/forgejo/README.md)
- [Backup and restore operations record](../operations/BACKUP-RESTORE.md)
- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [ADR-006 oCIS filesystem configuration](ADR-006-adopt-ocis-with-local-filesystem-storage.md)

Repository configuration now extends `depotrunner` with Rclone and the PostgreSQL client; keeps the workflow on `ssh-deploy`; and defines both target contracts, same-host and target retention inputs, and integrity checks. No image-build result, successful transfer evidence, independently retrievable copy, restore workflow execution, or timed restore evidence is recorded as of 2026-10-04. Actual target locations and retention values remain in protected configuration.

On 2026-10-07 the workflow was changed so that each off-host target is gated on its own `${PREFIX}_CONFIG` key, each target's tooling and secrets are checked only when that target is enabled, and the run fails when neither target is enabled. The change was verified by extracting the workflow's validation and tool-check prefix and executing it against both target combinations, a single-target combination for each target, a both-disabled configuration, and missing-secret and malformed-value cases: each returned the expected enabled-target line or the expected error. The transfer stages themselves, on the source host and against real targets, remain unexecuted and unevidenced.

On 2026-10-08 the replication technology was revised as recorded in this document, and the workflow was refactored the same day. Both off-host targets now replicate through Rclone: the workflow creates a `servicehub-home` SFTP remote for the Home Server from `backup_home_sftp`, `backup_home_destination`, `BACKUP_HOME_SSH_KEY`, and `BACKUP_HOME_SSH_KNOWN_HOSTS`, and uses the Crypt-wrapped remote named by `backup_rclone_destination` for Google Drive. Every transfer is verified with `rclone check --download`, retention is applied per destination with the four keep-age keys, the workflow logs `Enabled off-host targets: home=<0|1> gdrive=<0|1>`, and the earlier Home Server path, its repository keys, and its password secret were removed from the workflow, the runner image, and the documentation. The refactor was verified by extracting the workflow's validation prefix and executing it against 14 combinations — both targets, each target alone, both disabled, missing secrets, malformed endpoint and path values, non-numeric ports, invalid retention ages, missing keep-age keys, legacy configuration keys, and an absent `${PREFIX}_CONFIG` — each returning the expected enabled-target line or the expected error. Transfer stages against real targets remain unexecuted and unevidenced. The existing Home Server backup repository must not be deleted until both new recovery paths have been tested successfully.

## Related Documents

- [ADR-006 Adopt oCIS with Local Filesystem Storage](ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [Backup and restore](../operations/BACKUP-RESTORE.md)
- [PHASE-004 Observability and Operational Hardening](../phases/PHASE-004-observability-and-operational-hardening.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
- [ServiceHub Roadmap](../requirements/ROADMAP.md)

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Refactor the backup workflow so both off-host targets replicate each archive with Rclone | ServiceHub Architecture | TBD | Implemented 2026-10-08; transfer execution pending |
| Set `backup_home_sftp`, `backup_home_destination`, and the Home Server keep-age keys for each environment, with `BACKUP_HOME_SSH_KEY` and `BACKUP_HOME_SSH_KNOWN_HOSTS` secrets | ServiceHub Architecture | TBD | Keys finalised 2026-10-08; environment values pending |
| Configure the Google Drive Rclone remote and a Crypt remote wrapping it | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Verify `rclone check --download` (or equivalent) runs after every transfer to both targets | ServiceHub Architecture | TBD | Implemented for both targets 2026-10-08; execution evidence pending |
| Preserve independent retention policies for `dbBK`, `cfgBK`, and `fullBK` on each destination | ServiceHub Architecture | TBD | Per-destination keep-age keys implemented 2026-10-08; approved values pending |
| Remove retired Home Server replication configuration and secrets after successful migration | ServiceHub Architecture | TBD | Removed from workflow, image, and documentation 2026-10-08; repository secret removal pending |
| Preserve the Rclone Crypt credentials and configuration in a secure recovery location separate from Google Drive | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Execute and validate database dumps, archive creation, retention, and Rclone transfers to both targets in Forgejo Actions | ServiceHub Architecture | TBD | Repository implementation added; execution evidence pending |
| Perform a complete Home Server recovery test and a complete Google Drive Crypt recovery test | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Introduce periodic automated or documented restore verification (monthly `cfgBK`/`dbBK`, less frequent `fullBK`) | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Retain the existing Home Server backup repository until both new recovery paths have been tested successfully | ServiceHub Architecture | TBD | Proposed 2026-10-08 |
| Align related documentation (`BACKUP-RESTORE`, `ARCHITECTURE`, `DATA-FLOW`, `SYSTEM-CONTEXT`, `DEPLOYMENT-ARCHITECTURE`, `RFC-001`, `TEST-001`, `PHASE-004`, `ROADMAP`) with the Rclone dual-target decision | ServiceHub Architecture | TBD | Completed 2026-10-08 |
| Build and validate the existing `depotrunner` image with the added backup tools | ServiceHub Architecture | TBD | Repository configuration added; build result pending |
| Define protected target configuration, credentials, retention, encryption, and alerting without recording secret values | ServiceHub Architecture | TBD | Secret names and validation added; approved values and alerting pending |
| Add oCIS configuration and persistent file storage to backup scope under ADR-006 | ServiceHub Architecture | TBD | Covered by full-archive and target-transfer configuration; execution pending |
| Implement and execute isolated restores from both targets and record integrity, duration, and validation evidence | ServiceHub Architecture | TBD | Proposed |
| Execute each target-selection combination (both targets, Home Server only, Google Drive only) in Forgejo Actions and confirm a disabled target's secrets and tools are not required | ServiceHub Architecture | TBD | Validation logic reworked and verified against 14 combinations locally 2026-10-08; Forgejo Actions runtime execution pending |
| Record which targets each environment is expected to enable, and alert when a run reports a changed enabled-target count | ServiceHub Architecture | TBD | Proposed |
| Approve RPO and RTO values from measured restore evidence | George Li | TBD | Proposed |
