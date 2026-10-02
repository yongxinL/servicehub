---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-002
title: Use Traefik as the Single HTTP Ingress
version: "1.0"
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
  - traefik
  - ingress
related_documents:
  - ARCHITECTURE
  - SYSTEM-CONTEXT
  - ADR-004
---

# ADR-002: Use Traefik as the Single HTTP Ingress

## Context

ServiceHub exposes multiple web applications through environment-defined hostnames. Routing must support HTTP redirect, TLS, Docker discovery, security middleware, and identity forward auth.

## Decision

Use one Traefik service as the designed HTTP and HTTPS ingress for routed web services.

## Decision Drivers

- Central TLS and redirect policy.
- Docker-label route discovery.
- Shared security headers and rate limits.
- Forward-auth middleware support.
- Metrics and structured access logging.

## Options Considered

1. Traefik with Docker provider.
2. Nginx or Caddy with generated configuration.
3. Per-application TLS termination.
4. Direct port publication for every application.

## Rationale

The repository declares `exposedbydefault=false`, labels each intended route, publishes only 80 and 443 on Traefik, and centralises TLS, middleware, metrics, and access logs in one service.

## Positive Consequences

- Consistent hostname routing.
- One HTTP-to-HTTPS redirect.
- Reusable `secure-chain`, forward-auth, IP allowlist, and compression middleware.
- Central access logs and Traefik metrics.

## Negative Consequences

- Traefik requires Docker socket access and runs privileged in Compose.
- Route configuration depends on container labels.
- Traefik becomes a critical ingress dependency.
- Dynamic label changes can alter routing without a separate configuration deployment.

## Risks

- A Traefik outage affects routed services.
- Incorrect labels or middleware can remove access controls.
- Trusted proxy and allowlist values may be misconfigured.
- Certificate issuance depends on external DNS and CA state.

## Implementation Evidence

- [compose/route.yml](../../compose/route.yml)
- [Traefik README](../../shared/traefik/README.md)
- [security middleware](../../shared/traefik/advanced/middlewares-security.yml)
- [forward-auth middleware](../../shared/traefik/advanced/middlewares-authentik.yml)
- Service router labels across `compose/*.yml`

## Related Documents

- [System context](../architecture/SYSTEM-CONTEXT.md)
- [Data flow](../architecture/DATA-FLOW.md)
- [ADR-004](ADR-004-use-authentik-for-central-identity.md)

## Follow-up Actions

- Validate HTTP redirect, TLS, host routes, rate limits, and headers.
- Review trusted proxy and allowlist values.
- Review Docker socket and privileged-mode exposure.

