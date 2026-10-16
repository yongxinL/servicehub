# Architecture

## Purpose
Summarizes the current architecture of ServiceHub and links the decisions that shape it. Also indexes cross-specification delivery plans.

## Authority
This overview is authoritative for the current architectural summary. Detailed decisions are authoritative in ADRs ([adr/README.md](adr/README.md)). Owning chapters: central manual 09 and 12.

## Artifact triggers
Update the overview when an ADR is accepted or superseded, or when a structural change is released. Create a delivery plan only for work spanning multiple specifications, releases, or systems, migrations, infrastructure transitions, coordinated deprecations, or governance adoption.

## Naming and identifiers
Delivery plans: `delivery-plan-<kebab-title>.md` (no governed identifier). ADRs: see the ADR index.

## Status expectations
Delivery plans use the specification status vocabulary (Draft, In Review, Approved, In Implementation, Implemented, Verified, Superseded, Withdrawn), per central manual chapter 16.

## Architecture overview

| Document | Type | Status | Updated |
|---|---|---|---|
| [ARCHITECTURE](ARCHITECTURE.md) | Architecture overview | Draft | 2026-10-17 |
| [COMPONENT-CATALOGUE](COMPONENT-CATALOGUE.md) | Component catalogue | Draft | 2026-10-07 |
| [DATA-FLOW](DATA-FLOW.md) | Data-flow diagram | Draft | 2026-10-10 |
| [DEPLOYMENT-ARCHITECTURE](DEPLOYMENT-ARCHITECTURE.md) | Deployment architecture | Draft | 2026-10-17 |
| [SYSTEM-CONTEXT](SYSTEM-CONTEXT.md) | System-context diagram | Draft | 2026-10-08 |
| [ADR index](adr/README.md) | ADR index | Not recorded | Not recorded |

## Cross-specification delivery plans

| Plan | Status | Participating specifications | Updated |
|---|---|---|---|
| [Governance adoption](delivery-plan-governance-adoption.md) | Approved | Not recorded | 2026-10-12 |
| [ServiceHub platform](delivery-plan-servicehub-platform.md) | Draft | PHASE-001, PHASE-002, PHASE-003, PHASE-004 (archived) | 2026-10-13 |

## Relationship to other artifacts
Native feature plans in `specs/` are not indexed here. Template: [../templates/cross-specification-delivery-plan-template.md](../templates/cross-specification-delivery-plan-template.md).

## Current scaffold state
Five architecture documents, the canonical ADR index, the governance-adoption delivery plan, and the ServiceHub platform delivery plan are indexed; native feature plans are not initialized.
