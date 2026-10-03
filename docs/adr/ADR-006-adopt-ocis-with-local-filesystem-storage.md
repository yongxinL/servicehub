---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-006
title: Adopt oCIS with Local Filesystem Storage
version: "1.1"
status: Accepted
decision_basis: Owner decision recorded on 2026-10-03; repository configuration added on 2026-10-03; runtime validation pending
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-03
updated: 2026-10-03
tags:
  - servicehub
  - architecture
  - cloud-drive
  - ocis
  - storage
related_documents:
  - ADR-003
  - ADR-004
  - ADR-007
  - RFC-002
  - ROADMAP-001
  - BACKUP-RESTORE
---

# ADR-006: Adopt oCIS with Local Filesystem Storage

## Context

ServiceHub provides identity management, source control, email, documentation, and related platform services on a single-node Docker Compose deployment. A cloud-drive capability is required for family documents, tax and property records, personal archives, project attachments, secure sharing, and future document collaboration.

The target deployment is an Oracle Cloud VM using Docker Compose, PostgreSQL, Traefik, and Authentik. The design must favour simple operations, straightforward recovery, low infrastructure complexity, Authentik SSO integration, and backups to a home server and an off-site service. Cluster operation is not required for the initial implementation.

At the time of the decision, no oCIS service, route, OIDC application, or persistent storage path existed in the repository. Repository configuration has since been added, but no container start, OIDC sign-in, file operation, backup, or restore has been executed as part of this change.

## Decision

Deploy the `wbappcloudrv` service in `compose/wbapp.yml` using the `owncloud/ocis` image, Authentik OIDC, Docker Compose, and local filesystem storage on the Oracle Cloud VM. Mount oCIS configuration under `${APPS_DATA}/cloud/ocis/config` and file data under `${APPS_DATA}/cloud/ocis/data`, and include both paths in the backup scope under [ADR-007](ADR-007-adopt-dual-target-backup-and-recovery.md).

oCIS 8.2 does not use a ServiceHub PostgreSQL database for its own service state. PostgreSQL continues to store Authentik identity data and other ServiceHub relational workloads. The operational guide is [shared/ocis/README.md](../../shared/ocis/README.md).

Do not deploy MinIO, OCI Object Storage, or an S3 storage backend for the initial implementation. Reconsider an object-storage backend only if measured scale, availability, or operational requirements justify the additional component.

## Decision Drivers

- Simple, explainable operations on a single node.
- Easy recovery using filesystem-visible data.
- Low service and infrastructure count.
- Authentik OIDC single sign-on.
- Authentication through the existing PostgreSQL-backed Authentik identity service.
- Backup to a home server with an independent off-site copy.
- No requirement for cluster-scale throughput or availability.

## Options Considered

### Option A: oCIS with OCI Object Storage

```text
oCIS
  |
  v
OCI Object Storage
```

- **Advantages:** managed durability and horizontal scalability.
- **Disadvantages:** another cloud dependency, less directly inspectable data, more complex metadata and object recovery, and scale beyond the initial requirement.
- **Result:** Rejected for the initial implementation.

### Option B: oCIS with MinIO

```text
oCIS
  |
  v
MinIO
  |
  v
Filesystem
```

- **Advantages:** S3 compatibility and portable object-storage behaviour.
- **Disadvantages:** an additional service, greater operational overhead, and a more complex recovery workflow without a current scale requirement.
- **Result:** Rejected for the initial implementation.

### Option C: oCIS with Local Filesystem Storage

```text
oCIS
  |
  v
Filesystem
  |
  v
Oracle Cloud block volume
```

- **Advantages:** simplest architecture, fewer services, filesystem-visible data, and lower recovery complexity.
- **Disadvantages:** lower scalability than an object-storage backend and single-volume availability constraints.
- **Result:** Accepted.

## Rationale

Local filesystem storage best matches the stated family-deployment requirements and the existing single-node Compose architecture. It avoids adding MinIO or an external object-store dependency solely for scalability that is not currently required. The local data path can be inventoried, archived, restored, and inspected with ordinary filesystem tooling, while Authentik retains its established PostgreSQL-backed identity role.

