# Product Vision - ServiceHub

| Field | Value |
|---|---|
| Title | Product Vision |
| Status | Draft |
| Owner | project-owner |
| Created | 2026-10-13 |
| Updated | 2026-10-13 |
| Approved by / mode / date | |

## 1. Problem statement

HomeLab services accumulate across independent configuration files, service-specific authentication, storage paths, deployment methods, and documentation locations. Without a governed repository-backed record, administrators and agents cannot reliably distinguish current implementation, recommended changes, and unverified operational claims.

## 2. Target users

- Administrators configuring domains, credentials, TLS, storage, deployment, backup, and monitoring.
- Developers reviewing Compose changes and service documentation.
- Forgejo Actions operators running deployment and backup workflows.
- AI users and agent operators interacting with Open WebUI or Hermes.
- End users accessing identity, repository, web, email, AI, or observability services.
- Coding and documentation agents.
- Family or internal service users.

External stakeholder names, teams, approval bodies, and escalation contacts are `TBD`.

## 3. Value proposition

ServiceHub is a self-hosted HomeLab services platform assembled from Docker Compose domains behind a single Traefik ingress. The repository provisions or documents infrastructure, identity, source control and CI, web applications, AI routing and inference, email, and observability services on a shared Docker network.

This vision provides a coherent, reviewable, and recoverable service platform whose architecture, decisions, requirements, tests, releases, and operational knowledge are maintained with the implementation in one repository. It proposes the project's purpose and governance. Repository implementation is evidence of technical direction, not evidence that every objective, recovery capability, or operational control has been accepted or validated.

## 4. Goals

- Maintain one repository-backed documentation source for ServiceHub.
- Make service dependencies, routes, persistence, identity, and telemetry understandable before runtime inspection.
- Separate implementation evidence from proposals and unverified operational claims.
- Support safe local administration and governed remote deployment.
- Establish traceable requirements, architecture decisions, phases, tests, releases, and lessons.
- Enable human review, Forgejo browsing, coding-agent retrieval, and future static documentation publishing.
- Provide a coherent self-hosted platform for HomeLab administration, developer services, web collaboration, family file storage, AI workloads, email, and observability, with repository-backed governance and operations knowledge.

## 5. Non-goals

- Designing or silently changing application or infrastructure behaviour through documentation.
- A dedicated family file-cloud platform at this stage.
- Guaranteed production availability, security, recovery, or compliance outcomes.
- Confluence or Forgejo Wiki content as the authoritative documentation store.
- Ownership, staffing, budget, approval, or completion claims not present in repository evidence.
- Arbitrary access to real secrets, private keys, recovery material, or production hostnames.

## 6. Guiding principles

Not recorded in source documents.

## 7. Constraints

- Docker Compose 2.20+ `include` support and the current service names are preserved.
- Existing ports, networks, volumes, environment variables, images, and routes are not changed for documentation convenience.
- Remote deployment uses SSH, Forgejo repository secrets, and passwordless sudo on target hosts.
- Sensitive files may be git-crypt protected; documentation must never reproduce their values.
- Australian English and standard Markdown are used where natural.

## 8. Success measures

- Every required documentation record exists with unique metadata and resolving links.
- Architecture claims identify repository evidence or are marked Inferred, Proposed, or TBD.
- No real secret or recovery value appears in documentation.
- Test execution, phase completion, and release approval are not claimed without evidence.
- Backup restoration, recovery objectives, alert ownership, and runtime health remain explicitly unverified until tested.
- Documentation changes accompany relevant implementation changes.

## 9. Time horizon

Not recorded in source documents.

## 10. Related artifacts

- Product requirements: `requirements.md`
