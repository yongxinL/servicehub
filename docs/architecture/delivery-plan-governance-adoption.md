# Delivery Plan: ServiceHub Governance Adoption

| Field | Value |
|---|---|
| Title | ServiceHub Governance Adoption |
| Status | Implemented |
| Owner | project-owner |
| Created | 2026-10-12 |
| Updated | 2026-10-13 |
| Approved by / mode / date | Pending Project Owner approval |
| Trigger | Governance adoption |

Observed baseline:

- Repository commit: e5b4fbeb2ec56851140afc9fc266b24cf6420a72
- Branch: chore/governance
- Working tree: clean at audit time
- No files were modified during this planning task.

## 1. Objective

Migrate ServiceHub’s existing documentation, planning records, ADRs, RFCs, operational records, product guides, templates, and governance metadata into the Nexora Governance v1.0 locations without changing Accepted ADR meaning, inventing decisions, or creating retrospective specifications.

The migration is complete only after:

- owner-approved batches are committed;
- native Spec Kit is initialized with integration codex;
- product intent and the platform delivery plan are in canonical locations;
- indexes and source-of-truth mappings resolve;
- validation evidence is recorded;
- remaining adoption gaps remain explicitly open.

## 2. Participating Work

| Item | Type | Native plan location | Status |
|---|---|---|---|
| Governance records and adoption metadata | Governance | docs/governance/ | Draft migration |
| Legacy documentation migration | Governance adoption | docs/architecture/delivery-plan-governance-adoption.md | Draft |
| ADR-001..ADR-010 | ADRs | docs/architecture/adr/ | Mixed: Accepted, Proposed, owner decision pending |
| RFC-001, RFC-002 | RFCs | docs/rfc/ | Accepted |
| INV-001 | Investigation | docs/investigations/ | Draft |
| TEST-001 | Test plan | docs/testing/ | Not Executed |
| Product intent | Product artifacts | docs/product/vision.md, docs/product/requirements.md | To be restructured |
| Platform delivery plan | Cross-specification delivery plan | docs/architecture/delivery-plan-servicehub-platform.md | To be created |
| Native Spec Kit | Specifications, plans, tasks | specs/, .specify/ | Not initialized |
| Service guides | Project-specific operations category | docs/operations/services/ | To be moved |
| Legacy records | Archive | docs/archive/ | To be indexed |

## 3. Dependencies and Order

The batches must be applied in this order:

1. Batch 0 records the owner decisions and creates this plan.
2. Batch 1 resolves the case-sensitive template problem before any lower-case copies are created.
3. Batch 2 moves unambiguous service guides, lessons, and runbooks and repairs their links.
4. Batch 3 moves ADRs to the canonical location, normalizes ADR relationships
5. Batch 4 initializes Spec Kit only after a recorded baseline commit.
6. Batch 5 consolidates product intent and the legacy roadmap/phase store.
7. Batch 6 completes metadata, indexes, and traceability.
8. Batch 7 validates the migrated tree.
9. Batch 8 archives the remaining legacy records.

No batch may be approved until the preceding batch has been reviewed and committed. No status transition such as Adopted, Verified, or Released is proposed by this plan.

## 4. Milestones and Owner Checkpoints

| Milestone | Entry criteria | Exit criteria | Owner checkpoint |
|---|---|---|---|
| Decision record | Owner decisions supplied | Draft plan contains OD-1 through OD-9 and open decisions | Approve map |
| Template normalization | APFS case behavior verified | Uppercase templates archived; lower-case templates tracked | Approve archive layout |
| Safe relocation | Directory contents reviewed | Product guides, lessons, and runbooks moved with valid links | Approve moves |
| ADR normalization | Product/runbook moves complete | Canonical ADR index, ADR-009/A​​DR-010 states recorded | Approve ADR changes |
| Native workflow | Baseline commit recorded | .specify/ and specs/ initialized or blocked with evidence | Approve initialization |
| Product consolidation | Product templates available | Vision, requirements, and delivery plan created | Approve content equivalence |
| Traceability | All artifacts exist | Metadata and indexes complete | Approve metadata batch |
| Validation | All batches committed | Link, secret, index, and status checks recorded | Accept adoption evidence |
| Archive completion | Replacement links exist | Legacy records archived and indexed | Approve archive |

## 5. Migration and Rollback Windows

- Each batch is one commit or pull request.
- The baseline commit for Spec Kit is the commit produced by completed Batch 3.
- If a batch fails validation, revert that batch only; do not revert earlier accepted decisions.
- No destructive history rewrite is proposed.
- Certificate material under shared/traefik/advanced/selfsigncert/ remains git-crypt encrypted. The key remains outside the repository. No certificate remediation is included.
- TEST-001 execution, restore testing, and release 1.0.0 remain post-adoption work.

## 6. Risks

- APFS case-insensitivity can make lower-case template checks appear successful when only upper-case paths are tracked.
- Accepted ADRs contain historical service and Compose names. Link repair must not rewrite their meaning.
- Product-guide relocation changes many relative paths.
- Roadmap and phase records contain planning material that must not become competing native specifications.
- Spec Kit initialization depends on an installed, pinned CLI version that is not supplied by the owner decision.
- The central Forgejo URL contains https://git.example.com and cannot be made concrete without owner input.
- TEST-001, restore validation, rollback, alert delivery, service criticality, and release evidence remain unverified.

## 7. Migration Map

Each row represents one audit finding or one deliberately grouped homogeneous finding. No finding appears in more than one row.

| Item | Audit finding | Class | Proposed action | Batch | Dependencies |
|---|---|---|---|---|---|
| Owner decision ledger | Owner decisions were supplied but are not committed | owner decision | Create this delivery plan and point the adoption record to it | 0 | Owner approval |
| Adoption metadata | docs/governance/governance-adoption.md contained placeholders at audit time | owner decision | Apply the Batch 0 values without advancing the adoption state | 0 | OD-8 |
| Central repository pointer | CENTRAL-GOVERNANCE-REFERENCE.md:6 is unresolved | owner decision | Set https://git.example.com/Nexora/governance | 6 | Actual Forgejo URL |
| Secret-store register | docs/governance/source-of-truth-register.md:31 is unresolved | owner decision | Record server .env (mode 600) and Forgejo Actions secrets | 6 | OD-8 |
| Agent instructions | AGENTS.md still uses project and validation placeholders | owner decision | Set project name and agent metadata; retain unresolved command placeholders | 6 | Owner-provided commands |
| Tool register | Spec Kit and Codex versions are placeholders | owner decision | Record integration codex; keep version unresolved until installed | 4, 6 | Pinned CLI version |
| ADR location | ADRs are under docs/adr/, while the canonical index is empty | careful consolidation | Move ADR-001..010 to docs/architecture/adr/ | 3 | OD-2 |
| ADR-008/ADR-009 relation | ADR-009 partially supersedes ADR-008 | owner decision | Record partial supersession on both ADRs and in the index | 3 | OD-6 |
| ADR-009 status | ADR-009 is Proposed despite implemented scope | owner decision | Set Accepted retrospectively; preserve follow-up obligations | 3 | OD-5 |
| ADR-010 status | ADR-010 remains unapproved | owner decision | Leave Proposed; list under Owner Decisions | 3, 13 | Owner decision |

