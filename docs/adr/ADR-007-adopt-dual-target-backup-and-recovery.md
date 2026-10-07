---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-007
title: Adopt Dual-Target Backup and Disaster Recovery
version: "1.3"
status: Accepted
decision_basis: Owner decision recorded on 2026-10-03 and runner consolidation revised on 2026-10-04; repository configuration added; target selection, source-host scope, non-standard SFTP port, and key-based authentication recorded on 2026-10-07; runtime validation pending
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-03
updated: 2026-10-07
tags:
  - servicehub
  - architecture
  - backup
  - disaster-recovery
  - restic
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

The repository implements daily PostgreSQL dumps and a weekly or on-demand `APPS_DATA` archive through Forgejo Actions. Those artifacts are written under a configured backup root on the target host, with configured Restic and Rclone transfers. No successful off-site transfer or tested restore is recorded.

ServiceHub must be able to recover from VM loss, an Oracle Cloud outage, accidental deletion, data corruption, and configuration error. Protection must include service configuration, PostgreSQL databases, and persistent filesystem paths for oCIS, Forgejo, email, Authentik, and the other stateful services already in scope.

Recovery objectives are not yet approved or measured. The one-to-two-hour recovery estimate in the decision discussion is a planning estimate only; it is not an approved RTO or evidence of recovery capability.

## Decision

Use Forgejo Actions to create database dumps and persistent-data archives, then copy each protected backup set to two destinations:

1. **Home Server:** primary recovery target using Restic over SSH/SFTP.
2. **Google Drive:** independent off-site recovery copy using Rclone.

Run every Forgejo Actions job on the existing `depotrunner` using the `ssh-deploy` label. Extend that runner image with `restic`, `rclone`, `openssh-client`, `postgresql-client`, `bash`, and `jq`. The shared runner will create database dumps, enforce retention, upload the Home Server copy, synchronise the Google Drive copy, and support disaster-recovery procedures.

The owner revised the runner portion of the decision on 2026-10-04 to avoid a second runner service and registration identity. The repository now configures the shared runner and dual-target workflow. Successful image build, scheduled execution, transfers, integrity checks, retention, and restores remain unverified until recorded runtime evidence exists. Same-host artifacts must not be treated as sufficient disaster recovery.

The owner added the following operational detail on 2026-10-07.

3. **Target selection:** each off-host target is enabled by its own key in `${PREFIX}_CONFIG`. Setting `backup_restic_repository` enables Target 1; setting `backup_rclone_destination` enables Target 2; setting both enables both. An absent or empty key disables that target, and every other setting and secret used only by that target is then ignored rather than validated. At least one off-host target must be enabled, and same-host archives under `backup_root` are created on every run regardless of target selection.
4. **Non-standard SFTP port:** Target 1 MAY use an SSH port other than 22, including an SFTP server on the local network, without a repository code change. Restic accepts the port through its URL form, for example `sftp://backup@backuphost:2222//srv/restic/servicehub`, where the first slash separates the connection settings from the path and the second begins the path. A relative path uses a single slash. The alternative is an SSH configuration alias carrying `Port`. The `sftp:` prefix is required by the workflow in either form.
5. **Transport authentication:** Target 1 authenticates the SSH connection with the private key in `BACKUP_HOME_SSH_KEY`. That key does not replace `BACKUP_RESTIC_PASSWORD`, which encrypts the repository content and is required to read it back. The two are independent, and both are required whenever Target 1 is enabled.

## Decision Drivers

- Recover from loss of the Oracle VM or cloud environment.
- Maintain a primary target that can be used directly for restoration.
- Maintain an independent off-site copy.
- Include databases, configuration, and persistent application data.
- Automate retention and transfers through repository-hosted workflows.
- Consolidate deployment, test, and backup jobs on one existing runner.
- Keep credentials outside tracked documentation.
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
| Home Server | Primary recovery target | Restic over SSH/SFTP | `backup_restic_repository` in `${PREFIX}_CONFIG` | Configuration added; transfer not runtime-validated |
| Google Drive | Independent off-site copy | Rclone | `backup_rclone_destination` in `${PREFIX}_CONFIG` | Configuration added; transfer not runtime-validated |

