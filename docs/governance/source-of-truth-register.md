# Source-of-Truth Register

Maps each information category to exactly one authoritative location. Consult before creating any document. This register does not duplicate content.

| Category | Authoritative location | Supporting locations | Notes |
|---|---|---|---|
| Governance rules | Central Nexora Governance at the adopted tag | `CENTRAL-GOVERNANCE-REFERENCE.md` | Never copied locally |
| Governance adoption | `docs/governance/governance-adoption.md` | | |
| Exceptions | `docs/governance/documentation-exceptions.md` | Affected artifacts for one-time deviations | |
| Permitted tools | `docs/governance/approved-tooling.md` | | |
| Enabled tools | `docs/governance/tooling-adoption-register.md` | Agent configuration files | |
| Agent operating rules | `AGENTS.md` | Nested `AGENTS.md` | Operational only |
| Project principles | Native Spec Kit constitution (under `.specify/`) | | |
| Product intent | `docs/product/vision.md`, `docs/product/requirements.md` | | |
| Feature behaviour and acceptance criteria | Native specifications under `specs/` | `specs/README.md` index | |
| Feature plans | Native plans under `specs/` | | |
| Tasks and completion state | Native tasks under `specs/` | External tracker mirrors (non-authoritative) | |
| Simple defect records | `.specify/bugs/<slug>/` | | Spec Kit `bug` extension |
| Architecture overview | `docs/architecture/README.md` | | |
| Architecture decisions | `docs/architecture/adr/` | | |
| Cross-specification delivery plans | `docs/architecture/delivery-plan-<slug>.md` | | Only when justified |
| Proposals | `docs/rfc/` | | |
| Investigations | `docs/investigations/` | | |
| Automated tests | Source tree test directories | | |
| Project-wide test strategy and evidence | `docs/testing/` | | |
| Release records | `docs/releases/` | Git tags | |
| Operations model | `docs/operations/README.md` | | |
| Procedures | `docs/operations/runbooks/` | | |
| Lessons | `docs/lessons/` | | Binding only once incorporated |
| Retired documentation | `docs/archive/` | | |
| Secrets | Outside the repository: `<SECRET_STORE>` | | Names only, never values |

Add project-specific categories (for example API schemas or infrastructure definitions) with a single authoritative location each. Replace `<SECRET_STORE>` with the name of the project's secret store or environment mechanism.
