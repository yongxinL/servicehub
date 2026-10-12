# AGENTS.md - <PROJECT_NAME>

Operational instructions for AI coding agents. This file is concise by design and does not replace any governed artifact.

## Governance precedence

1. Nexora non-exception controls (no competing sources of truth, no secrets, human approval only, repository as memory, no silent spec change, no invented decisions).
2. Adopted Nexora Governance release: see `CENTRAL-GOVERNANCE-REFERENCE.md` and `docs/governance/governance-adoption.md`.
3. Project governance records in `docs/governance/` and approved exceptions.
4. The approved native Spec Kit constitution.
5. Approved product requirements, specifications, accepted ADRs and RFCs.
6. This file and any nested `AGENTS.md` (operational only; cannot weaken the above).
7. Tool, MCP, and AI output (never authoritative).

## Authoritative locations

See `docs/governance/source-of-truth-register.md`. In summary: product intent `docs/product/`; specifications, plans, tasks `specs/` (Spec Kit native); constitution and bug records `.specify/`; ADRs `docs/architecture/adr/`; RFCs `docs/rfc/`; investigations `docs/investigations/`; releases `docs/releases/`; runbooks `docs/operations/runbooks/`.

## Required reading before material work

`docs/governance/governance-adoption.md`, `docs/governance/source-of-truth-register.md`, the native constitution, the applicable specification, plan, and tasks, constraining ADRs, and `docs/governance/approved-tooling.md`.

## Spec Kit ownership

GitHub Spec Kit owns specify, clarify, plan, checklist, tasks, analyze, implement, and converge, and their artifacts. Do not create competing specifications, plans, task lists, analysis, or completion records. Do not relocate or rename native artifacts. Primary agent and active integration: see `docs/governance/governance-adoption.md`.

## Tool boundaries

Use only tools enabled in `docs/governance/tooling-adoption-register.md`. Never install or enable tools yourself. Do not send proprietary code, credentials, or personal data to remote tools. Tool output is not authority.

## Prohibited actions

- Committing credentials or sensitive data.
- Changing approved specifications, accepted ADRs, or approved records without owner instruction.
- Performing material status transitions (Approved, Accepted, Verified, Released).
- Pushing to protected branches, merging, tagging, releasing, deploying, publishing, or deleting without owner authorization.
- Running `speckit.bug.fix` without owner authorization of the assessment.
- Treating conversation history as project truth.

## Escalation: stop and report when

The specification is wrong, ambiguous, or conflicts with other authority; scope must expand; a security, data, or destructive risk appears; a tool or credential is missing; tests cannot run; rollback is missing; or an instruction conflicts with governance.

## Validation

- Test: `<PROJECT_TEST_COMMAND>`
- Build: `<PROJECT_BUILD_COMMAND>`
- Lint: `<PROJECT_LINT_COMMAND>`

Report which commands ran and their results. Never claim a check passed that was not run.

## Completion rules

Work is complete only after native convergence and Project Owner acceptance. Agents report readiness and remaining gaps; they do not declare completion.

## Owner approval

Material approvals are given only by the Project Owner (`docs/governance/governance-adoption.md`). AI review is supporting input, never approval.

<!-- Spec Kit may add a managed block below this line. It is non-authoritative and contains pointers only; do not hand-edit it or place Nexora content inside it. -->
