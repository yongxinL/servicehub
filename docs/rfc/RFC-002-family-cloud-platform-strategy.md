---
project: ServiceHub
project_code: SVCHUB
document_type: RFC
document_id: RFC-002
title: Family Cloud Platform Strategy
version: "1.0"
status: Proposed
lifecycle_stage: Ideation
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - family-cloud
  - files
  - strategy
related_documents:
  - CHARTER-001
  - ARCHITECTURE
  - ROADMAP-001
---

# RFC-002: Family Cloud Platform Strategy

## Summary

Decide whether ServiceHub needs a dedicated family file-cloud platform, and if so which option should be piloted. No file-cloud service is currently included in the default architecture.

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
- **Fit:** proposed default while no validated requirement exists.

### Lightweight File Management

Use a small file manager or existing application storage rather than a full sync platform.

- **Benefits:** lower operational overhead.
- **Costs:** weak mobile synchronisation, sharing, versioning, and offline access.
- **Fit:** suitable only if requirements remain limited to basic browsing or upload.

### oCIS / ownCloud Infinite Scale

Pilot oCIS as a cloud-native file platform with OIDC and storage integrations.

- **Benefits:** modern file synchronisation, sharing, and potential extension points.
- **Costs:** new identity integration, storage layout, backup, upgrade, monitoring, and mobile testing.
- **Fit:** preferred pilot candidate if a real file synchronisation or family sharing requirement emerges.

### Nextcloud

Adopt Nextcloud as a broader family collaboration suite.

- **Benefits:** mature synchronisation, sharing, mobile clients, and extensive applications.
- **Costs:** larger application surface, plug-in and upgrade management, and potentially higher resource use.
- **Fit:** candidate if calendar, collaboration, office, or application breadth becomes a requirement beyond file synchronisation.

## Evaluation Matrix

| Criterion | No platform | Lightweight | oCIS | Nextcloud |
|---|---|---|---|---|
| Authentik OIDC | Not applicable | Limited or app-specific | Pilot required | Pilot required |
| Family file storage | No new platform | Basic | Yes | Yes |
| File synchronisation | No | Weak | Yes | Yes |
| Mobile access | No | Limited | Requires validation | Requires validation |
| External sharing | Outside scope | Limited | Requires policy and test | Requires policy and test |
| Backup and recovery | Existing platform only | Existing platform only | New scope | New scope |
| Monitoring | Existing platform only | Existing platform only | New scope | New scope |
| Operational overhead | Lowest | Low | Moderate | Moderate to high |
| AI or RAG access | None | Manual | Requires pilot | Requires pilot |

The matrix expresses proposed evaluation criteria, not tested product results.

## Proposed Decision

Defer deployment until a validated file synchronisation or family file-sharing requirement exists.

If that requirement emerges, conduct a pilot of oCIS before production adoption. Evaluate Nextcloud only if the requirement expands beyond oCIS's expected scope.

## Implementation Status

oCIS, ownCloud Infinite Scale, and Nextcloud are **not** implemented in the current ServiceHub architecture.

## Consequences

- Avoids speculative infrastructure and recovery scope.
- Delays integrated family file services.
- Requires a new RFC update or decision record if the requirement changes.
- A future pilot must include identity, mobile, sharing, backup, monitoring, and AI-access tests.

## Acceptance Criteria for Reopening

- A named user group and use case require repository-managed family files.
- Synchronisation, sharing, mobile, recovery, and monitoring expectations are written down.
- Resource and operational ownership are assigned.
- A pilot environment and success criteria are approved.

## Related Documents

- [Product requirements](../requirements/PRD.md)
- [Roadmap](../requirements/ROADMAP.md)
- [Architecture](../architecture/ARCHITECTURE.md)

