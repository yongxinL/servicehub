# Adoption Instructions

Project-local adoption checklist for Nexora Governance v1.0 (`v1.0.0`). The complete procedure is owned by central manual chapter 30; this file sequences it for this repository.

## 1. Install the full scaffold

Copy every file from the central `project-template/` into the project root, including `.codex/`. Do not omit directories that seem unused; their indexes are part of the scaffold.

## 2. Customize

Replace customization markers:

| Marker | Meaning | Where to supply it |
|---|---|---|
| `<PROJECT_NAME>` | Project name | `AGENTS.md`, `governance-adoption.md` |
| `<PROJECT_OWNER>` | Named Project Owner | `governance-adoption.md` only |
| `<CENTRAL_GOVERNANCE_REPOSITORY>` | URL of the central governance repository | `CENTRAL-GOVERNANCE-REFERENCE.md`, `governance-adoption.md` |
| `<ADOPTION_DATE>` | `YYYY-MM-DD` | `governance-adoption.md` |
| `<PRIMARY_AGENT>` | `opencode` or `codex` | `governance-adoption.md` |
| `<SPEC_KIT_INTEGRATION_KEY>` | Spec Kit integration key matching the primary agent | `governance-adoption.md` |
| `<SPEC_KIT_VERSION>` | Pinned Spec Kit release tag | `tooling-adoption-register.md` |
| `<OPENCODE_VERSION>` | Installed OpenCode version (v2 format) | `tooling-adoption-register.md` |
| `<CONTEXT7_AUTH_MODE>` | `api-key` or `oauth` | `tooling-adoption-register.md` |
| `<PLAYWRIGHT_MCP_VERSION>` | Pinned Playwright MCP version | Configuration, register |
| `<SECRET_STORE>` | Name of the secret store or environment mechanism | `source-of-truth-register.md` |
| `<PROJECT_TEST_COMMAND>`, `<PROJECT_BUILD_COMMAND>`, `<PROJECT_LINT_COMMAND>` | Real project commands | `AGENTS.md` |

If a value is not yet known, leave the marker and record why in the adoption record's notes. Never invent values.

## 3. Central governance reference

Record the central repository, version `1.0.0`, and immutable tag `v1.0.0`. Never reference the central default branch.

## 4. Solo-owner mode

Governance mode defaults to `solo`. Record the Project Owner once in `governance-adoption.md`; artifacts use `owner: project-owner`.

## 5. Approved exceptions

Record any exception in `docs/governance/documentation-exceptions.md` with all required fields. Exceptions cannot waive non-exception controls.

## 6. Environment configuration

- OpenCode: copy `opencode.json.example` to `opencode.json` (v2 format).
- Codex: copy `.codex/config.toml.example` to `.codex/config.toml`; trust the project only after review.
- Delete the example for the agent you do not use, or keep it if a secondary agent is configured.
- Keep conditional tools disabled; store credentials in the environment or a secret store.

## 7. Spec Kit initialization

Install Spec Kit at a pinned version and run `specify init --here --integration <SPEC_KIT_INTEGRATION_KEY>`. Review the diff. If `--force` is needed, commit first.

## 8. Constitution reconciliation

Reconcile `SPEC-KIT-CONSTITUTION-TEMPLATE.md` into the native constitution, approve it, and delete the template.

## 9. Baseline commits

Example sequence: `docs: establish Nexora project governance scaffold`, `docs(product): define product vision and requirements`, `docs(spec): approve project constitution`.

## 10. First specification

Allocate `SPEC-001` in the specification index when the first material change is specified through the native workflow.

## 11. Adoption validation

Run central prompts 04 and 19. Set the adoption state accordingly.

## 12. Existing-project safeguards

Work on an adoption branch from a recorded commit. Add the scaffold without moving legacy documents. Audit read-only first. Resolve authority before moving anything. Never use `--force` initialization without a baseline commit.
