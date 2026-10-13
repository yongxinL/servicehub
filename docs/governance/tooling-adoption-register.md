# Tooling Adoption Register

Records which tools are **actually configured or enabled** in this project. Each conditional tool requires an entry before use. Use the [tooling adoption entry template](../templates/tooling-adoption-entry-template.md).

## Summary

| Tool | Version | Scope | State | Entry |
|---|---|---|---|---|
| GitHub Spec Kit | `1.1.3` | Project | Enabled | TA-001 |
| Primary agent (`codex`) | `0.162.1` | User install, project config | Enabled | TA-002 |

States: Planned, Pilot, Enabled, Disabled, Removed. Removed entries remain listed.

## Entries

### TA-001: GitHub Spec Kit

| Field | Value |
|---|---|
| Purpose | SDD workflow owner |
| Official source | github.com/github/spec-kit, PyPI `specify-cli` |
| Version | `<SPEC_KIT_VERSION>` |
| Installation scope | User tool install; project files under `.specify/` and integration directories |
| Integration | `<SPEC_KIT_INTEGRATION_KEY>` |
| Extensions enabled | None |
| Data transmission | None during normal workflow beyond the agent's own model calls |
| Credentials | None |
| Removal | Uninstall CLI; native artifacts remain as governed history |

### TA-002: Primary agent

| Field | Value |
|---|---|
| Agent | `<PRIMARY_AGENT>` |
| Version | Record installed version |
| Project configuration | `opencode.json` or `.codex/config.toml` |
| User configuration | Not committed |
| Enabled MCP servers | None |
| Credentials | Provider credentials in user scope only |
| Removal | Remove project configuration; record agent switch per central chapter 19 |
