# Delivery Plan: ServiceHub Platform

| Field | Value |
|---|---|
| Title | Delivery Plan: ServiceHub Platform |
| Status | Approved |
| Owner | project-owner |
| Created | 2026-10-13 |
| Updated | 2026-10-13 |
| Approved by project-owner / owner-self-approval / 2026-10-13 | |
| Trigger | Governance adoption |

## 1. Objective

Deliver the ServiceHub self-hosted HomeLab services platform through a governed sequence of phases: Platform Foundation, Identity and Developer Services, AI Platform, and Observability and Operational Hardening. Each phase produces implementation and evidence records that culminate in a governed first release. The repository currently contains implementation associated with all four phases, but Git history provides implementation activity only; the repository does not contain a formal phase completion record or a complete runtime validation report. Current state is therefore implemented in part, not yet verified as a governed release.

## 2. Participating work

| Item | Type | Plan record | Status |
|---|---|---|---|
| PHASE-001 Platform Foundation | Phase | docs/archive/2026-10-delivery-plan/PHASE-001-platform-foundation.md | Implemented (owner-confirmed 2026-10-13); validation evidence pending (TEST-001) |
| PHASE-002 Identity and Developer Services | Phase | docs/archive/2026-10-delivery-plan/PHASE-002-identity-and-developer-services.md | Implemented (owner-confirmed 2026-10-13); oCIS Authentik OIDC configuration pending (requirements.md open question 1); validation evidence pending (TEST-001) |
| PHASE-003 AI Platform | Phase | docs/archive/2026-10-delivery-plan/PHASE-003-ai-platform.md | Implemented (owner-confirmed 2026-10-13); validation evidence pending (TEST-001) |
| PHASE-004 Observability and Operational Hardening | Phase | docs/archive/2026-10-delivery-plan/PHASE-004-observability-and-operational-hardening.md | Partial implementation; restoration and release controls incomplete |

## 3. Dependencies and order

1. **PHASE-001 Platform Foundation** must complete first (Compose, network, ingress, data, deployment baseline).
2. **PHASE-002 Identity and Developer Services** depends on healthy Traefik and PostgreSQL (Authentik, ForgeJo, runner, application identity coverage).
3. **PHASE-003 AI Platform** depends on PostgreSQL for LiteLLM usage data, model availability, and cloud credentials (Hermes, LiteLLM, llama.cpp, Open WebUI).
4. **PHASE-004 Observability and Operational Hardening** depends on healthy metrics and log stores, working Alloy host and Docker access, backup target secrets, and approved retention/RPO/RTO/encryption controls (metrics, logs, dashboards, backup, restoration, alerting, release controls).

The Cloud Drive Platform (oCIS with Authentik OIDC and local filesystem storage under ADR-006) and Dual-Target Backup and Recovery (ADR-007) are accepted roadmap entries that span phases.

## 4. Milestones and owner checkpoints

| Milestone | Entry criteria | Exit criteria | Owner checkpoint |
|---|---|---|---|
| Platform Foundation validated | Compose project, ingress, databases, environment template, setup script, deployment and backup workflows in repository | `docker compose config` succeeds; all default services reach expected health states; HTTP redirects to HTTPS and each intended host route responds; TLS trust and renewal match selected mode; databases persist and are reachable by dependent services; remote-access workflow checks pass; deployment completes without unintended foundational replacement; evidence links attached | Project owner |
| Identity and Developer Services validated | Healthy Traefik and PostgreSQL; Authentik initial setup; ForgeJo repository secrets and runner registration; SSH target secrets; public repository URL | Authentik reaches health and initial setup complete; protected routes enforce expected authentication; oCIS authenticates through Authentik and provides file access only after successful OIDC flow; ForgeJo registration disabled and access review recorded; runner registration and labels validated; deployment workflows execute as designed; LDAP mail authentication and recovery path tested; break-glass procedures documented and tested; evidence links attached | Project owner |
| AI Platform validated | PostgreSQL for LiteLLM; model availability and local resources; cloud provider credentials; client configuration and authentication | Local health and inference request succeed; cloud route succeeds when configured without recording credentials; privacy requests use local routing and fallback behaviour matches policy; large, complex, unhealthy-local, and context-window cases route as configured; Hermes and Open WebUI authenticate and reach intended target; LiteLLM metrics appear in VictoriaMetrics; test evidence linked | Project owner |
| Observability and Operational Hardening validated | Healthy metrics and log stores; working Alloy; backup target secrets; approved retention/RPO/RTO/encryption; notification channels and owners; staging runtime and release evidence | Expected metrics and logs appear in Grafana; dashboards resolve data sources; alert delivery tested to named destination and owner; backups meet approved scope and retention; restore succeeds in isolated test; RPO and RTO approved and measured; rollback tested; release evidence and post-release validation recorded; security review actions tracked; evidence links attached | Project owner |
| First governed release | All phase acceptance evidence linked and accepted; release governance satisfied | Release record created; migration and rollback notes recorded; post-release validation complete | Project owner |

