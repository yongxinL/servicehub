# Archive

## Purpose
Holds legacy documentation displaced during migration, retired documentation sets, obsolete formats, and historical material that no longer belongs in an active area.

## Authority
Nothing in the archive is current authority. Completed ADRs, RFCs, investigations, specifications, lessons, and releases are **not** archived; they stay in their canonical locations. Owning chapter: central manual 28.

## Artifact triggers
Migration batches that displace legacy content, retirement of a documentation set, or format obsolescence, each approved by the owner.

## Naming and identifiers
Preserve original filenames under a dated subfolder, for example `YYYY-MM-<origin>/` (illustrative).

## Status expectations
Archived items carry no lifecycle status.

## Index

| Item | Origin path | Archived on | Reason | Replacement |
|---|---|---|---|---|
| [ADR-TEMPLATE.md](2026-10-legacy-templates/ADR-TEMPLATE.md) | `docs/templates/ADR-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [adr-template.md](../templates/adr-template.md) |
| [INVESTIGATION-TEMPLATE.md](2026-10-legacy-templates/INVESTIGATION-TEMPLATE.md) | `docs/templates/INVESTIGATION-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [investigation-template.md](../templates/investigation-template.md) |
| [LESSON-TEMPLATE.md](2026-10-legacy-templates/LESSON-TEMPLATE.md) | `docs/templates/LESSON-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [lesson-learned-template.md](../templates/lesson-learned-template.md) |
| [PHASE-TEMPLATE.md](2026-10-legacy-templates/PHASE-TEMPLATE.md) | `docs/templates/PHASE-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template with no lower-case replacement | Native plans or [cross-specification-delivery-plan-template.md](../templates/cross-specification-delivery-plan-template.md) |
| [RELEASE-TEMPLATE.md](2026-10-legacy-templates/RELEASE-TEMPLATE.md) | `docs/templates/RELEASE-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [release-template.md](../templates/release-template.md) |
| [RFC-TEMPLATE.md](2026-10-legacy-templates/RFC-TEMPLATE.md) | `docs/templates/RFC-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [rfc-template.md](../templates/rfc-template.md) |
| [TEST-TEMPLATE.md](2026-10-legacy-templates/TEST-TEMPLATE.md) | `docs/templates/TEST-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [test-plan-template.md](../templates/test-plan-template.md) |
| [RELEASE-TEMPLATE-from-releases.md](2026-10-legacy-templates/RELEASE-TEMPLATE-from-releases.md) | `docs/releases/RELEASE-TEMPLATE.md` | 2026-10-12 | Legacy upper-case release template | [release-template.md](../templates/release-template.md) |

## Relationship to other artifacts
Every archived item links to its replacement where one exists.

## Current scaffold state
Eight legacy templates are indexed.
