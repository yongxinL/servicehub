---
project: ServiceHub
project_code: SVCHUB
document_type: CHARTER
document_id: CHARTER-001
title: ServiceHub Project Charter
version: "1.0"
status: Proposed
lifecycle_stage: Initiation
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - governance
  - charter
related_documents:
  - PRD-001
  - ROADMAP-001
  - ARCHITECTURE
---

# ServiceHub Project Charter

## Executive Summary

ServiceHub is a self-hosted HomeLab services platform assembled from Docker Compose domains behind a single Traefik ingress. The repository provisions or documents infrastructure, identity, source control and CI, web applications, AI routing and inference, email, and observability services on a shared Docker network.

This charter proposes the project's purpose and governance. Repository implementation is evidence of technical direction, not evidence that every objective, recovery capability, or operational control has been accepted or validated.

## Problem Statement

HomeLab services accumulate across independent configuration files, service-specific authentication, storage paths, deployment methods, and documentation locations. Without a governed repository-backed record, administrators and agents cannot reliably distinguish current implementation, recommended changes, and unverified operational claims.

## Vision

Provide a coherent, reviewable, and recoverable service platform whose architecture, decisions, requirements, tests, releases, and operational knowledge are maintained with the implementation in one repository.

## Objectives

- Maintain one repository-backed documentation source for ServiceHub.
- Make service dependencies, routes, persistence, identity, and telemetry understandable before runtime inspection.
- Separate implementation evidence from proposals and unverified operational claims.
- Support safe local administration and governed remote deployment.
- Establish traceable requirements, architecture decisions, phases, tests, releases, and lessons.
- Enable human review, Forgejo browsing, coding-agent retrieval, and future static documentation publishing.

## In Scope

- Docker Compose platform definition and its included domain files.
- Traefik ingress, TLS, Authentik identity, PostgreSQL, and MariaDB.
- Forgejo and its Actions runner.
- Confluence, Open WebUI, Hermes, LiteLLM, llama.cpp, Stalwart, and Bulwark.
- VictoriaMetrics, VictoriaLogs, Grafana Alloy, and Grafana.
- Repository-backed deployment and backup workflows.
- Architecture, requirements, RFCs, ADRs, phases, testing, operations, releases, lessons, and investigations.

## Out of Scope

- Designing or silently changing application or infrastructure behaviour through documentation.
- A dedicated family file-cloud platform at this stage.
- Guaranteed production availability, security, recovery, or compliance outcomes.
- Confluence or Forgejo Wiki content as the authoritative documentation store.
- Ownership, staffing, budget, approval, or completion claims not present in repository evidence.
- Arbitrary access to real secrets, private keys, recovery material, or production hostnames.

## Stakeholders

- Project owner and maintainer: George Li.
- Repository reviewers and future maintainers.
- HomeLab administrators operating staging or production.
- Developers and coding agents changing the stack.
- Family or user groups consuming hosted services.

External stakeholder names, teams, approval bodies, and escalation contacts are `TBD`.

## Users

- Administrators configuring domains, credentials, TLS, storage, deployment, backup, and monitoring.
- Developers reviewing Compose changes and service documentation.
- Forgejo Actions operators running deployment, backup, and remote-access workflows.
- AI users and agent operators interacting with Open WebUI or Hermes.
- End users accessing identity, repository, web, email, AI, or observability services.

## Success Criteria

- Every required documentation record exists with unique metadata and resolving links.
- Architecture claims identify repository evidence or are marked Inferred, Proposed, or TBD.
- No real secret or recovery value appears in documentation.
- Test execution, phase completion, and release approval are not claimed without evidence.
- Backup restoration, recovery objectives, alert ownership, and runtime health remain explicitly unverified until tested.
- Documentation changes accompany relevant implementation changes.

## Constraints

- Docker Compose 2.20+ `include` support and the current service names are preserved.
- Existing ports, networks, volumes, environment variables, images, and routes are not changed for documentation convenience.
- Remote deployment uses SSH, Forgejo repository secrets, and passwordless sudo on target hosts.
- Sensitive files may be git-crypt protected; documentation must never reproduce their values.
- Australian English and standard Markdown are used where natural.

## Assumptions

- The repository is intended to remain the authoritative project record.
- Staging and production exist as workflow targets, but their runtime state is `Not yet verified`.
- The owner will review this charter before it becomes Accepted or Active.
- Confluence and any future wiki act as portals that link back to this repository.

## Major Risks

- Restores are not documented or validated in the repository.
- Runtime health, TLS issuance, authentication, AI routing, and monitoring are not evidenced by a full test report.
- Dynamic host exposure exists for several AI and observability APIs and requires review.
- High-privilege mounts expose Docker or host filesystem state to platform containers.
- Documentation could drift if implementation changes do not update the same records.
- Sensitive local and git-crypt protected material requires careful handling.

## Governance Model

- The repository owner approves this charter and material scope changes.
- Architecture decisions require an ADR.
- Significant cross-cutting proposals require an RFC.
- Releases require test evidence and release notes.
- Indexes are maintained with their child records.
- Proposed work does not become Completed without evidence.
- External portals link to, rather than duplicate, authoritative repository documents.

## Related Documents

- [Product requirements](../requirements/PRD.md)
- [Roadmap](../requirements/ROADMAP.md)
- [Architecture overview](../architecture/ARCHITECTURE.md)
- [Architecture decisions](../adr/README.md)
- [Operations index](../operations/README.md)

