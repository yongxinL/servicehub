# Nexora Project Scaffold

This directory is the full project scaffold for Nexora Governance v1.0 (`v1.0.0`). Its contents are copied into the root of every adopting project.

## Full-scaffold approach

Every approved documentation area, index, and template is copied into every project, so that every project has the same navigable shape and agents always find authority in the same places.

## Why all areas exist, and why creation stays proportional

Each directory contains a README that explains purpose, authority, triggers, and indexing. A directory with no artifacts is valid: its index states that no project artifacts have yet been created. Directory existence never makes artifact creation mandatory; artifacts are created only when their trigger applies (manual chapter 03).

## Scaffold contents

| Path | Role |
|---|---|
| [AGENTS.md](AGENTS.md) | Operational agent control document |
| [ADOPTION-INSTRUCTIONS.md](ADOPTION-INSTRUCTIONS.md) | Project-local adoption checklist and marker list |
| [CENTRAL-GOVERNANCE-REFERENCE.md](CENTRAL-GOVERNANCE-REFERENCE.md) | Pointer to the adopted central release |
| [SPEC-KIT-CONSTITUTION-TEMPLATE.md](SPEC-KIT-CONSTITUTION-TEMPLATE.md) | Temporary constitution reconciliation source |
| `opencode.json.example` | OpenCode v2 configuration example |
| `.codex/config.toml.example` | Codex configuration example |
| [docs/README.md](docs/README.md) | Documentation root index |

## What to customize

| File | Customize |
|---|---|
| `AGENTS.md` | Project name, commands, primary agent |
| `CENTRAL-GOVERNANCE-REFERENCE.md` | Central repository, version, tag |
| `docs/governance/governance-adoption.md` | All adoption fields |
| `docs/governance/source-of-truth-register.md` | Confirm locations; add project-specific categories |
| `docs/governance/approved-tooling.md` | Confirm or restrict the permitted tool list |
| `docs/governance/tooling-adoption-register.md` | Record actually configured tools |
| `docs/governance/documentation-exceptions.md` | Record any exceptions |
| `opencode.json.example` or `.codex/config.toml.example` | Create live configuration for the primary agent |

Customization markers use angle brackets, for example `<PROJECT_NAME>`. The full list and their meaning is in `ADOPTION-INSTRUCTIONS.md`.

## Copying hidden files

The scaffold contains a hidden directory (`.codex/`). Copy with a method that includes hidden files:

```bash
# Example
cp -a project-template/. <project-root>/
```

## Initializing Spec Kit

After customization, initialize Spec Kit at a pinned version with your primary agent's integration key (`specify init --here --integration <SPEC_KIT_INTEGRATION_KEY>`). This scaffold intentionally contains no `.specify/` or `specs/`; Spec Kit creates them.

## Reconciling the constitution

`SPEC-KIT-CONSTITUTION-TEMPLATE.md` is a temporary reconciliation source, not the active constitution. Reconcile it into the native constitution, approve it, then delete the template from the project root unless a documented reason to keep it is recorded in `docs/governance/documentation-exceptions.md`.

## Non-authoritative files

`docs/templates/*`, `docs/product/*-template.md`, `opencode.json.example`, `.codex/config.toml.example`, and `SPEC-KIT-CONSTITUTION-TEMPLATE.md` are non-authoritative. Authority arises only in artifacts created from them and approved.

## Validating adoption

Use the adoption review prompt (central `prompts/04-governance-adoption-review.md`) and the documentation validation prompt (`prompts/19-documentation-validation.md`). Target maturity for a new solo project is Level 1: Controlled.

This README may be kept as the scaffold's provenance note or removed after adoption; it is not a governed artifact.