## Target Architecture

```text
                 Authentik
                    |\
                    | \ PostgreSQL
                    | OIDC
                    v
                  oCIS
                    |
                    v
            Local filesystem
                    |
                    v
            Oracle Cloud block volume
```

The repository now contains the Compose service, routing, OIDC environment, local storage mounts, and operational documentation. Runtime authentication, file operations, monitoring, backup, and recovery remain unvalidated.

## Positive Consequences

- One fewer stateful service compared with MinIO.
- File data remains directly visible for inventory and recovery.
- Authentik remains the central identity provider.
- The initial deployment fits the existing single-host operational model.
- The local storage path can be covered by the ADR-007 backup workflow.

## Negative Consequences

- Local storage does not provide object-store scalability or managed durability.
- The VM and its block volume remain a common dependency for live service availability.
- Large oCIS datasets may increase archive duration, transfer volume, and recovery time.
- oCIS introduces a new upgrade, identity, sharing, monitoring, and restoration surface.

## Risks

- **Capacity or throughput growth:** monitor storage use and service performance; reevaluate object storage if measured needs change.
- **VM or block-volume loss:** protect platform configuration, PostgreSQL data, and both oCIS filesystem paths through ADR-007; residual risk remains until a restore is tested.
- **Inconsistent live file archives:** define and test an oCIS-aware or coordinated backup procedure before relying on recovery.
- **OIDC or upgrade regression:** validate authentication, authorisation, sharing, and rollback behaviour in staging before production adoption.
- **Recovery complexity from large datasets:** measure archive and restore duration and set objectives from test evidence rather than assumption.

## Implementation Evidence

Repository configuration added on 2026-10-03:

- [`wbappcloudrv` and `wbappcloudrvinit`](../../compose/wbapp.yml) define the oCIS service, local bind mounts, dependency order, Traefik route, health check, and Authentik OIDC environment.
- [`env.example`](../../env.example) defines the oCIS image, public hostname, Authentik issuer, public OIDC client ID, and certificate-verification setting.
- [Traefik route configuration](../../compose/route.yml) permits long transfers and encoded WebDAV path characters.
- [Deployment workflow](../../.forgejo/workflows/00-prod-deploy-services.yml) can deploy `wbappcloudrv` after its directory initialiser.
- [oCIS operational guide](../../shared/ocis/README.md) records Authentik provider setup, redirect URIs, validation, backup scope, and operations.
- [ADR-007](ADR-007-adopt-dual-target-backup-and-recovery.md) and [backup and restore](../operations/BACKUP-RESTORE.md) record the target recovery strategy.

This is configuration evidence only. The container, Authentik OIDC flow, account provisioning, file operations, monitoring, dual-target backup, and restore have not been runtime-validated by this change.

## Related Documents

- [ADR-003 Use PostgreSQL as the Primary Relational Platform](ADR-003-use-postgresql-as-primary-database.md)
- [ADR-004 Use Authentik for Central Identity](ADR-004-use-authentik-for-central-identity.md)
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](ADR-007-adopt-dual-target-backup-and-recovery.md)
- [RFC-002 Family Cloud Platform Strategy](../rfc/RFC-002-family-cloud-platform-strategy.md)
- [ServiceHub Roadmap](../requirements/ROADMAP.md)
- [Backup and restore](../operations/BACKUP-RESTORE.md)

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Add the oCIS Compose service with Authentik OIDC, Traefik, and persistent local storage | ServiceHub Architecture | 2026-10-03 | Repository configuration added; runtime validation pending |
| Configure and validate Authentik OIDC sign-in, sign-out, authorisation, and break-glass access | ServiceHub Architecture | TBD | Proposed |
| Include oCIS configuration and file storage in the ADR-007 backup workflow | ServiceHub Architecture | TBD | Proposed; both paths are in the current full-archive scope |
| Validate synchronisation, sharing, mobile access, monitoring, upgrade, and rollback behaviour | ServiceHub Architecture | TBD | Proposed |
| Update architecture, component, data-flow, service-inventory, and operational records | George Li | 2026-10-03 | Repository documentation updated; runtime evidence pending |
