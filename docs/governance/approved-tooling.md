# Approved Tooling

Defines which tools are **permitted** in this project. Whether a tool is actually configured is recorded in [tooling-adoption-register.md](tooling-adoption-register.md). Permission does not mean a tool is enabled.

Baseline: Nexora Governance v1.0 default tool profile (central chapter 20), verified 2026-10-12.

| Tool | Permission | Conditions |
|---|---|---|
| Git, search, shell, language, build, and test tools | Approved core | Least privilege; no production credentials |
| GitHub Spec Kit (`specify-cli`) | Approved core workflow owner | Pinned version; official channel |
| Spec Kit `git` extension | Approved when relevant | Register entry |
| Spec Kit `bug` extension | Approved when relevant | Limits B1-B9 (central chapter 07) |
| Spec Kit `bugfix` bundle and workflow | Not approved (candidate) | Future minor release |
| Spec Kit `assess` extension | Not approved (candidate) | Use investigations and RFCs |
| Community Spec Kit `bugfix` extension | Prohibited | Patches specifications outside change control |
| Other community Spec Kit extensions and presets | Not approved | Individual tool adoption review required |
| Context7 | Approved after data-handling acceptance | Sanitized queries; register entry |
| OpenAI Developer Documentation MCP | Approved when relevant | OpenAI or Codex work only |
| codebase-memory-mcp | Disabled initially | Pilot via tool adoption review |
| Ponytail | Disabled initially | Review-only pilot without hooks |
| Playwright MCP | Disabled initially | Isolated profile, pinned version |
| Forgejo integration | Disabled or read-only initially | Dedicated least-privilege token; writes need owner authorization |
| Deployment, infrastructure, privileged tools | Disabled initially | RFC or tool adoption review |

Project-specific restrictions may make this list stricter. Loosening it requires a tool adoption review and, where it departs from the central profile, an exception.