Both targets are read from the source host: the workflow streams each archive out of `backup_root` to Restic and copies the same archive to Rclone. Neither target depends on the other, so either can be disabled without changing the data path of the remaining one. Selection is per environment, because `STAG_CONFIG` and `PROD_CONFIG` are separate variables.

Both targets are enabled in the default configuration. Disabling one reduces the design to a single off-host copy, which is the condition option 2 in [Options Considered](#options-considered) was rejected for; treat a single-target configuration as an accepted reduction in protection rather than an equivalent design.

Target locations, account identifiers, hostnames, credentials, repository names, and retention values must remain in approved secret or environment configuration and must not be invented in documentation.

### Connection details

| Setting | Where it lives | Notes |
|---|---|---|
| SFTP port for Target 1 | `backup_restic_repository` value | Use the Restic URL form `sftp://user@host:port//abs/path` (double slash before an absolute path) or an SSH configuration alias with `Port`. No code change is required. |
| SSH private key for Target 1 | `BACKUP_HOME_SSH_KEY` secret | Authenticates the SSH connection only. |
| Host keys for Target 1 | `BACKUP_HOME_SSH_KNOWN_HOSTS` secret | Enforces strict host verification; required whenever Target 1 is enabled. |
| Repository password for Target 1 | `BACKUP_RESTIC_PASSWORD` secret | Encrypts repository content. Independent of the SSH key and not replaceable by it. |
| Rclone remotes for Target 2 | `BACKUP_RCLONE_CONFIG` secret | Required whenever Target 2 is enabled. |

## Backup Workflow

```text
Forgejo Actions
      |
      v
Database dumps and persistent-data archives
      |
      +--> Restic over SSH/SFTP --> Home Server
      |
      +--> Rclone ---------------> Google Drive
```

The configured workflow fails when required inputs, dumps, archives, transfers, retention operations, or integrity checks fail. Transfer and restore credentials are supplied only as protected Forgejo Actions secrets. Target locations, credentials, and approved retention values remain outside tracked documentation.

A branch whose enabling key is absent or empty is skipped entirely: its tooling, secrets, validation, transfer, integrity check, and retention steps do not run and are not validated. The workflow fails when neither branch is enabled, so a configuration that disables both targets cannot produce a run that looks successful while keeping archives on the source host only.

## Recovery Procedures

### Scenario 1: Oracle VM Lost

1. Provision a replacement VM.
2. Restore Compose and approved environment configuration.
3. Restore PostgreSQL role globals and database dumps.
4. Restore persistent volumes and certificate state.
5. Restore separately governed secret recovery material.
6. Start services in dependency order.
7. Validate routes, authentication, repositories, email, oCIS data, telemetry, and subsequent backups.

**Planning estimate:** one to two hours. This estimate is untested and does not establish an RTO.

### Scenario 2: Google Drive Used for Recovery

1. Provision a replacement VM.
2. Retrieve the off-site backup set using Rclone.
3. Validate backup integrity before restoration.
4. Restore configuration, databases, volumes, certificates, and secret recovery material.
5. Start and validate the platform as in Scenario 1.

**Planning estimate:** subject to the same untested one-to-two-hour estimate; download duration and access recovery must be measured.

## Options Considered

1. Retain same-host PostgreSQL and filesystem archives only.
2. Replicate backups to one off-host destination.
3. Replicate backups to a Home Server primary target and a Google Drive off-site target.

Option 1 was rejected because host or cloud loss can remove both service data and backups. Option 2 was rejected because a single off-host destination becomes a single point of backup failure or credential loss. Option 3 was accepted because it separates primary recovery from off-site continuity without introducing cluster infrastructure.

The 2026-10-07 amendment does not reverse that evaluation. It makes each target individually selectable so an operator can defer one credential set or destination, while option 3 remains the default configuration and the recommended one.

## Rationale

The dual-target design addresses host-loss and cloud-outage scenarios while preserving a filesystem-visible primary recovery path. Restic supports managed repository retention and transfer to the Home Server, while Rclone provides a separate path to Google Drive. Repository-hosted automation keeps backup behaviour reviewable and reusable across environments.

## Positive Consequences

- Primary and off-site recovery paths are independent.
- Database and filesystem layers have distinct consistency roles.
- Retention and transfer behaviour can be automated and alerted.
- The design can cover existing stateful services and the configured oCIS filesystem paths.
- Backup creation and transfer remain traceable to Forgejo Actions history after execution evidence is available.

## Negative Consequences

- Two transfer paths increase runtime, storage, credential, and monitoring overhead.
- Google Drive recovery depends on external service availability and account access.
- Large filesystem archives may consume significant Home Server and network capacity.
- Backup creation alone does not provide recovery assurance without restore tests.
- Deployment and backup jobs queue behind one another because the shared runner has capacity one.
- Optional targets mean a single-target configuration is reachable by deleting one key, with no separate approval step.

## Risks

- **No tested restore:** implement recovery procedures and record an isolated restore test before claiming recovery capability.
- **Undefined RPO, RTO, and retention:** approve objectives only from measured backup history and timed restoration evidence.
- **Credential or key loss:** define protected storage, custodians, rotation, and break-glass recovery without placing values in documentation.
- **Transfer failure remains unnoticed:** alert on missing, stale, failed, or integrity-checked backups.
- **Inconsistent live archives:** use transaction-consistent PostgreSQL dumps and validate filesystem or oCIS-aware consistency rules.
- **External Google Drive limitations:** test retrieval, quotas, authentication recovery, and off-site retention before relying on the copy.
- **Single-target drift:** a disabled target raises no error and runs no credential check, so an environment can silently drop to one off-host copy after a single edit to `${PREFIX}_CONFIG`; mitigate by recording which targets each environment is expected to enable and by alerting when a run reports a changed enabled-target count.

## Implementation Evidence

The current repository contains:

- [Daily and weekly backup workflow](../../.forgejo/workflows/30-prod-backup-services.yml)
- [Shared Forgejo runner image and configuration](../../shared/forgejo/README.md)
- [Backup and restore operations record](../operations/BACKUP-RESTORE.md)
- [RFC-001 Reliability and Recovery Baseline](../rfc/RFC-001-reliability-and-recovery-baseline.md)
- [ADR-006 oCIS filesystem configuration](ADR-006-adopt-ocis-with-local-filesystem-storage.md)

Repository configuration now extends `depotrunner` with Restic, Rclone, and the PostgreSQL client; keeps the workflow on `ssh-deploy`; and defines both target contracts, same-host and target retention inputs, and integrity checks. No image-build result, successful transfer evidence, independently retrievable copy, restore workflow execution, or timed restore evidence is recorded as of 2026-10-04. Actual target locations and retention values remain in protected configuration.

On 2026-10-07 the workflow was changed so that each off-host target is gated on its own `${PREFIX}_CONFIG` key, each target's tooling and secrets are checked only when that target is enabled, and the run fails when neither target is enabled. The change was verified by extracting the workflow's validation and tool-check prefix and executing it against both target combinations, a single-target combination for each target, a both-disabled configuration, and missing-secret and malformed-value cases: each returned the expected enabled-target line or the expected error. The transfer stages themselves, on the source host and against real targets, remain unexecuted and unevidenced.

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
| Build and validate the existing `depotrunner` image with the added backup tools | ServiceHub Architecture | TBD | Repository configuration added; build result pending |
| Execute and validate database dumps, archive creation, retention, Restic transfer, and Rclone synchronisation in Forgejo Actions | ServiceHub Architecture | TBD | Repository implementation added; execution evidence pending |
| Define protected target configuration, credentials, retention, encryption, and alerting without recording secret values | ServiceHub Architecture | TBD | Secret names and validation added; approved values and alerting pending |
| Add oCIS configuration and persistent file storage to backup scope under ADR-006 | ServiceHub Architecture | TBD | Covered by full-archive and target-transfer configuration; execution pending |
| Implement and execute isolated restores from both targets and record integrity, duration, and validation evidence | ServiceHub Architecture | TBD | Proposed |
| Execute each target-selection combination (both targets, Restic only, Rclone only) in Forgejo Actions and confirm a disabled target's secrets and tools are not required | ServiceHub Architecture | TBD | Validation logic added 2026-10-07; runtime execution pending |
| Record which targets each environment is expected to enable, and alert when a run reports a changed enabled-target count | ServiceHub Architecture | TBD | Proposed |
| Approve RPO and RTO values from measured restore evidence | George Li | TBD | Proposed |
