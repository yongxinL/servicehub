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
| [README.md](2026-10-legacy-adr-index/README.md) | `docs/adr/README.md` | 2026-10-12 | ADR index migrated to architecture/adr/ | [adr/README.md](../architecture/adr/README.md) |
| [INVESTIGATION-TEMPLATE.md](2026-10-legacy-templates/INVESTIGATION-TEMPLATE.md) | `docs/templates/INVESTIGATION-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [investigation-template.md](../templates/investigation-template.md) |
| [LESSON-TEMPLATE.md](2026-10-legacy-templates/LESSON-TEMPLATE.md) | `docs/templates/LESSON-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [lesson-learned-template.md](../templates/lesson-learned-template.md) |
| [PHASE-TEMPLATE.md](2026-10-legacy-templates/PHASE-TEMPLATE.md) | `docs/templates/PHASE-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template with no lower-case replacement | Native plans or [cross-specification-delivery-plan-template.md](../templates/cross-specification-delivery-plan-template.md) |
| [RELEASE-TEMPLATE.md](2026-10-legacy-templates/RELEASE-TEMPLATE.md) | `docs/templates/RELEASE-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [release-template.md](../templates/release-template.md) |
| [RFC-TEMPLATE.md](2026-10-legacy-templates/RFC-TEMPLATE.md) | `docs/templates/RFC-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [rfc-template.md](../templates/rfc-template.md) |
| [TEST-TEMPLATE.md](2026-10-legacy-templates/TEST-TEMPLATE.md) | `docs/templates/TEST-TEMPLATE.md` | 2026-10-12 | Legacy upper-case template | [test-plan-template.md](../templates/test-plan-template.md) |
| [RELEASE-TEMPLATE-from-releases.md](2026-10-legacy-templates/RELEASE-TEMPLATE-from-releases.md) | `docs/releases/RELEASE-TEMPLATE.md` | 2026-10-12 | Legacy upper-case release template | [release-template.md](../templates/release-template.md) |
| [CHARTER.md](2026-10-product-intent/CHARTER.md) | `docs/charter/CHARTER.md` | 2026-10-12 | Product intent restructured into vision.md and requirements.md | [vision.md](../product/vision.md), [requirements.md](../product/requirements.md) |
| [PRD.md](2026-10-product-intent/PRD.md) | `docs/requirements/PRD.md` | 2026-10-12 | Product intent restructured into vision.md and requirements.md | [vision.md](../product/vision.md), [requirements.md](../product/requirements.md) |
| [ROADMAP.md](2026-10-delivery-plan/ROADMAP.md) | `docs/requirements/ROADMAP.md` | 2026-10-12 | Delivery plan consolidated into delivery-plan-servicehub-platform.md | [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) |
| [README.md](2026-10-delivery-plan/README.md) | `docs/phases/README.md` | 2026-10-12 | Phase register consolidated into delivery-plan-servicehub-platform.md | [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) |
| [PHASE-001-platform-foundation.md](2026-10-delivery-plan/PHASE-001-platform-foundation.md) | `docs/phases/PHASE-001-platform-foundation.md` | 2026-10-12 | Phase consolidated into delivery-plan-servicehub-platform.md | [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) |
| [PHASE-002-identity-and-developer-services.md](2026-10-delivery-plan/PHASE-002-identity-and-developer-services.md) | `docs/phases/PHASE-002-identity-and-developer-services.md` | 2026-10-12 | Phase consolidated into delivery-plan-servicehub-platform.md | [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) |
| [PHASE-003-ai-platform.md](2026-10-delivery-plan/PHASE-003-ai-platform.md) | `docs/phases/PHASE-003-ai-platform.md` | 2026-10-12 | Phase consolidated into delivery-plan-servicehub-platform.md | [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) |
| [PHASE-004-observability-and-operational-hardening.md](2026-10-delivery-plan/PHASE-004-observability-and-operational-hardening.md) | `docs/phases/PHASE-004-observability-and-operational-hardening.md` | 2026-10-12 | Phase consolidated into delivery-plan-servicehub-platform.md | [delivery-plan-servicehub-platform.md](../architecture/delivery-plan-servicehub-platform.md) |

## Relationship to other artifacts
Every archived item links to its replacement where one exists.

## Current scaffold state
Eight legacy templates, eight product/planning documents, and the legacy ADR index are indexed.
