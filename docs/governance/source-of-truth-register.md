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
| Project principles | `.specify/memory/constitution.md` | | Approved v1.0.0 |
| Product intent | `docs/product/vision.md`, `docs/product/requirements.md` | `docs/archive/2026-10-product-intent/` | Archived originals are not authoritative |
| Feature behaviour and acceptance criteria | Native specifications under `specs/` | `specs/README.md` index | |
| Feature plans | Native plans under `specs/` | | |
| Tasks and completion state | Native tasks under `specs/` | External tracker mirrors (non-authoritative) | |
| Simple defect records | `.specify/bugs/<slug>/` | | Spec Kit `bug` extension |
| Architecture overview | `docs/architecture/README.md` | | |
| Architecture decisions | `docs/architecture/adr/` | `docs/archive/2026-10-legacy-adr-index/` | Migrated from docs/adr/ (2026-10) |
| Cross-specification delivery plans | `docs/architecture/delivery-plan-*.md` | `docs/archive/2026-10-delivery-plan/` | Governance adoption and platform plans |
| Proposals | `docs/rfc/` | | |
| Investigations | `docs/investigations/` | | |
| Automated tests | Source tree test directories | | |
| Project-wide test strategy and evidence | `docs/testing/` | | |
| Release records | `docs/releases/` | Git tags | |
| Operations model | `docs/operations/README.md` | | |
| Service guides (per service) | `docs/operations/services/` | `shared/<service>/` implementation | Project-specific category; migrated from docs/products/ |
| Procedures | `docs/operations/runbooks/` | `docs/operations/` | |
| Service definitions | `docker-compose.yml`, `compose/*.yml` | `docs/operations/services/` | |
| Deployment and backup automation | `.forgejo/workflows/` | Decision comments citing ADRs | Implementation |
| Lessons | `docs/lessons/` | | Binding only once incorporated |
| Retired documentation | `docs/archive/` | | |
| Secrets | Outside the repository: server .env (mode 600) and Forgejo Actions secrets | `env.example` (names only) | Never values |
| TLS certificate material | `shared/traefik/advanced/selfsigncert/` (git-crypt encrypted; key held outside the repository) | `docs/operations/DEVELOPMENT.md`, `docs/operations/runbooks/DEPLOYMENT.md` | Encrypted at rest; not a plaintext credential |

Add project-specific categories (for example API schemas or infrastructure definitions) with a single authoritative location each.
