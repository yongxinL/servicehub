---
project: ServiceHub
project_code: SVCHUB
document_type: RFC
document_id: RFC-002
title: Family Cloud Platform Strategy
version: "1.1"
status: Accepted
lifecycle_stage: Ideation
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-03
tags:
  - servicehub
  - family-cloud
  - files
  - strategy
related_documents:
  - CHARTER-001
  - ARCHITECTURE
  - ROADMAP-001
  - ADR-006
  - ADR-007
  - BACKUP-RESTORE
---

# RFC-002: Family Cloud Platform Strategy

## Summary

Record whether ServiceHub needs a dedicated family file-cloud platform and select the initial platform and storage model. Repository configuration for the selected service now exists, but runtime delivery evidence is pending.

## Requirements to Evaluate

- Authentik OIDC integration.
- Family file storage.
- File synchronisation.
- Mobile access.
- External sharing.
- Backup and recovery.
- Monitoring.
- Operational overhead.
- AI or RAG document access.

## Options

### No Dedicated Cloud Platform

Use the current platform without a file synchronisation service. Families could continue using existing approved tools outside ServiceHub.

- **Benefits:** no new database, synchronisation, mobile, sharing, or recovery workload.
- **Costs:** no integrated family file repository or AI/RAG access to a managed corpus.
- **Fit:** not selected for the initial implementation.

### Lightweight File Management

Use a small file manager or existing application storage rather than a full sync platform.

- **Benefits:** lower operational overhead.
- **Costs:** weak mobile synchronisation, sharing, versioning, and offline access.
- **Fit:** suitable only if requirements remain limited to basic browsing or upload.

### oCIS / ownCloud Infinite Scale

Pilot oCIS as a cloud-native file platform with OIDC and storage integrations.

- **Benefits:** modern file synchronisation, sharing, and potential extension points.
- **Costs:** new identity integration, storage layout, backup, upgrade, monitoring, and mobile testing.
- **Fit:** accepted for the initial implementation.

### Nextcloud

Adopt Nextcloud as a broader family collaboration suite.

- **Benefits:** mature synchronisation, sharing, mobile clients, and extensive applications.
- **Costs:** larger application surface, plug-in and upgrade management, and potentially higher resource use.
- **Fit:** deferred unless requirements expand beyond the selected oCIS scope.

## Evaluation Matrix

| Criterion | No platform | Lightweight | oCIS | Nextcloud |
|---|---|---|---|---|
| Authentik OIDC | Not applicable | Limited or app-specific | Configuration present; runtime validation required | Runtime validation required |
| Family file storage | No new platform | Basic | Yes | Yes |
| File synchronisation | No | Weak | Yes | Yes |
| Mobile access | No | Limited | Requires validation | Requires validation |
| External sharing | Outside scope | Limited | Requires policy and test | Requires policy and test |
| Backup and recovery | Existing platform only | Existing platform only | New scope | New scope |
| Monitoring | Existing platform only | Existing platform only | New scope | New scope |
| Operational overhead | Lowest | Low | Moderate | Moderate to high |
| AI or RAG access | None | Manual | Requires pilot | Requires pilot |

The matrix records evaluation criteria, not tested product results.

## Decision

On 2026-10-03, ServiceHub adopted oCIS as its cloud-drive platform using Authentik OIDC, Docker Compose, and local filesystem storage. PostgreSQL remains the Authentik identity store but is not an oCIS service database. MinIO, OCI Object Storage, and an S3 storage backend are not part of the initial implementation. The architecture, options, risks, and implementation requirements are recorded in [ADR-006](../adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md).

Nextcloud remains deferred unless collaboration requirements expand beyond oCIS. Backup and recovery scope is recorded in [ADR-007](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md).

## Implementation Status

The `wbappcloudr` oCIS service and its local filesystem paths now exist in repository configuration as of 2026-10-03. The container start, Authentik OIDC sign-in, account provisioning, file operations, backup, and restore have not been runtime-validated, so delivery remains pending. Nextcloud remains outside the current implementation.

## Consequences

- Adds identity, storage, sharing, backup, monitoring, upgrade, and recovery scope.
- Requires an implementation and validation plan before the capability is described as delivered.
- Keeps MinIO, OCI Object Storage, S3, and Nextcloud outside the initial scope.
- Requires revision of this RFC or a superseding ADR if the platform or storage decision changes.

## Delivery and Validation Criteria

- Document the supported family-file, sharing, synchronisation, and collaboration use cases.
- Validate Authentik OIDC sign-in, sign-out, authorisation, and break-glass access.
- Validate file synchronisation, sharing, mobile access, monitoring, upgrade, and rollback behaviour.
- Include oCIS configuration and file storage in the accepted backup strategy.
- Record implementation and runtime evidence before marking delivery complete.

## Related Documents

- [Product requirements](../requirements/PRD.md)
- [Roadmap](../requirements/ROADMAP.md)
- [Architecture](../architecture/ARCHITECTURE.md)
- [ADR-006 Adopt oCIS with Local Filesystem Storage](../adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md)
- [ADR-007 Adopt Dual-Target Backup and Disaster Recovery](../adr/ADR-007-adopt-dual-target-backup-and-recovery.md)
- [Backup and restore](../operations/BACKUP-RESTORE.md)
