# Templates

## Purpose
Non-authoritative starting points for governed artifacts. Templates are never authority; authority arises only in artifacts created from them and approved.

## Authority
Owning chapter: central manual 16 (metadata) and the chapter that owns each artifact type.

## Artifact triggers
Use a template only when the artifact's trigger applies. Copy it to the canonical location, rename it, and allocate the identifier in the area index.

## Naming and identifiers
Template files end in `-template.md`. Target names are given in each template.

## Status expectations
Each template starts at the initial status for its type; templates never claim approval or completion.

## Index

| Template | Creates | Target location | Owning chapter |
|---|---|---|---|
| [adr-template.md](adr-template.md) | ADR | `docs/architecture/adr/` | 09 |
| [rfc-template.md](rfc-template.md) | RFC | `docs/rfc/` | 10 |
| [investigation-template.md](investigation-template.md) | Investigation | `docs/investigations/` | 11 |
| [cross-specification-delivery-plan-template.md](cross-specification-delivery-plan-template.md) | Delivery plan | `docs/architecture/` | 12 |
| [test-plan-template.md](test-plan-template.md) | Test plan | `docs/testing/` | 13 |
| [verification-summary-template.md](verification-summary-template.md) | Verification summary | Native feature directory or `docs/testing/` | 13 |
| [runbook-template.md](runbook-template.md) | Runbook | `docs/operations/runbooks/` | 15 |
| [release-template.md](release-template.md) | Release record | `docs/releases/` | 14 |
| [lesson-learned-template.md](lesson-learned-template.md) | Lesson | `docs/lessons/` | 11 |
| [tooling-adoption-entry-template.md](tooling-adoption-entry-template.md) | Register entry | `docs/governance/tooling-adoption-register.md` | 20 |
| [temporary-work-handoff-template.md](temporary-work-handoff-template.md) | Temporary handoff | Working branch root | 19 |

Product templates live in [../product/](../product/README.md). **No specification template is provided:** specifications are created with the native Spec Kit specify command and its native template. No phase template is provided; use native plans or the delivery-plan template.

## Relationship to other artifacts
Conventions common to all templates: *Mandatory* sections must be completed; *Optional* sections may be deleted; italic guidance is removed once written; example content is labelled "Example (illustrative only)".

## Current scaffold state
All eleven templates present.