| ADR-001..010 links | ADR files contain historical Compose paths | careful consolidation | Repair links and add dated rename notes without changing decision meaning | 3 | OD-6 |
| Legacy product guides | docs/products/ is not an operations category | safe automatic | Move to docs/operations/services/ and register category | 2 | OD-approved move |
| Product-guide links | Relative links depend on docs/products/ depth | safe automatic | Repair every affected relative link | 2 | Product move |
| Lessons identifiers | LESSON-001/002 violate current naming | safe automatic | Rename to LES-001/002 and update IDs, titles, indexes, and inbound links | 2 | OD-approved move |
| Legacy lesson Compose link | LESSON-002 links to compose/poste.yml | careful consolidation | Replace with compose/mailsv.yml (archived) and add dated note; docs archived to docs/archive/2026-10-mailsv-removal/ | 2 | OD-6 |
| Runbook locations | RUNBOOK.md, BACKUP-RESTORE.md, and DEPLOYMENT.md are outside runbooks/ | safe automatic | Move into docs/operations/runbooks/ | 2 | Index and link repair |
| Stale Compose links | dbsvc, authn, depot, wbapp, aiagn, obsvc, and poste remain in links | careful consolidation | Replace with current domains and add dated rename notes | 2, 3 | OD-6 |
| Alloy README | Four Victoria/Grafana README links point to nonexistent files | safe automatic | Point links to docs/operations/services/ and docs/operations/services/grafana.md | 2 | Product move |
| Uppercase templates | Seven upper-case templates and one release template remain tracked | careful consolidation | Move to dated archive; copy missing lower-case Nexora templates after the move | 1 | APFS dependency |
| Lower-case template coverage | Four lower-case template links are broken at the audited commit | safe automatic | Restore adr-template.md, rfc-template.md, investigation-template.md, and release-template.md from the central template | 1 | Archive-before-copy |
| Phase template | PHASE-TEMPLATE.md has no lower-case replacement | owner decision | Archive it; use native plans or the delivery-plan template for new work | 1, 8 | OD-7 |
| RFC index | RFC-001 and RFC-002 are not indexed | safe automatic | Add rows with Accepted status and resulting ADRs | 1 | None |
| Investigation index | INV-001 is not indexed | safe automatic | Add row with current Draft status | 1 | None |
| Test index | TEST-001 is not indexed | safe automatic | Add row with Not Executed status | 1 | None |
| Architecture index | Architecture files exist but the index claims none do | safe automatic | Index architecture files and ADR index | 1, 6 | ADR move |
| Operations index | Operations index claims no project artifacts exist | safe automatic | Index operational documents, services, and runbooks | 2, 6 | Product/runbook moves |
| Lessons index | Lessons index is empty | safe automatic | Add LES-001 and LES-002 rows | 2 | Lesson rename |
| Product intent | CHARTER.md and PRD.md are outside docs/product/ | careful consolidation | Restructure into vision.md and requirements.md; archive originals | 5 | OD-4 |
| Planning stores | ROADMAP.md and docs/phases/* compete with future native plans | careful consolidation | Consolidate into the platform delivery plan; archive originals | 5 | OD-7 |
| Product/service index | Product guides lack a registered project-specific category | safe automatic | Add docs/operations/services/ to source-of-truth and operations indexes | 2, 6 | Product move |
| Spec Kit absent | No .specify/ or specs/ exists | owner decision | Initialize native Spec Kit with codex; create no retrospective specifications | 4 | Baseline commit and pinned version |
| TEST-001 | TEST-001 is Not Executed | owner decision | Record as post-adoption gap, not a migration task | 6, 13 | OD-9 |
| Restore and release | Restore, rollback, alert delivery, and release evidence are absent | owner decision | Record as known gaps; do not claim completion | 6, 13 | OD-9 |
| Certificate tracking | Five certificate paths are tracked but git-crypt encrypted | owner decision | Revised 2026-10-13: no ADR-011; the encrypted certificate state is recorded in the source-of-truth register and existing operations guides. | 0, 3, 7 | OD-1 |
| .env and servicehub.key | Not tracked at audited commit | safe automatic | Verify absence during validation; do not add | 7 | None |
| Decision-bearing comments | Compose, workflow, egress, routing, and shell comments contain implementation decisions | safe automatic | Inventory and retain; no code/config changes | 7 | None |
| Legacy archive | Several displaced records need durable archive entries | careful consolidation | Add archive index entries and replacement links | 5, 8 | Replacement artifacts |
| ADR-010 | Owner approval remains pending | owner decision | Keep Proposed and require explicit owner decision | 13 | Owner |
| Migration map approval | Prompt 03 requires owner approval of map | owner decision | Obtain approval before execution | 0 | Project Owner |
| Validation commands | Project test/build/lint commands are placeholders | owner decision | Record actual commands or explicitly retain placeholders | 6, 13 | Owner |

## 8. Controlled Batches

### Batch 0 — Governance Records

Purpose: record the owner decisions and adoption metadata before any migration action.

Files to create

- docs/architecture/delivery-plan-governance-adoption.md:1 — this plan, using the cross-specification delivery-plan template and Status: Draft.
- The plan contains the complete OD-1 through OD-9 ledger, the migration map, batch order, open decisions, and validation criteria.

Files to edit

- docs/governance/governance-adoption.md — fill the Batch 0 adoption metadata, keep `<CENTRAL_GOVERNANCE_REPOSITORY>` unchanged, add the Forgejo URL note and this plan's Notes pointer, and do not transition the adoption state.

Exact git mv commands

- None. Batch 0 creates the coordination record only.

Link repairs

- None in Batch 0.

Index entries

- Add the migration plan to docs/architecture/README.md:21 in Batch 5 or Batch 6, when its final location is confirmed.
- Do not add it as a native specification or task list.

Suggested commit message

docs(governance): record migration owner decisions and draft adoption plan

### Batch 1 — Templates and Indexes

Purpose: resolve the case-sensitive template state before restoring lower-case files.

Observed state at the audited commit:

- Tracked upper-case templates: ADR-TEMPLATE.md, INVESTIGATION-TEMPLATE.md, LESSON-TEMPLATE.md, PHASE-TEMPLATE.md, RELEASE-TEMPLATE.md, RFC-TEMPLATE.md, TEST-TEMPLATE.md, plus docs/releases/RELEASE-TEMPLATE.md.
- Tracked lower-case templates already present: cross-specification-delivery-plan-template.md, lesson-learned-template.md, runbook-template.md, temporary-work-handoff-template.md, test-plan-template.md, tooling-adoption-entry-template.md, verification-summary-template.md.
- Missing tracked lower-case templates: adr-template.md, rfc-template.md, investigation-template.md, release-template.md.
- APFS case-insensitivity makes filesystem comparisons misleading; the move must precede the copy.

Exact git mv commands

mkdir -p docs/archive/2026-10-legacy-templates

git mv docs/templates/ADR-TEMPLATE.md docs/archive/2026-10-legacy-templates/ADR-TEMPLATE.md
git mv docs/templates/INVESTIGATION-TEMPLATE.md docs/archive/2026-10-legacy-templates/INVESTIGATION-TEMPLATE.md
git mv docs/templates/LESSON-TEMPLATE.md docs/archive/2026-10-legacy-templates/LESSON-TEMPLATE.md
git mv docs/templates/PHASE-TEMPLATE.md docs/archive/2026-10-legacy-templates/PHASE-TEMPLATE.md
git mv docs/templates/RELEASE-TEMPLATE.md docs/archive/2026-10-legacy-templates/RELEASE-TEMPLATE.md
git mv docs/templates/RFC-TEMPLATE.md docs/archive/2026-10-legacy-templates/RFC-TEMPLATE.md
git mv docs/templates/TEST-TEMPLATE.md docs/archive/2026-10-legacy-templates/TEST-TEMPLATE.md
git mv docs/releases/RELEASE-TEMPLATE.md docs/archive/2026-10-legacy-templates/RELEASE-TEMPLATE-from-releases.md

After the upper-case files are moved, restore the missing lower-case files from the approved central template:

cp -p /Users/george.li/Documents/workspaces/governance/project-template/docs/templates/adr-template.md docs/templates/adr-template.md
cp -p /Users/george.li/Documents/workspaces/governance/project-template/docs/templates/rfc-template.md docs/templates/rfc-template.md
cp -p /Users/george.li/Documents/workspaces/governance/project-template/docs/templates/investigation-template.md docs/templates/investigation-template.md
cp -p /Users/george.li/Documents/workspaces/governance/project-template/docs/templates/release-template.md docs/templates/release-template.md

The seven already-tracked lower-case templates should be verified against the central template, not copied blindly.

Files to edit

- docs/adr/README.md:41 — change the upper-case ADR-template link to ../archive/2026-10-legacy-templates/ADR-TEMPLATE.md until the old index is archived in Batch 3.
- docs/phases/README.md:35 — change the upper-case phase-template link to ../archive/2026-10-legacy-templates/PHASE-TEMPLATE.md; no lower-case phase template is being restored.
- docs/releases/README.md:26 — becomes valid after release-template.md is copied; no semantic edit required.
- docs/rfc/README.md:26 — becomes valid after rfc-template.md is copied; no semantic edit required.
- docs/investigations/README.md:26 — becomes valid after investigation-template.md is copied; no semantic edit required.
- docs/architecture/adr/README.md:26 — becomes valid after adr-template.md is copied; no semantic edit required.
- docs/templates/README.md:22 — adr-template.md becomes valid after copy.
- docs/templates/README.md:23 — rfc-template.md becomes valid after copy.
- docs/templates/README.md:24 — investigation-template.md becomes valid after copy.
- docs/templates/README.md:29 — release-template.md becomes valid after copy.

Archive link repairs

- docs/archive/2026-10-legacy-templates/RELEASE-TEMPLATE-from-releases.md:82 -> ../../releases/README.md
- docs/archive/2026-10-legacy-templates/RELEASE-TEMPLATE-from-releases.md:83 -> ../../testing/README.md
- docs/archive/2026-10-legacy-templates/RELEASE-TEMPLATE-from-releases.md:84 -> ../../architecture/DEPLOYMENT-ARCHITECTURE.md

Index entries

- docs/archive/README.md:20 — add all eight legacy-template entries with origin, archived date 2026-10-12, reason, and replacement.
- docs/rfc/README.md:20 — add RFC-001 and RFC-002.
- docs/investigations/README.md:20 — add INV-001.
- docs/testing/README.md:20 — add TEST-001.
- docs/architecture/README.md:21 — add the five existing architecture documents and the canonical ADR index; add the governance-adoption delivery plan once created.

Suggested commit message

docs: normalize templates and governed documentation indexes

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 2 — Safe Moves and Link Repair

Purpose: move unambiguous records and repair the links affected by directory depth.

Exact git mv commands

mkdir -p docs/operations

git mv docs/products docs/operations/services

git mv docs/lessons/LESSON-001-initial-architecture-review.md docs/lessons/LES-001-initial-architecture-review.md
git mv docs/lessons/LESSON-002-stalwart-allowlist-broke-bulwark-login.md docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md

git mv docs/operations/RUNBOOK.md docs/operations/runbooks/RUNBOOK.md
git mv docs/operations/BACKUP-RESTORE.md docs/operations/runbooks/BACKUP-RESTORE.md
git mv docs/operations/DEPLOYMENT.md docs/operations/runbooks/DEPLOYMENT.md

Files to create or edit

- docs/operations/services/README.md:1 — retain the product-guide index, rename its category to project-specific service guides, and link it from the operations index.
- docs/operations/README.md:1 — add service guides and runbooks to the operations index.
- docs/operations/runbooks/README.md:18 — add RUNBOOK, BACKUP-RESTORE, and DEPLOYMENT rows.
- docs/lessons/README.md:18 — add LES-001 and LES-002.
- docs/investigations/INV-001-architecture-and-documentation-gap-analysis.md:21 — change LESSON-001 to LES-001.
- docs/investigations/INV-001-architecture-and-documentation-gap-analysis.md:129 -> ../lessons/LES-001-initial-architecture-review.md.
- shared/grafana/alloy/README.md:7:
  - ../../victoriametrics/README.md -> ../../../docs/operations/services/victoriametrics.md
  - ../../victorialogs/README.md -> ../../../docs/operations/services/victorialogs.md
- shared/grafana/alloy/README.md:69 -> ../../../docs/operations/services/victoriametrics.md
- shared/grafana/alloy/README.md:70 -> ../../../docs/operations/services/victorialogs.md
- shared/grafana/alloy/README.md:71 -> ../../../docs/operations/services/grafana.md

Lesson identifier edits

- docs/lessons/LES-001-initial-architecture-review.md:5 — LESSON-001 -> LES-001.
- docs/lessons/LES-001-initial-architecture-review.md — add metadata row `Formerly: LESSON-001`.
- docs/lessons/LES-001-initial-architecture-review.md:24 — LESSON-001 -> LES-001.
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md:5 — LESSON-002 -> LES-002. (archived to docs/archive/2026-10-mailsv-removal/docs/lessons/)
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md — add metadata row `Formerly: LESSON-002`. (archived)
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md:25 — LESSON-002 -> LES-002. (archived)
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md:31:
  - compose/poste.yml -> compose/mailsv.yml (archived)
  - ../products/bulwark.md -> ../operations/services/bulwark.md (archived to ../archive/2026-10-mailsv-removal/)
  - ../products/stalwart.md -> ../operations/services/stalwart.md (archived to ../archive/2026-10-mailsv-removal/)
  - Add: “Rename note (2026-10-12): compose/poste.yml was renamed compose/mailsv.yml; historical incident wording is retained.”
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md:110 -> ../operations/services/bulwark.md
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md:111 -> ../operations/services/stalwart.md
- docs/lessons/LES-002-stalwart-allowlist-broke-bulwark-login.md:112 -> ../operations/services/traefik.md

Moved runbook link repairs

- docs/operations/runbooks/RUNBOOK.md:28 -> ../INSTALLATION.md
- docs/operations/runbooks/RUNBOOK.md:96 -> ../SERVICE-INVENTORY.md
- docs/operations/runbooks/RUNBOOK.md:110 -> ../../architecture/COMPONENT-CATALOGUE.md
- docs/operations/runbooks/RUNBOOK.md:168 -> ../../architecture/DEPLOYMENT-ARCHITECTURE.md
- docs/operations/runbooks/RUNBOOK.md:197 -> ../TROUBLESHOOTING.md
- docs/operations/runbooks/RUNBOOK.md:209 -> ../SERVICE-INVENTORY.md
- docs/operations/runbooks/RUNBOOK.md:210 -> BACKUP-RESTORE.md
- docs/operations/runbooks/RUNBOOK.md:211 -> ../MONITORING-ALERTING.md
- docs/operations/runbooks/RUNBOOK.md:212 -> ../TROUBLESHOOTING.md
- docs/operations/runbooks/RUNBOOK.md:213 -> ../../testing/README.md
- docs/operations/runbooks/BACKUP-RESTORE.md:32 -> ../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
- docs/operations/runbooks/BACKUP-RESTORE.md:38 -> ../../../.forgejo/workflows/71-backup.yml
- docs/operations/runbooks/BACKUP-RESTORE.md:73 -> ../services/owncloud.md#backup-and-recovery
- docs/operations/runbooks/BACKUP-RESTORE.md:84 -> ../EGRESS-CONTROLS.md
- docs/operations/runbooks/BACKUP-RESTORE.md:86 -> ../INSTALLATION.md#prerequisites
- docs/operations/runbooks/BACKUP-RESTORE.md:103 -> ../services/stalwart.md#database-management-create--delete--backup--restore
- docs/operations/runbooks/BACKUP-RESTORE.md:107 -> DEPLOYMENT.md
- docs/operations/runbooks/BACKUP-RESTORE.md:114 -> DEPLOYMENT.md#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts
- docs/operations/runbooks/BACKUP-RESTORE.md:173 -> DEPLOYMENT.md#ssh-host-keys-server_ssh_known_hosts-and-backup_home_ssh_known_hosts
- docs/operations/runbooks/BACKUP-RESTORE.md:175 -> ../services/forgejo.md
- docs/operations/runbooks/BACKUP-RESTORE.md:352 -> ../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
- docs/operations/runbooks/BACKUP-RESTORE.md:358 -> ../../architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md
- docs/operations/runbooks/BACKUP-RESTORE.md:535 -> ../../rfc/RFC-001-reliability-and-recovery-baseline.md
- docs/operations/runbooks/BACKUP-RESTORE.md:536 -> ../../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
- docs/operations/runbooks/BACKUP-RESTORE.md:537 -> ../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
- docs/operations/runbooks/BACKUP-RESTORE.md:538 -> ../MONITORING-ALERTING.md
- docs/operations/runbooks/BACKUP-RESTORE.md:539 -> ../../testing/TEST-001-platform-baseline-validation.md
- docs/operations/runbooks/DEPLOYMENT.md:27 -> ../../../.forgejo/workflows/61-deploy.yml
- docs/operations/runbooks/DEPLOYMENT.md:46 -> ../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
- docs/operations/runbooks/DEPLOYMENT.md:86 -> ../DEVELOPMENT.md#managing-encrypted-files-git-crypt
- docs/operations/runbooks/DEPLOYMENT.md:88 -> BACKUP-RESTORE.md#backup-secrets
- docs/operations/runbooks/DEPLOYMENT.md:139 -> BACKUP-RESTORE.md#configuration-keys
- docs/operations/runbooks/DEPLOYMENT.md:145 -> ../INSTALLATION.md#prerequisites
- docs/operations/runbooks/DEPLOYMENT.md:205 -> ../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
- docs/operations/runbooks/DEPLOYMENT.md:214 -> ../../../.forgejo/workflows/71-backup.yml
- docs/operations/runbooks/DEPLOYMENT.md:214 -> BACKUP-RESTORE.md#managing-the-schedule-enable-disable-retime
- docs/operations/runbooks/DEPLOYMENT.md:218 -> ../../architecture/DEPLOYMENT-ARCHITECTURE.md
- docs/operations/runbooks/DEPLOYMENT.md:219 -> BACKUP-RESTORE.md
- docs/operations/runbooks/DEPLOYMENT.md:220 -> ../INSTALLATION.md

Moved product-guide link repairs

These are the affected links whose relative strings change after docs/products/ becomes docs/operations/services/. Sibling links that remain in the same directory are unchanged.

docs/products/authentik.md:9 -> ../../../compose/infra.yml
docs/products/authentik.md:9 -> ../../../shared/authentik/Dockerfile
docs/products/authentik.md:38 -> ../../../env.example
docs/products/authentik.md:79 -> ../../../shared/traefik/advanced/middlewares-authentik.yml
docs/products/authentik.md:138 -> ../../../README.md#architecture-overview
docs/products/authentik.md:139 -> ../../../README.md#security-observability-stack
docs/products/bulwark.md:7 -> ../../../compose/mailsv.yml (archived)
docs/products/bulwark.md:7 -> ../../../shared/bulwark/Dockerfile (archived)
docs/products/bulwark.md:95 -> ../../../shared/bulwark/Dockerfile (archived)
docs/products/bulwark.md:102 -> ../../../README.md#email-stack-mailsv (archived)
docs/products/confluence.md:7 -> ../../../compose/webapp.yml
docs/products/confluence.md:7 -> ../../../shared/confluence/Dockerfile
docs/products/confluence.md:28 -> ../../../env.example
docs/products/confluence.md:90 -> ../../../scripts/egress-guard.sh
docs/products/confluence.md:90 -> ../../../scripts/egress-policies.conf
docs/products/confluence.md:100 -> ../EGRESS-CONTROLS.md
docs/products/confluence.md:114 -> ../../../shared/confluence/Dockerfile
docs/products/confluence.md:115 -> ../../../shared/confluence/plugins
docs/products/confluence.md:121 -> ../../../README.md#homepage
docs/products/fastcrw.md:20 -> ../../../shared/searxng/compose.yml
docs/products/fastcrw.md:20 -> ../../../shared/fastcrw/lightpanda/compose.yml
docs/products/fastcrw.md:20 -> ../../../shared/fastcrw/chromium/compose.yml
docs/products/fastcrw.md:20 -> ../../../shared/fastcrw/compose.yml
docs/products/forgejo.md:7 -> ../../../compose/devops.yml
docs/products/forgejo.md:7 -> ../../../shared/forgejo/server/Dockerfile
docs/products/forgejo.md:9 -> ../runbooks/DEPLOYMENT.md
docs/products/forgejo.md:28 -> ../../../env.example
docs/products/forgejo.md:55 -> ../../../shared/forgejo/actions/Dockerfile
docs/products/forgejo.md:61 -> ../../../shared/forgejo/actions/config.yml
docs/products/forgejo.md:69 -> ../../../env.example
docs/products/forgejo.md:78 -> ../runbooks/DEPLOYMENT.md
docs/products/forgejo.md:91 -> ../../../.forgejo/workflows/71-backup.yml
docs/products/forgejo.md:93 -> ../runbooks/BACKUP-RESTORE.md
docs/products/forgejo.md:93 -> ../../../README.md#required-actions-secrets-and-variables
docs/products/forgejo.md:118 -> ../../../shared/forgejo/actions/config.yml
docs/products/forgejo.md:135 -> ../../../shared/forgejo/actions/entrypoint.sh
docs/products/forgejo.md:144 -> ../../../.forgejo/workflows/61-deploy.yml
docs/products/forgejo.md:144 -> ../../../.forgejo/workflows/71-backup.yml
docs/products/forgejo.md:180 -> ../../../shared/forgejo/server/Dockerfile
docs/products/forgejo.md:181 -> ../../../shared/forgejo/actions/Dockerfile
docs/products/forgejo.md:182 -> ../../../shared/forgejo/actions/entrypoint.sh
docs/products/forgejo.md:183 -> ../../../shared/forgejo/actions/config.yml
docs/products/forgejo.md:187 -> ../runbooks/DEPLOYMENT.md
docs/products/forgejo.md:188 -> ../runbooks/BACKUP-RESTORE.md
docs/products/forgejo.md:190 -> ../../../README.md#architecture-overview
docs/products/grafana.md:7 -> ../../../compose/obsvce.yml
docs/products/grafana.md:7 -> ../../../shared/grafana/Dockerfile
docs/products/grafana.md:24 -> ../../../env.example
docs/products/grafana.md:43 -> ../../../shared/grafana/provisioning
docs/products/grafana.md:47 -> ../../../shared/grafana/provisioning/datasources/datasources.yml
docs/products/grafana.md:48 -> ../../../shared/grafana/provisioning/dashboards/dashboards.yml
docs/products/grafana.md:50 -> ../../../shared/grafana/dashboards
docs/products/grafana.md:85 -> ../../../shared/grafana/Dockerfile
docs/products/grafana.md:86 -> ../../../shared/grafana/provisioning
docs/products/grafana.md:87 -> ../../../shared/grafana/dashboards
docs/products/grafana.md:88 -> ../../../shared/grafana/alloy
docs/products/grafana.md:88 -> ../../../shared/grafana/alloy/README.md
docs/products/grafana.md:89 -> ../../../shared/grafana/geoip
docs/products/grafana.md:95 -> ../../../shared/grafana/alloy/README.md
docs/products/grafana.md:97 -> ../../../README.md#observability-stack-obsvce
docs/products/hermesagent.md:187 -> ../../../compose/aiserv.yml
docs/products/litellm.md:7 -> ../../../shared/litellm/smartrouter.py
docs/products/litellm.md:7 -> ../../../compose/aiserv.yml
docs/products/litellm.md:7 -> ../../../shared/litellm/Dockerfile
docs/products/litellm.md:25 -> ../../../env.example
docs/products/litellm.md:52 -> ../../../shared/litellm/smartrouter.py
docs/products/litellm.md:64 -> ../../../shared/litellm/config.default.yaml
docs/products/litellm.md:71 -> ../../../shared/litellm/config.default.yaml
docs/products/litellm.md:71 -> ../../../shared/litellm/entrypoint.sh
docs/products/litellm.md:97 -> ../../../shared/litellm/Dockerfile
docs/products/litellm.md:98 -> ../../../shared/litellm/config.default.yaml
docs/products/litellm.md:99 -> ../../../shared/litellm/smartrouter.py
docs/products/litellm.md:100 -> ../../../shared/litellm/entrypoint.sh
docs/products/litellm.md:108 -> ../../../README.md#ai-agent-platform-aiserv
docs/products/llamacpp.md:7 -> ../../../compose/aiserv.yml
docs/products/llamacpp.md:7 -> ../../../shared/llamacpp/Dockerfile
docs/products/llamacpp.md:24 -> ../../../env.example
docs/products/llamacpp.md:44 -> ../../../shared/llamacpp/entrypoint.sh
docs/products/llamacpp.md:63 -> ../../../shared/llamacpp/Dockerfile
docs/products/llamacpp.md:64 -> ../../../shared/llamacpp/entrypoint.sh
docs/products/llamacpp.md:70 -> ../../../README.md#ai-agent-platform-aiserv
docs/products/mariadb.md:7 -> ../../../compose/infra.yml
docs/products/mariadb.md:7 -> ../../../shared/mariadb/Dockerfile
docs/products/mariadb.md:19 -> ../../../shared/mariadb/create-multiple-databases.sh
docs/products/mariadb.md:23 -> ../../../env.example
docs/products/mariadb.md:34 -> ../../../shared/mariadb/create-multiple-databases.sh
docs/products/mariadb.md:87 -> ../../../shared/mariadb/Dockerfile
docs/products/mariadb.md:88 -> ../../../shared/mariadb/create-multiple-databases.sh
docs/products/mariadb.md:93 -> ../../../README.md#configuration
docs/products/openwebui.md:7 -> ../../../compose/aiserv.yml
docs/products/openwebui.md:7 -> ../../../shared/openwebui/Dockerfile
docs/products/openwebui.md:21 -> ../../../env.example
docs/products/openwebui.md:58 -> ../../../shared/openwebui/Dockerfile
docs/products/openwebui.md:64 -> ../../../README.md#ai-agent-platform-aiserv
docs/products/owncloud.md:7 -> ../../../compose/webapp.yml
docs/products/owncloud.md:7 -> ../../../shared/owncloud/Dockerfile
docs/products/owncloud.md:36 -> ../../../env.example
docs/products/owncloud.md:151 -> ../../../shared/owncloud/Dockerfile
docs/products/owncloud.md:152 -> ../../../shared/owncloud/entrypoint.sh
docs/products/owncloud.md:161 -> ../runbooks/BACKUP-RESTORE.md
docs/products/postgresql.md:7 -> ../../../compose/infra.yml
docs/products/postgresql.md:7 -> ../../../shared/postgresql/Dockerfile
docs/products/postgresql.md:18 -> ../../../shared/postgresql/create-multiple-databases.sh
docs/products/postgresql.md:34 -> ../../../env.example
docs/products/postgresql.md:51 -> ../../../shared/postgresql/create-multiple-databases.sh
docs/products/postgresql.md:102 -> ../../../shared/postgresql/Dockerfile
docs/products/postgresql.md:103 -> ../../../shared/postgresql/create-multiple-databases.sh
docs/products/postgresql.md:107 -> ../runbooks/BACKUP-RESTORE.md
docs/products/postgresql.md:110 -> ../../../README.md#configuration
docs/products/stalwart.md:7 -> ../../../compose/mailsv.yml (archived)
docs/products/stalwart.md:7 -> ../../../shared/stalwart/Dockerfile (archived)
docs/products/stalwart.md:37 -> ../../../shared/stalwart/entrypoint.sh (archived)
docs/products/stalwart.md:95 -> ../runbooks/BACKUP-RESTORE.md
docs/products/stalwart.md:232 -> ../../../shared/stalwart/entrypoint.sh (archived)
docs/products/stalwart.md:233 -> ../../../shared/stalwart/acme-export.sh (archived)
docs/products/stalwart.md:333 -> ../../../README.md#configuration
docs/products/stalwart.md:345 -> ../../../README.md#configuration
docs/products/stalwart.md:377 -> ../../../shared/stalwart/Dockerfile (archived)
docs/products/stalwart.md:378 -> ../../../shared/stalwart/entrypoint.sh (archived)
docs/products/stalwart.md:379 -> ../../../shared/stalwart/acme-export.sh (archived)
docs/products/stalwart.md:387 -> ../../../README.md#email-stack-mailsv (archived)
docs/products/traefik.md:9 -> ../../../compose/route.yml
docs/products/traefik.md:9 -> ../../../shared/traefik/Dockerfile
docs/products/traefik.md:31 -> ../../../env.example
docs/products/traefik.md:51 -> ../../../scripts/gen-admin-rules.py
docs/products/traefik.md:107 -> ../runbooks/DEPLOYMENT.md
docs/products/traefik.md:111 -> ../../../shared/traefik/advanced/certificates.yml
docs/products/traefik.md:111 -> ../../../shared/traefik/advanced/selfsigncert
docs/products/traefik.md:122 -> ../DEVELOPMENT.md#managing-encrypted-files-git-crypt
docs/products/traefik.md:130 -> ../../../shared/traefik/advanced/middlewares-authentik.yml
docs/products/traefik.md:131 -> ../../../shared/traefik/advanced/middlewares-security.yml
docs/products/traefik.md:132 -> ../../../shared/traefik/advanced/certificates.yml
docs/products/traefik.md:133 -> ../../../shared/traefik/advanced/metrics.yml
docs/products/traefik.md:137 -> ../../../shared/traefik/advanced/middlewares-security.yml
docs/products/traefik.md:142 -> ../TROUBLESHOOTING.md#identity-console-rate-limited-429
docs/products/traefik.md:154 -> ../../../shared/traefik/advanced/metrics.yml
docs/products/traefik.md:175 -> ../../../shared/traefik/Dockerfile
docs/products/traefik.md:176 -> ../../../shared/traefik/advanced/certificates.yml
docs/products/traefik.md:177 -> ../../../shared/traefik/advanced/middlewares-authentik.yml
docs/products/traefik.md:178 -> ../../../shared/traefik/advanced/middlewares-security.yml
docs/products/traefik.md:179 -> ../../../shared/traefik/advanced/metrics.yml
docs/products/traefik.md:180 -> ../../../shared/traefik/advanced/selfsigncert
docs/products/traefik.md:184 -> ../../../README.md#architecture-overview
docs/products/traefik.md:185 -> ../DEVELOPMENT.md#managing-encrypted-files-git-crypt
docs/products/victorialogs.md:7 -> ../../../compose/obsvce.yml
docs/products/victorialogs.md:7 -> ../../../shared/grafana/alloy/README.md
docs/products/victorialogs.md:7 -> ../../../shared/victorialogs/Dockerfile
docs/products/victorialogs.md:59 -> ../../../shared/victorialogs/Dockerfile
docs/products/victorialogs.md:64 -> ../../../shared/grafana/alloy/README.md
docs/products/victorialogs.md:66 -> ../../../README.md#observability-stack-obsvce
docs/products/victoriametrics.md:7 -> ../../../compose/obsvce.yml
docs/products/victoriametrics.md:7 -> ../../../shared/grafana/alloy/README.md
docs/products/victoriametrics.md:7 -> ../../../shared/victoriametrics/Dockerfile
docs/products/victoriametrics.md:16 -> ../../../shared/victoriametrics/scrape.yaml
docs/products/victoriametrics.md:28 -> ../../../shared/victoriametrics/scrape.yaml
docs/products/victoriametrics.md:41 -> ../../../shared/grafana/alloy/config.alloy
docs/products/victoriametrics.md:66 -> ../../../shared/victoriametrics/Dockerfile
docs/products/victoriametrics.md:67 -> ../../../shared/victoriametrics/scrape.yaml
docs/products/victoriametrics.md:72 -> ../../../shared/grafana/alloy/README.md
docs/products/victoriametrics.md:74 -> ../../../README.md#observability-stack-obsvce
docs/products/wordpress.md:9 -> ../../../shared/wordpress/compose.yml
docs/products/wordpress.md:32 -> ../../../docker-compose.yml
docs/products/wordpress.md:44 -> ../../../env.example
docs/products/wordpress.md:98 -> ../../../shared/wordpress/compose.yml
docs/products/wordpress.md:99 -> ../../../shared/wordpress/Dockerfile
docs/products/wordpress.md:100 -> ../../../shared/wordpress/etc/nginx/nginx.conf
docs/products/wordpress.md:101 -> ../../../shared/wordpress/etc/nginx/http.d/00-common.inc
docs/products/wordpress.md:102 -> ../../../shared/wordpress/etc/nginx/http.d/10-wordpress.inc
docs/products/wordpress.md:103 -> ../../../shared/wordpress/etc/supervisord.conf
docs/products/wordpress.md:110 -> ../../../README.md#homepage

Inbound product-guide link repairs

Files that remain in docs/operations/ use sibling targets: services/<name>.md for service guides and runbooks/<name>.md for procedures.

docs/architecture/COMPONENT-CATALOGUE.md:34 -> ../operations/services/traefik.md
docs/architecture/COMPONENT-CATALOGUE.md:38 -> ../operations/services/authentik.md
docs/architecture/COMPONENT-CATALOGUE.md:41 -> ../operations/services/forgejo.md
docs/architecture/COMPONENT-CATALOGUE.md:43 -> ../operations/services/confluence.md
docs/architecture/COMPONENT-CATALOGUE.md:44 -> ../operations/services/owncloud.md
docs/architecture/COMPONENT-CATALOGUE.md:45 -> ../operations/services/owncloud.md
docs/architecture/COMPONENT-CATALOGUE.md:46 -> ../operations/services/openwebui.md
docs/architecture/COMPONENT-CATALOGUE.md:48 -> ../operations/services/hermesagent.md
docs/architecture/COMPONENT-CATALOGUE.md:49 -> ../operations/services/litellm.md
docs/architecture/COMPONENT-CATALOGUE.md:50 -> ../operations/services/llamacpp.md
docs/architecture/COMPONENT-CATALOGUE.md:56 -> ../operations/services/stalwart.md (archived to ../archive/2026-10-mailsv-removal/)
docs/architecture/COMPONENT-CATALOGUE.md:58 -> ../operations/services/bulwark.md (archived to ../archive/2026-10-mailsv-removal/)
docs/operations/INSTALLATION.md:103 -> services/confluence.md
docs/operations/SERVICE-INVENTORY.md:34 -> services/traefik.md
docs/operations/SERVICE-INVENTORY.md:41 -> services/forgejo.md
docs/operations/SERVICE-INVENTORY.md:43 -> services/confluence.md
docs/operations/SERVICE-INVENTORY.md:44 -> services/owncloud.md
docs/operations/SERVICE-INVENTORY.md:45 -> services/owncloud.md
docs/operations/SERVICE-INVENTORY.md:49 -> services/litellm.md
docs/operations/SERVICE-INVENTORY.md:55 -> services/grafana.md
docs/operations/SERVICE-INVENTORY.md:56 -> services/stalwart.md (archived to ../archive/2026-10-mailsv-removal/)
docs/operations/SERVICE-INVENTORY.md:58 -> services/bulwark.md (archived to ../archive/2026-10-mailsv-removal/)
docs/operations/SERVICE-INVENTORY.md:68 -> services/wordpress.md
docs/operations/TROUBLESHOOTING.md:74 -> services/authentik.md
docs/operations/TROUBLESHOOTING.md:106 -> services/traefik.md#security-middlewares
docs/operations/TROUBLESHOOTING.md:122 -> services/postgresql.md
docs/operations/TROUBLESHOOTING.md:138 -> services/forgejo.md
docs/operations/TROUBLESHOOTING.md:154 -> services/forgejo.md
docs/operations/TROUBLESHOOTING.md:166 -> services/wordpress.md
docs/operations/TROUBLESHOOTING.md:170 -> services/wordpress.md
docs/operations/TROUBLESHOOTING.md:186 -> services/litellm.md
docs/operations/TROUBLESHOOTING.md:202 -> services/llamacpp.md
docs/operations/TROUBLESHOOTING.md:234 -> services/grafana.md
docs/operations/TROUBLESHOOTING.md:250 -> services/victorialogs.md
docs/operations/TROUBLESHOOTING.md:250 -> services/victoriametrics.md
docs/rfc/RFC-001-reliability-and-recovery-baseline.md:140 -> ../operations/services/forgejo.md#backup-workflow-runtime
docs/phases/PHASE-002-identity-and-developer-services.md:46 -> ../operations/services/authentik.md
docs/phases/PHASE-002-identity-and-developer-services.md:47 -> ../operations/services/forgejo.md
docs/phases/PHASE-002-identity-and-developer-services.md:50 -> ../operations/services/owncloud.md
docs/phases/PHASE-004-observability-and-operational-hardening.md:49 -> ../operations/services/forgejo.md#backup-workflow-runtime

Inbound ADR product/runbook repairs before the ADR move

docs/adr/ADR-002-use-traefik-as-ingress.md:79 -> ../operations/services/traefik.md
docs/adr/ADR-003-use-postgresql-as-primary-database.md:79 -> ../operations/services/postgresql.md
docs/adr/ADR-004-use-authentik-for-central-identity.md:79 -> ../operations/services/authentik.md
docs/adr/ADR-004-use-authentik-for-central-identity.md:82 -> ../operations/services/stalwart.md
docs/adr/ADR-005-use-litellm-for-ai-routing.md:79 -> ../operations/services/litellm.md
docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:44 -> ../operations/services/owncloud.md
docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:160 -> ../operations/services/owncloud.md
docs/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:290 -> ../operations/services/forgejo.md
docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:162 -> ../operations/services/confluence.md#outbound-egress-policy
docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:266 -> ../operations/services/confluence.md
docs/adr/ADR-001-use-docker-compose.md:86 -> ../operations/runbooks/RUNBOOK.md
docs/adr/ADR-003-use-postgresql-as-primary-database.md:86 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:161 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:172 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:291 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:309 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:414 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:427 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../operations/runbooks/BACKUP-RESTORE.md

Runbook link repairs from non-runbook documents

docs/operations/DEVELOPMENT.md:119 -> runbooks/DEPLOYMENT.md
docs/operations/EGRESS-CONTROLS.md:174 -> runbooks/BACKUP-RESTORE.md
docs/operations/INSTALLATION.md:121 -> runbooks/RUNBOOK.md
docs/operations/INSTALLATION.md:122 -> runbooks/DEPLOYMENT.md
docs/operations/TROUBLESHOOTING.md:58 -> runbooks/BACKUP-RESTORE.md
docs/operations/TROUBLESHOOTING.md:58 -> runbooks/RUNBOOK.md
docs/operations/TROUBLESHOOTING.md:122 -> runbooks/BACKUP-RESTORE.md
docs/operations/TROUBLESHOOTING.md:266 -> runbooks/BACKUP-RESTORE.md
docs/operations/TROUBLESHOOTING.md:282 -> runbooks/RUNBOOK.md
docs/rfc/RFC-001-reliability-and-recovery-baseline.md:139 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:128 -> ../operations/runbooks/BACKUP-RESTORE.md
docs/testing/TEST-001-platform-baseline-validation.md:99 -> ../operations/runbooks/RUNBOOK.md
docs/testing/TEST-001-platform-baseline-validation.md:100 -> ../operations/runbooks/BACKUP-RESTORE.md

Suggested commit message

docs: relocate service guides, lessons, and runbooks into canonical locations

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 3 — ADR and RFC Normalization

Purpose: make docs/architecture/adr/ authoritative and normalize relationships without changing Accepted ADR meaning.

Exact git mv commands

git mv docs/adr/ADR-001-use-docker-compose.md docs/architecture/adr/ADR-001-use-docker-compose.md
git mv docs/adr/ADR-002-use-traefik-as-ingress.md docs/architecture/adr/ADR-002-use-traefik-as-ingress.md
git mv docs/adr/ADR-003-use-postgresql-as-primary-database.md docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md
git mv docs/adr/ADR-004-use-authentik-for-central-identity.md docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md
git mv docs/adr/ADR-005-use-litellm-for-ai-routing.md docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md
git mv docs/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
git mv docs/adr/ADR-007-adopt-dual-target-backup-and-recovery.md docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
git mv docs/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md
git mv docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
git mv docs/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md

mkdir -p docs/archive/2026-10-legacy-adr-index

git mv docs/adr/README.md docs/archive/2026-10-legacy-adr-index/README.md

Files to create

- docs/architecture/adr/ADR-011-retain-git-crypt-encrypted-certificate-material.md:1.

ADR-011 outline:

project: ServiceHub
document_type: ADR
document_id: ADR-011
title: Retain Git-Crypt-Encrypted Certificate Material With an External Key
status: Accepted
owner: project-owner
created: 2026-10-12
updated: 2026-10-12
decision_basis: Retrospective owner decision recorded 2026-10-12

Required ADR-011 content:

- Decision: certificate material under shared/traefik/advanced/selfsigncert/ remains git-crypt encrypted; the key remains outside the repository.
- Evidence: .gitattributes:3, .gitattributes:4, .gitattributes:5, and .gitattributes:6 apply git-crypt.
- Alternatives: remove certificate material from the repository, or retain plaintext material; both rejected by the owner decision.
- Rationale: the deploy workflow .forgejo/workflows/61-deploy.yml unlocks git-crypt during deployment, so changing how certificates are stored is deferred to a separate operational change.
- Follow-up obligation: replace the git-crypt key, because part of the key was displayed in a chat session on 2026-10-12.

Files to edit

- docs/architecture/adr/README.md:18 — add ADR-001 through ADR-011.
- docs/archive/2026-10-legacy-adr-index/README.md — add a short note immediately after the front matter saying the index is retired and pointing to link target `../../architecture/adr/README.md`.
- docs/archive/2026-10-legacy-adr-index/README.md — keep all original index content; repoint the original ADR-001 through ADR-010 row targets to ../../architecture/adr/<filename>, and repoint the original ADR template target to ../../templates/ADR-TEMPLATE.md.
- docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:8 — Proposed -> Accepted.
- docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:9 — append the retrospective owner acceptance and retain follow-up obligations.
- docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:37 — retain the existing partial-supersession statement and add an explicit relation to ADR-009.
- docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:24 — add explicit partial-supersession relation to ADR-008.
- docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:8 — retain Proposed; do not assume acceptance.
- docs/investigations/INV-001-architecture-and-documentation-gap-analysis.md:21 — retain LES-001 after the lesson rename.

ADR link repairs after the move

The following relative links change because the ADRs move from docs/adr/ to docs/architecture/adr/:

docs/architecture/adr/ADR-001-use-docker-compose.md:77 -> ../../../docker-compose.yml
docs/architecture/adr/ADR-001-use-docker-compose.md:78 -> ../../../compose
docs/architecture/adr/ADR-001-use-docker-compose.md:79 -> ../../../.forgejo/workflows/61-deploy.yml
docs/architecture/adr/ADR-001-use-docker-compose.md:84 -> ../ARCHITECTURE.md
docs/architecture/adr/ADR-001-use-docker-compose.md:85 -> ../DEPLOYMENT-ARCHITECTURE.md
docs/architecture/adr/ADR-001-use-docker-compose.md:86 -> ../../operations/runbooks/RUNBOOK.md
docs/architecture/adr/ADR-002-use-traefik-as-ingress.md:78 -> ../../../compose/route.yml
docs/architecture/adr/ADR-002-use-traefik-as-ingress.md:79 -> ../../operations/services/traefik.md
docs/architecture/adr/ADR-002-use-traefik-as-ingress.md:80 -> ../../../shared/traefik/advanced/middlewares-security.yml
docs/architecture/adr/ADR-002-use-traefik-as-ingress.md:81 -> ../../../shared/traefik/advanced/middlewares-authentik.yml
docs/architecture/adr/ADR-002-use-traefik-as-ingress.md:86 -> ../SYSTEM-CONTEXT.md
docs/architecture/adr/ADR-002-use-traefik-as-ingress.md:87 -> ../DATA-FLOW.md
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:77 -> ../../../compose/infra.yml
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:78 -> ../../../shared/postgresql/Dockerfile
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:79 -> ../../operations/services/postgresql.md
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:80 -> ../../../.forgejo/workflows/71-backup.yml
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:85 -> ../COMPONENT-CATALOGUE.md
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:86 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-003-use-postgresql-as-primary-database.md:87 -> ../../testing/TEST-001-platform-baseline-validation.md
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:78 -> ../../../compose/infra.yml
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:79 -> ../../operations/services/authentik.md
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:80 -> ../../../shared/traefik/advanced/middlewares-authentik.yml
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:81 -> ../../../compose/obsvce.yml
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:82 -> ../../operations/services/stalwart.md (archived to ../../archive/2026-10-mailsv-removal/)
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:86 -> ../ARCHITECTURE.md
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:87 -> ../../operations/TROUBLESHOOTING.md
docs/architecture/adr/ADR-004-use-authentik-for-central-identity.md:88 -> ../../testing/TEST-001-platform-baseline-validation.md
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:78 -> ../../../compose/aiserv.yml
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:79 -> ../../operations/services/litellm.md
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:80 -> ../../../shared/litellm/config.default.yaml
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:81 -> ../../../shared/litellm/smartrouter.py
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:82 -> ../../../compose/aiserv.yml
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:86 -> ../DATA-FLOW.md
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:87 -> ../../phases/PHASE-003-ai-platform.md
docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:88 -> ../../testing/TEST-001-platform-baseline-validation.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:42 -> ADR-007-adopt-dual-target-backup-and-recovery.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:44 -> ../../operations/services/owncloud.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:155 -> ../../../compose/webapp.yml
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:156 -> ../../../shared/owncloud/Dockerfile
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:156 -> ../../../shared/owncloud/entrypoint.sh
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:157 -> ../../../env.example
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:158 -> ../../../compose/route.yml
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:159 -> ../../../.forgejo/workflows/61-deploy.yml
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:160 -> ../../operations/services/owncloud.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:161 -> ADR-007-adopt-dual-target-backup-and-recovery.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:161 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:167 -> ADR-003-use-postgresql-as-primary-database.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:168 -> ADR-004-use-authentik-for-central-identity.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:169 -> ADR-007-adopt-dual-target-backup-and-recovery.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:170 -> ../../rfc/RFC-002-family-cloud-platform-strategy.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:171 -> ../../requirements/ROADMAP.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:172 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:89 -> ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:289 -> ../../../.forgejo/workflows/71-backup.yml
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:290 -> ../../operations/services/forgejo.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:291 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:292 -> ../../rfc/RFC-001-reliability-and-recovery-baseline.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:293 -> ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:307 -> ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:308 -> ../../rfc/RFC-001-reliability-and-recovery-baseline.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:309 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:310 -> ../../phases/PHASE-004-observability-and-operational-hardening.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:311 -> ../../testing/TEST-001-platform-baseline-validation.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:312 -> ../../requirements/ROADMAP.md
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:37 -> ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:407 -> ../../../env.example
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:407 -> ../../operations/SERVICE-INVENTORY.md
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:413 -> ../../operations/SERVICE-INVENTORY.md
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:414 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:415 -> ../ARCHITECTURE.md
docs/architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md:427 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:162 -> ../../../scripts/egress-guard.sh
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:162 -> ../../../scripts/egress-policies.conf
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:162 -> ../../operations/EGRESS-CONTROLS.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:162 -> ../../operations/services/confluence.md#outbound-egress-policy
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:181 -> ../../../env.example
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:250 -> ../../../docker-compose.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:251 -> ../../../compose/webapp.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:252 -> ../../../compose/route.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:252 -> ../../../compose/mailsv.yml (archived)
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:256 -> ../../../docker-compose.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:257 -> ../../../compose/webapp.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:257 -> ../../../compose/aiserv.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:258 -> ../../../compose/route.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:258 -> ../../../compose/mailsv.yml (archived)
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:259 -> ../../../scripts/gen-admin-rules.py
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:261 -> ../../../.forgejo/workflows/61-deploy.yml
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:262 -> ../../../env.example
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../../../README.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../ARCHITECTURE.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../DEPLOYMENT-ARCHITECTURE.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../COMPONENT-CATALOGUE.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../../operations/SERVICE-INVENTORY.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../../operations/MONITORING-ALERTING.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:264 -> ../../operations/runbooks/BACKUP-RESTORE.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:266 -> ../../../scripts/egress-guard.sh
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:266 -> ../../../scripts/egress-policies.conf
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:266 -> ../../operations/EGRESS-CONTROLS.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:266 -> ../../operations/services/confluence.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:270 -> ADR-002-use-traefik-as-ingress.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:271 -> ADR-004-use-authentik-for-central-identity.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:272 -> ADR-005-use-litellm-for-ai-routing.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:273 -> ADR-008-standardise-service-naming-storage-and-bind-mounts.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:274 -> ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:275 -> ../DEPLOYMENT-ARCHITECTURE.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:276 -> ../ARCHITECTURE.md
docs/architecture/adr/009-rescope-oci-deployment-and-harden-platform-boundaries.md:277 -> ../../operations/MONITORING-ALERTING.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:278 -> ../../operations/EGRESS-CONTROLS.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:279 -> ../../operations/SERVICE-INVENTORY.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:289 -> ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:291 -> ../../../scripts/egress-guard.sh
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:291 -> ../../../scripts/egress-policies.conf
docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:291 -> ../../operations/EGRESS-CONTROLS.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:35 -> ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:39 -> ../../../env.example
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:40 -> ../../../docker-compose.yml
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:42 -> ../../operations/MONITORING-ALERTING.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:59 -> ADR-008-standardise-service-naming-storage-and-bind-mounts.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:79 -> ../../operations/MONITORING-ALERTING.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:111 -> ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:173 -> ../../../env.example
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:174 -> ../../../docker-compose.yml
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:175 -> ../../../compose
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:176 -> ../../operations/MONITORING-ALERTING.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:180 -> ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:181 -> ../../operations/MONITORING-ALERTING.md
docs/architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md:182 -> ../DEPLOYMENT-ARCHITECTURE.md

There is one typographical path in the preceding generated list: docs/architecture/adr/009-rescope-oci-deployment-and-harden-platform-boundaries.md:277 must be docs/architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md:277.

Dated Compose rename notes

Add notes without rewriting historical decisions:

- ADR-003: compose/dbsvc.yml -> compose/infra.yml.
- ADR-004: compose/authn.yml -> compose/infra.yml; compose/obsvc.yml -> compose/obsvce.yml.
- ADR-005: compose/aiagn.yml -> compose/aiserv.yml.
- ADR-006: compose/wbapp.yml -> compose/webapp.yml.
- LES-002: compose/poste.yml -> compose/mailsv.yml (archived).
- PHASE-002, PHASE-003, and PHASE-004: apply the same dated note when their archived copies are repaired.
- ADR-008:407 is an explicit historical baseline list; retain the old names and do not rewrite it.

Inbound ADR link repairs

docs/architecture/ARCHITECTURE.md:32 -> adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/ARCHITECTURE.md:95 -> adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/ARCHITECTURE.md:112 -> adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/architecture/ARCHITECTURE.md:146 -> adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/ARCHITECTURE.md:150 -> adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/architecture/ARCHITECTURE.md:193 -> adr/README.md
docs/architecture/COMPONENT-CATALOGUE.md:30 -> adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/DATA-FLOW.md:144 -> adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/architecture/DEPLOYMENT-ARCHITECTURE.md:29 -> adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/architecture/DEPLOYMENT-ARCHITECTURE.md:35 -> adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md
docs/operations/BACKUP-RESTORE.md:32 -> ../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/operations/BACKUP-RESTORE.md:352 -> ../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/BACKUP-RESTORE.md:358 -> ../architecture/adr/ADR-008-standardise-service-naming-storage-and-bind-mounts.md
docs/operations/BACKUP-RESTORE.md:536 -> ../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/operations/BACKUP-RESTORE.md:537 -> ../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/operations/DEPLOYMENT.md:46 -> ../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/DEPLOYMENT.md:205 -> ../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/EGRESS-CONTROLS.md:29 -> ../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/MONITORING-ALERTING.md:31 -> ../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/MONITORING-ALERTING.md:31 -> ../architecture/adr/ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md
docs/operations/SERVICE-INVENTORY.md:28 -> ../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/TROUBLESHOOTING.md:74 -> ../architecture/adr/ADR-004-use-authentik-for-central-identity.md
docs/operations/TROUBLESHOOTING.md:106 -> ../architecture/adr/ADR-002-use-traefik-as-ingress.md
docs/operations/TROUBLESHOOTING.md:186 -> ../architecture/adr/ADR-005-use-litellm-for-ai-routing.md
docs/rfc/RFC-001-reliability-and-recovery-baseline.md:118 -> ../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:98 -> ../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:100 -> ../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:126 -> ../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:127 -> ../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/operations/services/confluence.md:90 -> ../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/services/openwebui.md:7 -> ../../architecture/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md
docs/operations/services/owncloud.md:11 -> ../../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/operations/services/owncloud.md:122 -> ../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md
docs/operations/services/owncloud.md:156 -> ../../architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md
docs/operations/services/owncloud.md:157 -> ../../architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md

Index entries

- docs/architecture/adr/README.md:20 — add ADR-001 through ADR-011.
- docs/architecture/adr/README.md:38 — ADR-009 relation: Partially supersedes ADR-008.
- docs/architecture/adr/README.md:39 — ADR-010 status: Proposed; relation: Owner decision pending.
- docs/architecture/adr/README.md:40 — ADR-011 relation: Follow-up: replace git-crypt key.
- docs/rfc/README.md:20 — RFC-001 and RFC-002 rows remain Accepted.
- docs/investigations/README.md:20 — INV-001 remains Draft.
- docs/testing/README.md:20 — TEST-001 remains Not Executed.

Suggested commit message

docs(adr): normalize ADR locations, statuses, and partial supersession

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 4 — Spec Kit Initialization

Purpose: initialize the native workflow owner after a baseline commit.

Prerequisites

- Batch 3 is committed and its commit SHA is recorded.
- A pinned Spec Kit version is supplied by the Project Owner.
- The Spec Kit CLI is already installed and permitted by docs/governance/approved-tooling.md:1.
- No retrospective specifications are created.

Exact command

specify init --here --force --integration codex

The command must be run only after the baseline commit. The actual command output and generated diff must be reviewed.

Files created or edited

- .specify/ — native constitution and governance files.
- specs/ — native specification/plan/task directories.
- specs/README.md — create only if the installed version supports a non-feature index without affecting native enumeration.
- docs/governance/tooling-adoption-register.md:9 — update TA-001 after successful initialization.
- docs/governance/tooling-adoption-register.md:22 — record the actual pinned Spec Kit version.
- docs/governance/tooling-adoption-register.md:24 — record integration codex.
- docs/governance/tooling-adoption-register.md:34 — record primary agent codex.
- docs/README.md:23 — update the specification-index note after compatibility is verified.
- SPEC-KIT-CONSTITUTION-TEMPLATE.md:1 — reconcile into the native constitution, then remove it only with owner approval.

Exact git mv commands

- None. Spec Kit owns its generated native structure.

Link repairs

- docs/README.md:25 — retain the conditional specs/README.md note if compatibility is unknown.
- docs/governance/source-of-truth-register.md:15 — retain native specs/ as authoritative.
- docs/governance/source-of-truth-register.md:16 — retain native plans under specs/.
- docs/governance/source-of-truth-register.md:17 — retain native tasks under specs/.

Index entries

- Add the native specification index only after compatibility verification.
- Do not add SPEC-001; no feature has started.

Suggested commit message

chore(spec): initialize native Spec Kit with codex integration

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 5 — Product Intent and Delivery-Plan Consolidation

Purpose: create canonical product intent and consolidate the legacy roadmap/phase store.

Exact git mv commands

mkdir -p docs/archive/2026-10-product-intent
mkdir -p docs/archive/2026-10-delivery-plan

git mv docs/charter/CHARTER.md docs/archive/2026-10-product-intent/CHARTER.md
git mv docs/requirements/PRD.md docs/archive/2026-10-product-intent/PRD.md
git mv docs/requirements/ROADMAP.md docs/archive/2026-10-delivery-plan/ROADMAP.md
git mv docs/phases/PHASE-001-platform-foundation.md docs/archive/2026-10-delivery-plan/PHASE-001-platform-foundation.md
git mv docs/phases/PHASE-002-identity-and-developer-services.md docs/archive/2026-10-delivery-plan/PHASE-002-identity-and-developer-services.md
git mv docs/phases/PHASE-003-ai-platform.md docs/archive/2026-10-delivery-plan/PHASE-003-ai-platform.md
git mv docs/phases/PHASE-004-observability-and-operational-hardening.md docs/archive/2026-10-delivery-plan/PHASE-004-observability-and-operational-hardening.md
git mv docs/phases/README.md docs/archive/2026-10-delivery-plan/README.md

Files to create

- docs/product/vision.md:1 — restructure CHARTER.md into the Nexora vision template without changing meaning.
- docs/product/requirements.md:1 — restructure PRD.md into the Nexora requirements template without changing meaning.
- docs/architecture/delivery-plan-servicehub-platform.md:1 — consolidate roadmap and phase information using the cross-specification delivery-plan template.
- Archive replacement banners in:
  - docs/archive/2026-10-product-intent/CHARTER.md:1
  - docs/archive/2026-10-product-intent/PRD.md:1
  - docs/archive/2026-10-delivery-plan/ROADMAP.md:1
  - docs/archive/2026-10-delivery-plan/README.md:1

Content mapping

- Vision: problem statement, users, value, goals, non-goals, constraints, success measures, and assumptions from the charter.
- Requirements: scope, user journeys, product requirements, constraints, non-goals, success measures, and open questions from the PRD.
- Delivery plan: current state, implemented capabilities, priorities, phase outcomes, evidence gaps, dependencies, and owner checkpoints.
- Remaining phase work becomes SPEC-NNN only when native work starts; this plan must not create specifications or task lists.

Archive links to add

- docs/archive/2026-10-product-intent/CHARTER.md:131 -> ../../product/requirements.md
- docs/archive/2026-10-product-intent/CHARTER.md:132 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-product-intent/PRD.md:1 — link to ../../product/requirements.md.
- docs/archive/2026-10-delivery-plan/ROADMAP.md:69 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/ROADMAP.md:70 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/ROADMAP.md:71 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/ROADMAP.md:72 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/README.md:30 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/README.md:31 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/README.md:32 -> ../../architecture/delivery-plan-servicehub-platform.md
- docs/archive/2026-10-delivery-plan/README.md:33 -> ../../architecture/delivery-plan-servicehub-platform.md

Metadata repointing

- docs/rfc/RFC-001-reliability-and-recovery-baseline.md:23 — replace PHASE-004 relation with the platform delivery-plan reference.
- docs/rfc/RFC-002-family-cloud-platform-strategy.md:19 — replace CHARTER-001 and ROADMAP-001 references with product-intent and delivery-plan references.

Active link repairs

docs/architecture/adr/ADR-005-use-litellm-for-ai-routing.md:87 -> ../delivery-plan-servicehub-platform.md
docs/architecture/adr/ADR-006-adopt-ocis-with-local-filesystem-storage.md:171 -> ../delivery-plan-servicehub-platform.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:310 -> ../delivery-plan-servicehub-platform.md
docs/architecture/adr/ADR-007-adopt-dual-target-backup-and-recovery.md:312 -> ../delivery-plan-servicehub-platform.md
docs/rfc/RFC-001-reliability-and-recovery-baseline.md:143 -> ../architecture/delivery-plan-servicehub-platform.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:123 -> ../product/requirements.md
docs/rfc/RFC-002-family-cloud-platform-strategy.md:124 -> ../architecture/delivery-plan-servicehub-platform.md
docs/lessons/LES-001-initial-architecture-review.md:90 -> ../architecture/delivery-plan-servicehub-platform.md
docs/lessons/LES-001-initial-architecture-review.md:91 -> ../architecture/delivery-plan-servicehub-platform.md
docs/operations/TROUBLESHOOTING.md:170 -> ../architecture/delivery-plan-servicehub-platform.md
docs/operations/TROUBLESHOOTING.md:202 -> ../architecture/delivery-plan-servicehub-platform.md
docs/operations/services/traefik.md:142 -> ../TROUBLESHOOTING.md#identity-console-rate-limited-429

Index entries

- docs/product/README.md:20 — add vision.md and requirements.md, both Draft until owner approval.
- docs/architecture/README.md:21 — add delivery-plan-servicehub-platform.md.
- docs/README.md:10 — keep Product pointing to product/README.md.
- docs/archive/README.md:20 — add CHARTER, PRD, ROADMAP, PHASE-001..004, and the phase index with replacement links.

Suggested commit message

docs(product): consolidate product intent and platform delivery planning

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 6 — Metadata and Traceability

Purpose: complete source-of-truth mappings and all area indexes.

Exact git mv commands

- None.

Files to edit

Adoption metadata in docs/governance/governance-adoption.md was completed in Batch 0 (Step 2), including the unchanged central-repository marker and Notes entries. No edits to that file are scheduled in Batch 6.

- AGENTS.md:1 — replace <PROJECT_NAME> with ServiceHub.
- AGENTS.md:46 through AGENTS.md:48 — retain unresolved test/build/lint placeholders until the owner supplies commands.
- CENTRAL-GOVERNANCE-REFERENCE.md:6 — https://git.example.com/Nexora/governance.
- docs/governance/source-of-truth-register.md:14 — confirm docs/product/vision.md and docs/product/requirements.md.
- docs/governance/source-of-truth-register.md:20 — confirm docs/architecture/adr/.
- docs/governance/source-of-truth-register.md:21 — record the two actual delivery-plan filenames.
- docs/governance/source-of-truth-register.md:31 — server .env (mode 600) and Forgejo Actions secrets.
- docs/governance/source-of-truth-register.md:33 — add project-specific category: service guides at docs/operations/services/, supported by shared/<product>/ implementation.
- docs/governance/tooling-adoption-register.md:9 — Spec Kit state becomes Enabled only after successful Batch 4 initialization.
- docs/governance/tooling-adoption-register.md:10 — primary agent codex; retain installed-version placeholder if unknown.
- docs/governance/tooling-adoption-register.md:22 — pinned Spec Kit version after initialization.
- docs/governance/tooling-adoption-register.md:24 — integration codex.
- docs/governance/tooling-adoption-register.md:34 — agent codex.
- README.md:1 — replace scaffold title with a ServiceHub project title or explicitly retain it as provenance.
- docs/README.md:1 — replace <PROJECT_NAME> with ServiceHub.
- docs/architecture/README.md:4 — replace <PROJECT_NAME> with ServiceHub.
- docs/operations/README.md:4 — replace <PROJECT_NAME> with ServiceHub.
- docs/operations/README.md:18 — add the actual operational model index.
- docs/operations/runbooks/README.md:20 — add RUNBOOK, BACKUP-RESTORE, DEPLOYMENT.
- docs/lessons/README.md:20 — add LES-001 and LES-002.
- docs/investigations/README.md:20 — add INV-001.
- docs/testing/README.md:20 — add TEST-001.
- docs/releases/README.md:20 — leave the release table empty and state that release 1.0.0 is post-adoption work.
- docs/archive/README.md:20 — add every archive entry and replacement link.
- docs/architecture/adr/README.md:20 — confirm ADR-001..011 rows.
- docs/rfc/README.md:20 — confirm RFC-001 and RFC-002 rows.

Index entries to add

- Architecture: ARCHITECTURE.md, COMPONENT-CATALOGUE.md, DATA-FLOW.md, DEPLOYMENT-ARCHITECTURE.md, SYSTEM-CONTEXT.md, adr/README.md, delivery-plan-servicehub-platform.md.
- Operations: DEVELOPMENT.md, EGRESS-CONTROLS.md, INSTALLATION.md, MONITORING-ALERTING.md, SERVICE-INVENTORY.md, TROUBLESHOOTING.md, runbooks/, and services/.
- Services: all 18 guides currently under docs/operations/services/.
- Lessons: LES-001-initial-architecture-review.md, LES-002-stalwart-allowlist-broke-bulwark-login.md (archived).
- Investigation: INV-001-architecture-and-documentation-gap-analysis.md.
- Testing: TEST-001-platform-baseline-validation.md.
- RFC: RFC-001-reliability-and-recovery-baseline.md, RFC-002-family-cloud-platform-strategy.md.
- Product: vision.md, requirements.md.
- Archive: all migrated legacy items.

Suggested commit message

docs(governance): complete source-of-truth mappings and traceability indexes

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 7 — Validation

Purpose: validate the migrated tree without claiming test, restore, or release completion.

Exact git mv commands

- None.

Validation checks

git diff --check
git ls-files
git check-attr filter diff merge -- shared/traefik/advanced/selfsigncert/*

Required validation assertions:

- No tracked .env or servicehub.key.
- The only tracked sensitive material is the five known git-crypt certificate paths:
  - shared/traefik/advanced/selfsigncert/certroot.crt
  - shared/traefik/advanced/selfsigncert/selfcert.key
  - shared/traefik/advanced/selfsigncert/selfcert.pem
  - shared/traefik/advanced/selfsigncert/selfcert.pfx
  - shared/traefik/advanced/selfsigncert/selfcertCA.crt
- .gitattributes:3 through .gitattributes:6 apply git-crypt to all certificate extensions.
- No broken relative Markdown links.
- No references to docs/adr/, docs/products/, docs/phases/, docs/requirements/ROADMAP.md, docs/requirements/PRD.md, or docs/charter/CHARTER.md remain outside docs/archive/.
- No stale Compose link targets remain for dbsvc, authn, depot, wbapp, aiagn, obsvc, or poste.
- shared/grafana/alloy/README.md:7, :69, :70, and :71 resolve.
- Lower-case template paths resolve after the Batch 1 copy.
- ADR index status agrees with ADR front matter.
- ADR-009 is Accepted; ADR-010 remains Proposed and is listed as an open owner decision.
- TEST-001 remains Not Executed.
- No release 1.0.0 record is created.
- No SPEC-001 is created by migration.
- No adoption state is advanced to Adopted.

Commands that were not run during this read-only plan:

- No tests.
- No build.
- No lint.
- No Spec Kit initialization.
- No migration commands.

Suggested commit message

docs: validate governance migration and record remaining gaps

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

### Batch 8 — Legacy Archive

Purpose: complete the archive after replacements exist.

Exact git mv commands

- None.

The legacy ADR index move was performed in Batch 3. The uppercase template moves were performed in Batch 1 because APFS requires the move before the lower-case copy. No second move is required.

Files to edit

- docs/archive/README.md:20 — add:
  - legacy ADR index;
  - legacy templates;
  - CHARTER and PRD;
  - ROADMAP and PHASE-001..004;
  - phase index.
- docs/archive/2026-10-delivery-plan/README.md:35 — replace the uppercase phase-template link with ../2026-10-legacy-templates/PHASE-TEMPLATE.md, or remove the template reference and state that native plans/delivery plans replace it.

Index entries

The archive index must contain, for every item, origin path, archived date 2026-10-12, reason, and replacement link.

Suggested commit message

docs(archive): retire displaced legacy governance records

Run: python3 ~/Documents/workspaces/nexora-audits/check-links.py
The batch is complete only if no new broken links appear.

Completed within Batches 3 and 5; archive register verified by prompt 19 on 2026-10-13.

## 9. Owner Decisions Still Open

1. ADR-010: accept, reject, defer, or revise the Oracle APM/logging design. It remains Proposed and must not be assumed accepted.
2. Migration map approval: approve this plan before any batch is executed.
3. Central URL: provide the concrete Forgejo host represented by https://git.example.com.
4. Spec Kit version: provide the pinned Spec Kit CLI version and confirm it is installed.
5. Baseline commit: identify the exact Batch 3 commit SHA to use for Spec Kit initialization.
6. Validation commands: provide project test, build, and lint commands for AGENTS.md:46 through AGENTS.md:48.
7. Product intent approval: approve the restructured vision.md and requirements.md.
8. Delivery-plan approval: approve the platform delivery plan and its treatment of remaining phase work.
9. Archive approval: approve the archive paths and replacement links.
10. Post-adoption work: assign owners and dates for TEST-001 execution, restore exercise, rollback validation, alert-delivery validation, and release 1.0.0.
11. ADR-009 follow-ups: assign runtime validation and local aiserv observability work; these are not migration tasks.
12. Git-crypt key replacement: assign the operational owner and timing for the ADR-011 follow-up.
13. Service ownership/criticality: resolve the audit’s Requires owner review status for service inventory entries.
14. Adoption completion: only the Project Owner may later move the state from Adoption in Progress to Adopted or Adopted with Exceptions.

## 10. Proposed Source-of-Truth Register Updates

Update docs/governance/source-of-truth-register.md:5 with these project-specific mappings:

| Category | Authoritative location | Supporting location | Notes |
|---|---|---|---|
| Product intent | docs/product/vision.md, docs/product/requirements.md | docs/archive/2026-10-product-intent/ | Archived originals are non-authoritative |
| Architecture decisions | docs/architecture/adr/ | docs/archive/2026-10-legacy-adr-index/ | Canonical ADR location |
| Cross-specification delivery plans | docs/architecture/delivery-plan-<slug>.md | docs/archive/2026-10-delivery-plan/ | Governance adoption and platform plans |
| Service guides | docs/operations/services/ | shared/<product>/ | Project-specific operations category |
| Procedures | docs/operations/runbooks/ | docs/operations/ | RUNBOOK, BACKUP-RESTORE, DEPLOYMENT |
| Native specifications, plans, tasks | specs/ | specs/README.md if compatible | Created only by native Spec Kit |
| Secrets | Outside the repository: server .env (mode 600) and Forgejo Actions secrets | .gitattributes | Names only, never values |

No exception is proposed for the certificate material because OD-1 explicitly accepts the encrypted tracked state.

## 11. Proposed Exceptions

None at this time.

A conditional exception may be required only if the installed Spec Kit version cannot tolerate specs/README.md. In that case, record the reason in docs/governance/documentation-exceptions.md and keep the specification index in docs/README.md:23.

## 12. Audit Inventory

### Documentation Files

All tracked Markdown/documentation files at the audited commit:

- Root: README.md, ADOPTION-INSTRUCTIONS.md, CENTRAL-GOVERNANCE-REFERENCE.md, SPEC-KIT-CONSTITUTION-TEMPLATE.md, AGENTS.md.
- Governance: docs/README.md, docs/governance/README.md, docs/governance/approved-tooling.md, docs/governance/documentation-exceptions.md, docs/governance/governance-adoption.md, docs/governance/source-of-truth-register.md, docs/governance/tooling-adoption-register.md.
- Architecture: docs/architecture/ARCHITECTURE.md, COMPONENT-CATALOGUE.md, DATA-FLOW.md, DEPLOYMENT-ARCHITECTURE.md, README.md, SYSTEM-CONTEXT.md, adr/README.md.
- ADRs: docs/adr/ADR-001-use-docker-compose.md, ADR-002-use-traefik-as-ingress.md, ADR-003-use-postgresql-as-primary-database.md, ADR-004-use-authentik-for-central-identity.md, ADR-005-use-litellm-for-ai-routing.md, ADR-006-adopt-ocis-with-local-filesystem-storage.md, ADR-007-adopt-dual-target-backup-and-recovery.md, ADR-008-standardise-service-naming-storage-and-bind-mounts.md, ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md, ADR-010-collect-oci-logs-and-integrate-with-oracle-apm.md, README.md.
- RFCs: docs/rfc/README.md, RFC-001-reliability-and-recovery-baseline.md, RFC-002-family-cloud-platform-strategy.md.
- Investigations: docs/investigations/README.md, INV-001-architecture-and-documentation-gap-analysis.md.
- Lessons: docs/lessons/README.md, LESSON-001-initial-architecture-review.md, LESSON-002-stalwart-allowlist-broke-bulwark-login.md (archived).
- Testing: docs/testing/README.md, TEST-001-platform-baseline-validation.md.
- Operations: docs/operations/README.md, BACKUP-RESTORE.md, DEPLOYMENT.md, DEVELOPMENT.md, EGRESS-CONTROLS.md, INSTALLATION.md, MONITORING-ALERTING.md, RUNBOOK.md, SERVICE-INVENTORY.md, TROUBLESHOOTING.md, runbooks/README.md.
- Product scaffold: docs/product/README.md, requirements-template.md, vision-template.md.
- Product/service guides: docs/products/README.md, authentik.md, bulwark.md (archived), confluence.md, fastcrw.md, forgejo.md, grafana.md, hermesagent.md, litellm.md, llamacpp.md, mariadb.md, openwebui.md, owncloud.md, postgresql.md, stalwart.md (archived), traefik.md, victorialogs.md, victoriametrics.md, wordpress.md.
- Planning: docs/charter/CHARTER.md, docs/requirements/PRD.md, ROADMAP.md, docs/phases/README.md, PHASE-001-platform-foundation.md, PHASE-002-identity-and-developer-services.md, PHASE-003-ai-platform.md, PHASE-004-observability-and-operational-hardening.md.
- Templates: docs/templates/README.md, upper-case ADR-TEMPLATE.md, INVESTIGATION-TEMPLATE.md, LESSON-TEMPLATE.md, PHASE-TEMPLATE.md, RELEASE-TEMPLATE.md, RFC-TEMPLATE.md, TEST-TEMPLATE.md, plus lower-case cross-specification-delivery-plan-template.md, lesson-learned-template.md, runbook-template.md, temporary-work-handoff-template.md, test-plan-template.md, tooling-adoption-entry-template.md, verification-summary-template.md.
- Releases: docs/releases/README.md, RELEASE-TEMPLATE.md.
- Archive scaffold: docs/archive/README.md.
- Other Markdown: shared/grafana/alloy/README.md, shared/hermesagent/default/SOUL.md.

### Agent Instructions and Tool Configuration

- AGENTS.md
- ADOPTION-INSTRUCTIONS.md
- CENTRAL-GOVERNANCE-REFERENCE.md
- .codex/config.toml.example
- opencode.json.example
- shared/hermesagent/default/SOUL.md

### CI Workflows

- .forgejo/workflows/61-deploy.yml
- .forgejo/workflows/71-backup.yml

### Environment Examples

- env.example
- .codex/config.toml.example
- opencode.json.example
- shared/hermesagent/default/env.example

No tracked .env or servicehub.key was found.

### Deployment and Runtime Definitions

- docker-compose.yml
- compose/aiserv.yml, devops.yml, infra.yml, mailsv.yml (archived), obsvce.yml, route.yml, webapp.yml
- shared/*/Dockerfile
- shared/fastcrw/chromium/compose.yml, shared/fastcrw/compose.yml, shared/fastcrw/lightpanda/compose.yml
- shared/searxng/compose.yml
- shared/wordpress/compose.yml
- .forgejo/workflows/61-deploy.yml
- .forgejo/workflows/71-backup.yml
- docs/operations/DEPLOYMENT.md
- docs/architecture/DEPLOYMENT-ARCHITECTURE.md

