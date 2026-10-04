---
project: ServiceHub
project_code: SVCHUB
document_type: PHASE
document_id: PHASE-002
title: Identity and Developer Services
version: "1.0"
status: Draft
lifecycle_stage: Planning
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-04
tags:
  - servicehub
  - phase
  - identity
  - forgejo
related_documents:
  - PRD-001
  - ADR-002
  - ADR-004
  - ADR-006
  - RFC-002
  - DEPLOYMENT-ARCHITECTURE
---

# PHASE-002: Identity and Developer Services

## Objective

Provide governed identity infrastructure and repository-hosted development and deployment services with explicit integration boundaries.

## Scope

- Authentik server, worker, initialisation, PostgreSQL state, and forward-auth middleware.
- Stalwart LDAP directory integration documentation.
- Forgejo server, database, HTTPS route, and registration controls.
- Host-mode Forgejo Actions runner and deployment workflows.
- Application identity coverage for Grafana, Forgejo, Confluence, webmail, oCIS, and other services.

## Deliverables

- [Authentik Compose domain](../../compose/authn.yml)
- [Forgejo Compose domain](../../compose/depot.yml)
- [Authentik README](../../shared/authentik/README.md)
- [Forgejo README](../../shared/forgejo/README.md)
- [Forward-auth middleware](../../shared/traefik/advanced/middlewares-authentik.yml)
- [oCIS Compose service](../../compose/wbapp.yml)
- [oCIS operational guide](../../shared/owncloud/README.md)
- [.forgejo workflows](../../.forgejo/workflows/)

## Requirements Addressed

- FR-005, FR-006, FR-011, FR-014
- SEC-003, SEC-004, SEC-006
- REL-001, REL-003
- MR-003, MR-005

## Dependencies

- Healthy Traefik and PostgreSQL.
- Authentik initial setup and application configuration.
- Forgejo repository secrets and runner registration.
- SSH target secrets and known-host material.
- Public repository URL for remote checkout.

## Tasks

- [x] Authentik and Forgejo services exist in Compose.
- [x] Grafana uses forward-auth middleware.
- [x] Stalwart LDAP integration is documented.
- [x] Forgejo registration is disabled in configuration.
- [x] Runner and workflow files exist.
- [x] Repository configuration exists for `wbappmydrive` and its Authentik OIDC environment.
- [ ] Record actual Authentik application coverage.
- [ ] Configure the Authentik OIDC provider and application for oCIS.
- [ ] Validate forward-auth login and logout.
- [ ] Validate LDAP-backed mail authentication.
- [ ] Validate Forgejo login, OIDC decision, and break-glass account.
- [ ] Validate oCIS OIDC sign-in, sign-out, account provisioning, and file access.
- [ ] Validate runner registration and all workflows.
- [ ] Record phase acceptance evidence.

## Risks

- Identity integrations may be configured only at runtime.
- Local accounts may diverge from central identity policy.
- Runner secret or SSH secret compromise.
- Runner-hosted jobs have broad target access.
- Foundational services are outside automated deployment.

## Acceptance Criteria

- Authentik reaches health and initial setup is complete.
- Protected routes enforce expected authentication.
- oCIS authenticates through Authentik and provides file access only after a successful OIDC flow.
- Forgejo registration is disabled and access review is recorded.
- Runner registration and labels are validated.
- Deployment and remote-access workflows execute as designed.
- LDAP mail authentication and recovery path are tested.
- Break-glass procedures are documented and tested.

## Evidence Required

- Identity configuration export with secret values redacted.
- Login and logout test results.
- Redacted oCIS OIDC and file-operation results.
- LDAP test results.
- Forgejo and runner health evidence.
- Workflow execution logs.
- Break-glass test record.

## Completion Summary

**Retrospective validation required.** Repository implementation exists, but integration coverage and phase completion are not claimed.

## Follow-up Work

- Decide and record central versus local identity for every application.
- Test redirect loops and outage behaviour.
- Review runner permission and secret scope.
