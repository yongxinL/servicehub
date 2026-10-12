# Spec Kit Constitution Reconciliation Template (Nexora Governance v1.0)

> **Temporary reconciliation source - not the active constitution.** After Spec Kit initialization, provide these principles to the native constitution command, keep only what is true for or explicitly adopted by this project, have the Project Owner approve the native constitution, then delete this file (unless a documented reason to retain it is recorded in `docs/governance/documentation-exceptions.md`).

## Principles

### I. Nexora governance precedence
This project is governed by the adopted Nexora Governance release recorded in `docs/governance/governance-adoption.md`. Where this constitution and the adopted release conflict, the release prevails until the conflict is resolved by owner decision.

### II. Specification before material implementation
New or materially changed observable behaviour is specified and approved before implementation. Low-risk maintenance does not require a specification.

### III. Native Spec Kit workflow ownership
Spec Kit owns specify, clarify, plan, checklist, tasks, analyze, implement, and converge, and their artifacts. No parallel specification, plan, task, analysis, or completion system is used.

### IV. Stable requirement identifiers
Every specification carries a project-local `SPEC-NNN`; requirements use `SPEC-NNN-FR-NNN`, `SPEC-NNN-NFR-NNN`, and `SPEC-NNN-AC-NNN`. Identifiers are never reused.

### V. Single source of truth
Each information category has one authoritative location defined in `docs/governance/source-of-truth-register.md`.

### VI. Controlled change
Approved specifications change only through an owner-approved change. Accepted decisions are superseded, not rewritten.

### VII. Verification before completion
Every material acceptance criterion is mapped to evidence before convergence. Work is complete only after convergence and owner acceptance.

### VIII. Git as durable project memory
Decisions, approvals, and evidence summaries are committed. Conversation history is not project truth.

### IX. Human Project Owner authority
Material approvals are made by the Project Owner. AI output is supporting input only.

### X. Least privilege
Tools and agents receive the minimum access needed. Credentials never enter the repository.

### XI. Tool authority boundaries
Tool, MCP, index, and external documentation output never overrides governed artifacts.

### XII. No silent assumptions
Ambiguity, conflicts, and missing information are surfaced and resolved explicitly.

### XIII. No competing artifact systems
No alternative specification store, plan hierarchy, task tracker, or completion record acts as authority.

### XIV. Simplicity and maintainability
Prefer the simplest design that satisfies approved requirements; do not weaken requirements, tests, security, or recoverability for brevity.

### XV. Required escalation
Implementation stops and escalates to the Project Owner on specification defects, scope expansion, security or data risk, missing rollback, or governance conflict.

## Project-specific additions

Add only principles the project has explicitly adopted (for example compatibility guarantees, technology constraints recorded in ADRs, or testing standards already enforced in CI). Do not invent standards to fill the constitution.

## Governance

Amendments to the native constitution are owner-approved, committed, and recorded with a version and date as supported by the native template.