### Decision-Bearing Source Comments

These files contain comments or configuration notes that record implementation decisions and should be retained unchanged unless a later governed artifact requires otherwise:

- compose/aiserv.yml, compose/devops.yml, compose/infra.yml, compose/mailsv.yml (archived), compose/obsvce.yml, compose/webapp.yml
- scripts/egress-guard.sh, scripts/egress-policies.conf, scripts/gen-admin-rules.py, scripts/setup.sh
- shared/fastcrw/chromium/compose.yml, shared/fastcrw/config.docker.toml
- shared/forgejo/actions/entrypoint.sh
- shared/hermesagent/start-gateways.sh
- shared/litellm/config.default.yaml, shared/litellm/smartrouter.py
- shared/searxng/settings.yml
- shared/stalwart/acme-export.sh (archived), shared/stalwart/entrypoint.sh (archived)
- shared/traefik/advanced/admin-routers.yml, shared/traefik/advanced/middlewares-security.yml
- shared/wordpress/etc/nginx/nginx.conf

Examples include scripts/egress-guard.sh:2, scripts/egress-policies.conf:1, shared/litellm/smartrouter.py:10, shared/hermesagent/start-gateways.sh:10, shared/stalwart/entrypoint.sh:5 (archived), and compose/aiserv.yml:2.

