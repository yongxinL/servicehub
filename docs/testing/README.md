# Testing

## Purpose
Project-wide test strategy and cross-feature verification evidence.

## Authority
Authoritative for project-wide test strategy, compatibility matrices, project-wide security and performance evidence, and reusable manual verification procedures. Feature-specific evidence stays with native Spec Kit artifacts; release-level evidence stays in release records. Tests never redefine requirements. Owning chapter: central manual 13.

## Artifact triggers
Create the test strategy when the first material feature is planned. Add cross-feature verification summaries, compatibility matrices, or a consolidated traceability matrix only when justified.

## Naming and identifiers
`test-strategy.md`; `test-plan-<kebab-title>.md`; `verification-<kebab-title>-YYYY-MM-DD.md`. No governed identifiers.

## Status expectations
Test plans: Draft, Approved, Superseded. Verification summaries record a result (Passed, Passed with deviations, Failed).

## Index

| Document | Type | Status or result | Updated |
|---|---|---|---|
| [TEST-001](TEST-001-platform-baseline-validation.md) | Test plan | Not Executed | 2026-10-08 |

## Relationship to other artifacts
Maps evidence to `SPEC-NNN-AC-NNN` and `SPEC-NNN-NFR-NNN`. Templates: [../templates/test-plan-template.md](../templates/test-plan-template.md), [../templates/verification-summary-template.md](../templates/verification-summary-template.md).

## Current scaffold state
One test plan is indexed.