## 5. Migration and rollback windows

Not recorded in source documents.

## 6. Risks

- Restore procedures exist (docs/operations/runbooks/BACKUP-RESTORE.md) but have not been exercised; recovery capability is unproven (requirements.md open question 2).
- Runtime health, TLS issuance, authentication, AI routing, and monitoring are not evidenced by a full test report.
- Dynamic host exposure exists for several AI and observability APIs and requires review.
- High-privilege mounts expose Docker or host filesystem state to platform containers.
- Documentation could drift if implementation changes do not update the same records.
- Sensitive local and git-crypt protected material requires careful handling.
- Identity integrations may be configured only at runtime.
- Local accounts may diverge from central identity policy.
- Runner secret or SSH secret compromise.
- Runner-hosted jobs have broad target access.
- Foundational services are outside automated deployment.
- Resource exhaustion or slow local startup for AI models.
- Heuristic routing misclassification.
- Cloud fallback may externalise privacy-sensitive content.
- Published API ports may be reachable beyond intended clients.
- Optional web-search components are not in the default stack.
- Telemetry exists without confirmed data or alert delivery.
- Dual-target configuration exists but transfers and encryption controls are not runtime-validated.
- Privileged and host-mounted collectors increase blast radius.

**Evidence gaps from the phases (carried as risks, not completed items):**
- TEST-001 platform baseline validation not executed (foundation, AI, and operational portions)
- Restore rehearsal and documented recovery evidence missing
- Alert delivery not tested to named destination and owner
- Rollback behaviour not defined or tested
- First governed release not defined or executed

## 7. Communication and coordination

Not recorded in source documents.

## 8. Completion criteria

This plan is complete when:

- All four phases have acceptance evidence linked and accepted by the project owner.
- The first governed release is defined with migration and rollback notes and post-release validation recorded.
- Runtime baseline test (TEST-001) executes in staging without changing implementation solely for documentation.

**Future SPEC-NNN candidates (not created here):**
- Restore rehearsal and documented recovery evidence (from Phase 4 follow-up)
- Encryption, retention policy, and restoration automation for ADR-007 backup targets (from roadmap Future Candidates)
- Consolidated alert routing, severity policy, ownership, and alert tests (from roadmap Future Candidates)
- Security review of dynamic ports, Docker socket access, privileged containers, and host mounts (from roadmap Future Candidates)
- Full identity integration coverage and break-glass controls (from roadmap Future Candidates)
- Static documentation publishing configuration (from roadmap Future Candidates)
- Office or collaboration integration beyond initial oCIS file-sharing scope (from roadmap Future Candidates)

**Deferred items (not in scope of this plan):**
- MinIO, OCI Object Storage, and S3 storage for the initial oCIS deployment
- Nextcloud or a broader collaboration suite unless ADR-006 is revised
- Alternative cloud-drive platforms unless requirements change
- Release dates not present in repository evidence
- Production hostname, approval, ownership, and recovery-objective claims
