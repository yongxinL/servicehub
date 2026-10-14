<!--
Sync Impact Report
Version change: 1.0.0 → 1.0.0 (no version bump; principle replacement within same semantic level)
Modified principles: XVI–XXIV removed (ADR-derived detail principles); XVI added (ADR binding constraint)
Added sections: none
Removed sections: none
Follow-up TODOs: none
-->

# ServiceHub Constitution

## Core Principles

### I. Governance Precedence
This project is governed by the adopted Nexora Governance release recorded in `docs/governance/governance-adoption.md`. Where this constitution and the adopted release conflict, the release prevails until the conflict is resolved by owner decision.

### II. Specification Before Material Implementation
New or materially changed observable behaviour is specified and approved before implementation. Low-risk maintenance does not require a specification.

### III. Native Spec Kit Workflow Ownership
Spec Kit owns specify, clarify, plan, checklist, tasks, analyze, implement, and converge, and their artifacts. No parallel specification, plan, task, analysis, or completion system is used.

### IV. Stable Requirement Identifiers
Every specification carries a project-local `SPEC-NNN`; requirements use `SPEC-NNN-FR-NNN`, `SPEC-NNN-NFR-NNN`, and `SPEC-NNN-AC-NNN`. Identifiers are never reused.

### V. Single Source of Truth
Each information category has one authoritative location defined in `docs/governance/source-of-truth-register.md`.

### VI. Controlled Change
Approved specifications change only through an owner-approved change. Accepted decisions are superseded, not rewritten.

### VII. Verification Before Completion
Every material acceptance criterion is mapped to evidence before convergence. Work is complete only after convergence and owner acceptance.

### VIII. Git as Durable Project Memory
Decisions, approvals, and evidence summaries are committed. Conversation history is not project truth.

### IX. Human Project Owner Authority
Material approvals are made by the Project Owner. AI output is supporting input only.

### X. Least Privilege
Tools and agents receive the minimum access needed. Credentials never enter the repository.

### XI. Tool Authority Boundaries
Tool, MCP, index, and external documentation output never overrides governed artifacts.

### XII. No Silent Assumptions
Ambiguity, conflicts, and missing information are surfaced and resolved explicitly.

### XIII. No Competing Artifact Systems
No alternative specification store, plan hierarchy, task tracker, or completion record acts as authority.

### XIV. Simplicity and Maintainability
Prefer the simplest design that satisfies approved requirements; do not weaken requirements, tests, security, or recoverability for brevity.

### XV. Required Escalation
Implementation stops and escalates to the Project Owner on specification defects, scope expansion, security or data risk, missing rollback, or governance conflict.

## Project-Specific Principles

### XVI. Accepted Architecture Decisions Are Binding Constraints
Accepted ADRs in `docs/architecture/adr/` (see its index) are binding constraints on every specification and plan. A plan must state which Accepted ADRs it relies on and must comply with them. A plan that needs to depart from an Accepted ADR must stop and propose a superseding ADR for Project Owner decision before implementation. Proposed, Rejected, Deprecated and Superseded ADRs are not binding. The constitution does not restate ADR content; the ADR is the single source of truth for each decision.

## Governance

Amendments to this constitution are owner-approved, committed, and recorded with a version and date. The amendment procedure requires: (1) a proposed change with rationale, (2) owner review and approval, (3) commit to the repository with version increment per semantic versioning (MAJOR for backward-incompatible principle removals or redefinitions, MINOR for new or materially expanded principles, PATCH for clarifications and non-semantic refinements), and (4) update of the ratified/amended dates.

Compliance review expectations: all material changes to specifications, plans, tasks, ADRs, RFCs, or operational records must be verified against this constitution before acceptance. AI-assisted work must not bypass governed artifact locations or approval authorities.

**Version**: 1.0.0 | **Ratified**: 2026-10-13 | **Last Amended**: 2026-10-13
