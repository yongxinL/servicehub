---
project: ServiceHub
project_code: SVCHUB
document_type: RELEASE
document_id: RELEASE-TEMPLATE
title: Release Template
version: "1.1"
status: Draft
lifecycle_stage: Release
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - release
  - template
related_documents:
  - RELEASE-INDEX
  - TEST-001
---

# Release Template

> Guidance: replace every `TBD`, remove this note, update metadata, and link actual evidence before approval. Do not mark `Completed` without executed tests and deployment validation.

## Release Identity

| Field | Value |
|---|---|
| Version | TBD |
| Git tag | TBD |
| Commit | TBD |
| Release date | TBD |
| Owner | TBD |
| Status | Draft |

## Summary

Describe the release purpose and user-visible changes.

## Changes

- Added: TBD
- Changed: TBD
- Fixed: TBD
- Removed: TBD

## Upgrade and Migration

Describe pre-upgrade backup, ordered steps, compatibility, verification, downtime, and irreversible changes.

## Test Evidence

Link the executed test report, environment, commit, tester, date, and deviations.

## Deployment Evidence

Link the workflow or deployment record for the target environment.

## Rollback

Describe rollback steps, data limitations, decision owner, and validation.

## Post-Release Validation

Record health, routes, TLS, authentication, databases, affected AI paths, telemetry, and backup checks.

## Known Issues

- TBD

## Approval

| Role | Name | Date | Decision |
|---|---|---|---|
| Owner | TBD | TBD | TBD |
| Technical reviewer | TBD | TBD | TBD |

## Related Documents

- [Release register](../releases/README.md)
- [Test register](../testing/README.md)
- [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md)

