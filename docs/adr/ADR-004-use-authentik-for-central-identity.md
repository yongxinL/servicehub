---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-004
title: Use Authentik for Central Identity
version: "1.1"
status: Accepted
decision_basis: Inferred from current implementation
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - architecture
  - identity
  - authentik
related_documents:
  - ARCHITECTURE
  - ADR-002
  - PHASE-002
---

# ADR-004: Use Authentik for Central Identity

## Context

ServiceHub includes multiple applications with different authentication mechanisms. Authentik runs as an identity provider with PostgreSQL state, a worker, forward-auth support, and a documented LDAP outpost for Stalwart.

## Decision

Use Authentik as the central identity provider for ServiceHub, while recognising that application integration coverage is partial and varies by service.

## Decision Drivers

- Single identity administration and potential MFA policy point.
- Traefik forward-auth support.
- LDAP support for mail authentication.
- Self-hosted control.
- Repository evidence for a dedicated identity Compose domain.

## Options Considered

1. Authentik.
2. Per-application local accounts only.
3. External identity provider.
4. Reverse-proxy basic authentication for all services.

## Rationale

Authentik has a dedicated server, worker, initialiser, persistent media and templates, and PostgreSQL storage. Grafana is configured with forward auth, and the email documentation defines an Authentik LDAP directory. Local accounts remain necessary for some applications and break-glass access.

## Positive Consequences

- A common identity administration point.
- Reusable forward-auth middleware.
- LDAP option for mail.
- Potential central MFA and policy enforcement.

## Negative Consequences

- Authentik becomes a dependency for protected applications.
- Worker uses Docker socket access to manage outposts.
- Integration configuration is partly runtime state not captured in Compose.
- Local and delegated accounts may coexist.

## Risks

- Incomplete application coverage creates inconsistent sign-in experiences.
- Forward-auth redirect loops or header issues can block access.
- LDAP outpost availability affects mail authentication.
- Initial setup, recovery, and break-glass paths require validation.

## Implementation Evidence

- [compose/authn.yml](../../compose/authn.yml)
- [Authentik README](../products/authentik.md)
- [forward-auth middleware](../../shared/traefik/advanced/middlewares-authentik.yml)
- [Grafana route](../../compose/obsvc.yml)
- [Stalwart directory documentation](../products/stalwart.md)

## Related Documents

- [Architecture](../architecture/ARCHITECTURE.md)
- [Troubleshooting](../operations/TROUBLESHOOTING.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)

## Follow-up Actions

- Record actual application integration coverage from runtime configuration.
- Validate forward auth and LDAP flows.
- Define break-glass accounts and recovery procedures.