### Planning and Task Stores

Found:

- docs/charter/CHARTER.md
- docs/requirements/PRD.md
- docs/requirements/ROADMAP.md
- docs/phases/README.md
- docs/phases/PHASE-001-platform-foundation.md
- docs/phases/PHASE-002-identity-and-developer-services.md
- docs/phases/PHASE-003-ai-platform.md
- docs/phases/PHASE-004-observability-and-operational-hardening.md

Not found:

- .planning/
- docs/plans/
- docs/superpowers/
- tasks.md
- TODO.md
- standalone roadmap files outside docs/requirements/ROADMAP.md

## 13. Completion Criteria

This migration is ready for Project Owner acceptance only when:

- Batch 0 records the owner decisions.
- Batch 1 restores the missing lower-case templates after archiving upper-case templates.
- Batch 2 completes the product-guide, lesson, and runbook moves with valid links.
- Batch 3 moves all ADRs to docs/architecture/adr/, records ADR-009 Accepted, and leaves ADR-010 Proposed pending owner decision.
- Batch 4 initializes native Spec Kit with codex after a recorded baseline commit.
- Batch 5 creates docs/product/vision.md, docs/product/requirements.md, and docs/architecture/delivery-plan-servicehub-platform.md.
- Batch 6 completes metadata, source-of-truth mappings, and indexes.
- Batch 7 validates links, git-crypt attributes, sensitive-file absence, statuses, and archive replacements.
- Batch 8 completes the archive register after the old ADR index is archived in Batch 3.
- TEST-001, restore validation, alert validation, rollback validation, and release 1.0.0 remain explicitly recorded as post-adoption gaps. Replace the git-crypt key (part of the key was displayed on 2026-10-12) and update the GIT_CRYPT_KEY Forgejo Actions secret.

No files were modified during this read-only planning task.
