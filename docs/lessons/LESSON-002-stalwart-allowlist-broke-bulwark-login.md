---
project: ServiceHub
project_code: SVCHUB
document_type: LESSON
document_id: LESSON-002
title: Stalwart Host Allowlist Can Block Bulwark Login
version: "1.1"
status: Draft
lifecycle_stage: Continuous Improvement
owner: George Li
maintainer: George Li
created: 2026-10-02
updated: 2026-10-02
tags:
  - servicehub
  - lessons
  - traefik
  - stalwart
  - bulwark
related_documents:
  - ARCHITECTURE
  - TEST-001
---

# LESSON-002: Stalwart Host Allowlist Can Block Bulwark Login

## Context

On 2026-10-02, a static repository review examined the reported symptom that Bulwark could not complete login when internet access to `mail.$domain_name` was denied. The services were not running locally, so this record does not claim a runtime reproduction or successful fix.

Evidence came from [`compose/poste.yml`](../../compose/poste.yml), [`compose/route.yml`](../../compose/route.yml), [`env.example`](../../env.example), [`../products/bulwark.md`](../products/bulwark.md), and [`../products/stalwart.md`](../products/stalwart.md). Current Stalwart, Bulwark, and Traefik documentation was also checked for endpoint and routing behaviour.

## What Went Well

- The webmail and mail-server services are separated by hostname and service labels.
- Stalwart's JMAP endpoints are documented as `/.well-known/jmap` and `/jmap`.
- The configuration keeps the Traefik dashboard and forwarded-header trust policy separate from application routes.
- The repository records the Bulwark login prerequisites, including CORS and certificate requirements.

These are repository and documentation observations, not runtime test results.

## Challenges

- The original `posteservice` router applied `posteservice-whitelist` to the entire `Host(${EMAIL_HOST})` rule, not only to the Stalwart admin surface.
- `TRUSTED_IP` contains private ranges only, so an internet request is denied before it reaches Stalwart.
- Bulwark is configured with `JMAP_SERVER_URL=https://${EMAIL_HOST}`, and the repository documents browser cross-origin JMAP requests. A public webmail login can therefore fail while the webmail route itself remains reachable.
- The comment in `compose/poste.yml` described the restriction as applying to the admin UI/JMAP endpoint, but the router label applied it to every path.
- The repository does not contain runtime evidence proving which Bulwark request mode is active in the deployed environment.

## Lessons

- Host-level IP allowlists must be scoped to the protected path when another service depends on a different path on the same hostname.
- Keep the Stalwart admin UI/API restricted, but expose only the JMAP paths required by webmail: `/.well-known/jmap` and `/jmap`.
- Do not weaken `TRUSTED_IP` to `0.0.0.0/0`; that would undermine both the allowlist and forwarded-header trust policy.
- A reachable application route does not prove that its downstream API route is reachable through the same reverse proxy.
- For this stack, browser cross-origin JMAP requests also require Stalwart's permissive CORS setting and a trusted certificate on the Stalwart HTTPS listener.

## Improvement Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Split the Stalwart Traefik router into a public JMAP router and a restricted non-JMAP router | Requires owner review | TBD | Proposed |
| Keep `JMAP_SERVER_URL=https://${EMAIL_HOST}` and verify `STALWART_PUBLIC_URL` remains the public HTTPS URL | Requires owner review | TBD | Proposed |
| Enable Stalwart permissive CORS for the webmail origin and confirm the exported certificate is installed | Requires owner review | TBD | Proposed |
| Update the Stalwart and Bulwark routing documentation to describe the path-scoped allowlist | Requires owner review | TBD | Proposed |
| Validate from an untrusted network that JMAP discovery is not denied while `/admin` remains denied | Requires owner review | TBD | Proposed |

## Recommended Configuration

Replace the single Stalwart Host router with path-scoped routers in `compose/poste.yml`:

```yaml
# Public JMAP endpoints
- "traefik.http.routers.posteservice-jmap.rule=Host(`${EMAIL_HOST}`) && (PathPrefix(`/jmap`) || PathPrefix(`/.well-known/jmap`))"
- "traefik.http.routers.posteservice-jmap.middlewares=secure-chain@file"
- "traefik.http.routers.posteservice-jmap.priority=20"

# All other Stalwart paths, including the admin UI/API, remain restricted
- "traefik.http.routers.posteservice-admin.rule=Host(`${EMAIL_HOST}`) && !(PathPrefix(`/jmap`) || PathPrefix(`/.well-known/jmap`))"
- "traefik.http.routers.posteservice-admin.middlewares=secure-chain@file,posteservice-whitelist"
```

Both routers must retain the existing entrypoint, service, TLS, and certificate-resolver labels. The Bulwark router should remain public with `secure-chain` only.

## Validation Required

Run these checks on the deployed target from an untrusted network after applying the change:

- `/.well-known/jmap` must not return an IP-allowlist denial.
- `/jmap` must reach Stalwart and return an application-level authentication response rather than Traefik's allowlist denial.
- `/admin` must remain denied for an untrusted source.
- Bulwark login must complete without a Traefik `403`, CORS error, or certificate error.

No runtime validation was performed as part of this lesson.

## Owners

Documentation owner and maintainer: George Li.

Operational, security, and validation owner: `Requires owner review`.

## Due Dates

All due dates are `TBD` because the repository does not provide a schedule.

## Related Documents

- [Platform baseline validation](../testing/TEST-001-platform-baseline-validation.md)
- [Architecture](../architecture/ARCHITECTURE.md)
- [Bulwark service documentation](../products/bulwark.md)
- [Stalwart service documentation](../products/stalwart.md)
- [Traefik service documentation](../products/traefik.md)
