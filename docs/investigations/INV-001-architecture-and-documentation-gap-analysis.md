---
project: ServiceHub
project_code: SVCHUB
document_type: INVESTIGATION
document_id: INV-001
title: Architecture and Documentation Gap Analysis
version: "1.0"
status: Draft
lifecycle_stage: Discovery
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - investigation
  - architecture
  - documentation
related_documents:
  - ARCHITECTURE
  - LESSON-001
  - TEST-001
---

# INV-001: Architecture and Documentation Gap Analysis

## Investigation Summary

The repository contains a substantial ServiceHub implementation but lacked a repository documentation home, stable planning and decision records, agent guidance, and validated operational evidence before this documentation change.

## Scope

Reviewed:

- Root README, environment template, `.gitattributes`, `.gitignore`, and Git state.
- Root and domain Compose files.
- All Dockerfiles and optional Compose definitions.
- Forgejo deployment, backup, and remote-access workflows.
- Setup script and shared configuration examples.
- Service READMEs, health checks, routes, dependencies, persistence, telemetry, and AI routing.
- Git tags and recent history.

Not reviewed through runtime execution:

- Live staging or production hosts.
- Actual secrets or secret values.
- Forgejo runtime settings.
- Authentik application configuration.
- DNS, certificate issuance, firewall state.
- Backup execution history or restore capability.

## Evidence Reviewed

- [docker-compose.yml](../../docker-compose.yml)
- [compose/](../../compose/)
- [.forgejo/workflows/](../../.forgejo/workflows/)
- [scripts/setup.sh](../../scripts/setup.sh)
- [env.example](../../env.example)
- [shared/](../../shared/)
- Root README and Git metadata

## Findings

1. **Documentation gap:** no `docs/` tree or repository `AGENTS.md` existed, and the root README was the main overview.
2. **Architecture is implementable from source:** Compose, Dockerfiles, routes, health checks, dependencies, and persistence are mostly explicit.
3. **Identity is partial:** Authentik, Grafana forward auth, and Stalwart LDAP evidence exist, but application coverage is not fully encoded.
4. **Backup without proven recovery:** PostgreSQL dumps and full archives exist; restore, off-host copy, encryption, RPO, and RTO do not.
5. **Test evidence is absent:** workflows and health checks exist, but no complete baseline execution report or Git release tags were found.
6. **Observability is configured but unverified:** collection, stores, dashboards, and Grafana alert rendering exist; delivery, ownership, thresholds, and retention do not.
7. **Security review is needed:** privileged containers, Docker socket access, host filesystem mounts, direct host ports, and passwordless sudo increase blast radius.
8. **Deployment lacks rollback and post-checks:** application deployment is constrained with `--no-deps`, but no rollback or health validation follows.
9. **Release governance is absent:** no tags or release records exist.
10. **Service ownership and criticality are undefined.**

## Impact

- Reviewers and agents must infer architecture from scattered files.
- Completed work may be mistaken for tested or approved work.
- A host or database incident could exceed recovery capability because restore is unproven.
- Identity or routing failures may be difficult to diagnose consistently.
- Alerts may exist as dashboards without reaching an owner.
- Release changes may lack rollback and evidence.

## Root Cause

Implementation evolved across Compose, service-specific READMEs, and workflows without a repository-level documentation and governance layer. The root `.gitignore` also excluded `/docs/` in the committed state, discouraging a versioned documentation tree.

This is an inferred process cause from repository structure, not an owner-approved retrospective.

## Recommendations

- Keep `docs/` authoritative and update it with implementation changes.
- Review the charter, requirements, architecture, ADRs, and RFC decisions.
- Execute TEST-001 in staging.
- Decide and implement RFC-001 recovery controls.
- Define alert ownership and notification testing.
- Review privileged access, direct ports, and sudo scope.
- Define and test deployment rollback.
- Create the first governed release only after evidence exists.
- Link Confluence to `docs/README.md` rather than duplicating content.

## Preventive Actions

- Require documentation and index updates in pull requests.
- Require ADRs for architecture decisions and RFCs for significant proposals.
- Require test evidence and release notes before `Completed` or governed release status.
- Add link, metadata, ID, and secret validation to documentation review.
- Maintain a service inventory whenever Compose topology changes.
- Keep restoration tests periodic after RFC-001 is decided.

## Open Questions

- Which runtime state and settings exist only in staging or production?
- What are the approved RPO, RTO, retention, and off-host requirements?
- Which applications are actually integrated with Authentik?
- Which service owns each alert and escalation?
- What firewall protects published AI and observability ports?
- What is the approved rollback procedure?
- What is the first release scope and version?
- Is a family file synchronisation requirement validated?

## Outcome

**Preliminary.** Repository evidence supports the documentation gaps and implementation observations, but runtime validation, owner decisions, and operational testing are required before closing the investigation.

## Related Documents

- [Architecture](../architecture/ARCHITECTURE.md)
- [Lessons](../lessons/LESSON-001-initial-architecture-review.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)
- [RFC-001](../rfc/RFC-001-reliability-and-recovery-baseline.md)

