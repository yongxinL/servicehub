---
project: ServiceHub
project_code: SVCHUB
document_type: HOME
document_id: HOME-001
title: ServiceHub Project Documentation
version: "1.1"
status: Active
lifecycle_stage: Continuous Improvement
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-03
tags:
  - servicehub
  - documentation
  - governance
related_documents:
  - CHARTER-001
  - PRD-001
  - ARCHITECTURE
---

# ServiceHub Project Documentation

This directory is the authoritative documentation set for ServiceHub. It records project intent, architecture decisions, implementation evidence, operational guidance, tests, releases, lessons, and unresolved work for developers, HomeLab administrators, Forgejo reviewers, coding agents, planning workflows, and future static-site publishing.

The repository implementation remains the source of truth. Documentation describes repository evidence; it does not replace configuration, workflows, scripts, or service code.

## Documentation Principles

- **Confirmed:** directly supported by repository files or Git history.
- **Inferred:** reasonably derived from the current implementation.
- **Proposed:** recommended but not implemented or approved.
- **TBD:** requires owner input, runtime validation, or evidence outside this repository.
- Keep secrets out of documentation. Document variable names only.
- Update documentation in the same change as the implementation it describes.
- Preserve stable document IDs and correct all index records when adding a document.
- Use relative repository links so Forgejo, agents, and future MkDocs builds work without a special base URL.
- Do not use the Forgejo Wiki or Confluence as the source of truth. External systems should link here.

## Documentation Map

| Section | Purpose | Entry point |
|---|---|---|
| Charter | Project intent, boundaries, governance, and success criteria | [Project Charter](charter/CHARTER.md) |
| Requirements | Product requirements and phased roadmap | [PRD](requirements/PRD.md), [Roadmap](requirements/ROADMAP.md) |
| Architecture | Current system model, components, data flows, and deployment | [Architecture index](architecture/README.md) |
| ADRs | Accepted implementation decisions and their trade-offs | [ADR register](adr/README.md) |
| RFCs | Significant proposals awaiting a decision | [RFC register](rfc/README.md) |
| Phases | Development and validation phases | [Phase register](phases/README.md) |
| Testing | Test plans, reports, and execution evidence | [Test register](testing/README.md) |
| Releases | Release governance, evidence, and notes | [Release register](releases/README.md) |
| Operations | Runbooks, inventory, backup, monitoring, and troubleshooting | [Operations index](operations/README.md) |
| Products | Per-product build, configuration, and setup guides | [Products](products/README.md) |
| Development | Developer workflows: git-crypt, local dev flow, contributing | [Development](operations/development/DEVELOPMENT.md) |
| Lessons | Retrospective learning and improvement actions | [Lessons register](lessons/README.md) |
| Investigations | Technical findings and open questions | [Investigation register](investigations/README.md) |
| Templates | Reusable record formats | [Templates](templates/ADR-TEMPLATE.md) |

## Authoritative and Proposed Content

Repository files under `compose/`, `shared/`, `scripts/`, `.forgejo/`, and the root configuration are authoritative for implementation. Architecture documents explain that evidence. Requirements, RFCs, phase acceptance, recovery objectives, alert ownership, and release decisions may remain proposed or TBD until reviewed.

Retrospective architecture decisions are labelled `Accepted` with `decision_basis: Inferred from current implementation`. This records the decision embodied by the code; it does not imply a historical approval process.

## Document Types and IDs

Each document has YAML front matter with a stable `document_id`. Indexes use IDs such as `ADR-INDEX`, `RFC-INDEX`, and `PHASE-INDEX`. Records use IDs such as `ADR-001`, `RFC-001`, `PHASE-001`, `TEST-001`, `LESSON-001`, and `INV-001`.

Use these document types:

`HOME`, `CHARTER`, `PRD`, `ROADMAP`, `ARCHITECTURE`, `ADR-INDEX`, `ADR`, `RFC-INDEX`, `RFC`, `PHASE-INDEX`, `PHASE`, `TEST-INDEX`, `TEST`, `RELEASE-INDEX`, `RELEASE`, `OPS-INDEX`, `OPS`, `LESSON-INDEX`, `LESSON`, `INVESTIGATION-INDEX`, `INVESTIGATION`, and `TEMPLATE`.

## Status Conventions

Allowed statuses are `Draft`, `Proposed`, `In Review`, `Accepted`, `Rejected`, `Active`, `Completed`, `Superseded`, `Deprecated`, `Archived`, and `Not Executed`.

- `Active` is used for live indexes and this documentation home.
- `Proposed` is used for recommendations awaiting a decision.
- `Draft` is used for records awaiting owner or technical review.
- `Accepted` is used for approved design decisions; each record must state whether implementation and runtime evidence exist.
- `Completed` is used only when completion evidence exists.
- `Not Executed` is used for test plans without reliable execution evidence.

## Contributing

See [Contributing](../operations/development/DEVELOPMENT.md#contributing) in the development workflows guide.

## Repository Links

- Root project overview: [README.md](../README.md)
- Coding and documentation guidance: [AGENTS.md](../AGENTS.md)
- Environment template: [env.example](../env.example)
- Main Compose definition: [docker-compose.yml](../docker-compose.yml)
