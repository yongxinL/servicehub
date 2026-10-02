---
project: ServiceHub
project_code: SVCHUB
document_type: RELEASE-INDEX
document_id: RELEASE-INDEX
title: ServiceHub Release Register
version: "1.0"
status: Active
lifecycle_stage: Release
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - releases
  - governance
  - index
related_documents:
  - TEST-001
  - DEPLOYMENT-ARCHITECTURE
---

# ServiceHub Release Register

The repository currently contains no Git tags and no release records. This register therefore contains only a template; it does not invent historical releases.

| ID | Version | Status | Date | Evidence | Link |
|---|---|---|---|---|---|
| RELEASE-TEMPLATE | `TBD` | Draft | `TBD` | Template only | [Release template](RELEASE-TEMPLATE.md) |

## Semantic Versioning

Use SemVer for governed releases:

- **Major:** incompatible service, data, configuration, or migration changes.
- **Minor:** backward-compatible capabilities or material operational changes.
- **Patch:** backward-compatible fixes and documentation corrections.

Pre-release labels such as `-rc.1` may be used before acceptance. Dates must come from actual Git or Forgejo release evidence.

## Release Page Naming

Use `vMAJOR.MINOR.PATCH` for the tag and release title. The release note filename should follow `RELEASE-vMAJOR.MINOR.PATCH.md` when a real release record is created.

## Required Release Evidence

- Unique version and commit.
- Approved change summary and migration notes.
- Executed test evidence with environment and commit.
- Known issues and deviations.
- Backup availability or an explicit exception.
- Deployment record.
- Post-release validation.
- Owner approval record.

## Tags and Release Notes

A tag identifies an immutable commit. Release notes explain user-visible changes, upgrade steps, migration requirements, rollback conditions, and evidence. Do not create a tag or release page without the corresponding evidence.

## Migration Documentation

Every release requiring data, schema, environment, certificate, or configuration migration must describe:

- Pre-upgrade backup.
- Ordered migration steps.
- Compatibility window.
- Verification queries or checks.
- Expected downtime.
- Rollback limitations.

## Rollback Requirements

Define how the previous version is recovered, how migrations are reversed or avoided, and which data changes are irreversible. No current rollback procedure is verified.

## Post-Release Validation

After deployment, verify container health, routes, TLS, authentication, database connectivity, AI routing where affected, metrics, logs, and backup status. Record the evidence before marking the release `Completed`.

## Creating a Release Record

1. Confirm the next unused version.
2. Copy [RELEASE-TEMPLATE.md](RELEASE-TEMPLATE.md).
3. Use the filename `RELEASE-vMAJOR.MINOR.PATCH.md`.
4. Attach test and deployment evidence.
5. Create the matching Git tag only after approval.
6. Add the record to this register.

