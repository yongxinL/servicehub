---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-011
title: Adopt 9Router as the ServiceHub AI Gateway
version: "1.0"
status: Accepted
decision_basis: Owner selection of 9Router for unified AI client routing with OpenCode Free and NVIDIA provider support, conditional on implementation validation
lifecycle_stage: Design
owner: project-owner
maintainer: project-owner
created: 2026-11-02
updated: 2026-11-02
approved_by: project-owner
approval_mode: owner-self-approval
approved_on: 2026-11-02
tags:
  - servicehub
  - architecture
  - ai
  - gateway
  - routing
  - providers
  - 9router
  - nvidia
  - opencode
related_documents:
  - ADR-002
  - ADR-005
  - ADR-008
  - ADR-009
---

# ADR-011: Adopt 9Router as the ServiceHub AI Gateway

<!-- Allowed status: Draft, Proposed, In Review, Accepted, Rejected, Superseded, Deprecated, Archived -->

## Context

ServiceHub clients including Claude Code, OpenAI Codex CLI, and OpenCode each require independent endpoint, credential, provider, and model configuration.

Problems to be addressed:

- repeated endpoint, credential, provider, and model configuration across clients;
- requirement for OpenCode Free routing capability;
- use of NVIDIA AI/NIM free-tier models with a planning constraint of 40 requests per minute;
- provider outages and changing free-model availability;
- need for consistent free-provider fallback policy;
- prevention of accidental paid-provider use;
- protection of prompts, source code, logs, infrastructure data, and secrets;
- need for a stable ServiceHub endpoint and observable, reversible operation.

Critical context:

- Free providers can change availability, quotas, models, authentication, and terms without notice.
- 9Router cannot guarantee upstream free capacity.
- This ADR does not authorise sending confidential, employer, customer, regulated, or production-sensitive data to unapproved AI providers.
- The NVIDIA 40 RPM constraint is a planning limit, not a guarantee of proactive enforcement by 9Router itself.

## Decision

ServiceHub SHALL adopt 9Router as the unified AI gateway for Claude Code, OpenAI Codex CLI, and OpenCode, subject to implementation validation of all gates listed in the Validation section.

The decision requires:

- upstream project `decolua/9router`;
- HTTPS exposure through existing Traefik at `cerberus.<servicehub-domain>`;
- hostname derivation from the existing ServiceHub base-domain variable (`${DOMAIN_NAME}`);
- existing ServiceHub TLS and certificate-management conventions;
- no direct public publication of the native application port;
- use of an internal Docker network;
- authenticated API access for coding clients;
- dashboard protection using the existing `TRUSTED_IP` allowlist where technically compatible;
- no separate trusted-IP list unless a documented technical requirement exists;
- secret values outside tracked Git content;
- a reviewed, pinned release and image rather than `latest` or an unpinned branch build;
- one 9Router application container initially unless verified implementation requirements justify another service;
- SQLite/application state persisted according to verified upstream paths;
- Claude Code, Codex CLI, and OpenCode compatibility testing;
- OpenCode Free provider validation during implementation;
- NVIDIA AI/NIM as an approved provider;
- approved free-provider-only fallback;
- fail-closed behaviour when no approved free route remains;
- paid and subscription-backed fallback disabled by default;
- no browser-cookie capture, MITM interception, or employer-managed subscription reuse in the initial scope;
- no intentional prompt, response, source-code, authorisation-header, API-key, OAuth-token, cookie, or provider-session logging;
- experimental and non-critical classification until runtime evidence supports promotion;
- backup, restore, monitoring, upgrade, rollback, and credential-rotation documentation before operational acceptance.

## Deployment Scope

9Router SHALL be deployed on the OCI-hosted ServiceHub platform (in the `route` compose domain alongside Traefik) as a gateway service reachable at `cerberus.<servicehub-domain>`.

The local `aiserv` platform (ADR-009) remains the host for local inference workloads (llama.cpp, Hermes, Open WebUI). 9Router does not run on the local `aiserv` platform. This is consistent with ADR-009, which reserves the OCI deployment for platform services including ingress, identity, DevOps, and business applications, while AI workloads run locally. 9Router is an ingress-layer gateway, not an AI workload.

OCI placement does not imply anonymous public access. Traefik SHALL enforce the approved access policy before forwarding traffic to 9Router.

Final service name, storage path, network, and backup tier SHALL follow ADR-008 conventions during implementation (e.g., service prefix `route`, storage under `${APPS_DATA}/route/`, backup Tier 2, experimental classification).

## NVIDIA 40 RPM Constraint

The owner's present planning constraint is 40 requests per minute.

This is an account/provider operating constraint that must be verified during implementation. NVIDIA may apply model-level, account-level, concurrency, worker-capacity, or other limits beyond the headline RPM figure.

9Router SHALL NOT be assumed to enforce the 40 RPM limit proactively. Reactive 429 (HTTP Too Many Requests) fallback is not equivalent to proactive throttling. A conservative local target below the nominal maximum is required if proactive limiting is implemented.

Concurrency SHALL be bounded separately from RPM. Retry loops SHALL be bounded and use backoff. `Retry-After` or reset metadata SHOULD be honoured where reliably available. Repeated requests SHALL NOT create a 429 storm.

NVIDIA models sharing one account quota SHALL NOT be treated as independent fallback capacity without evidence. Multiple API keys SHALL NOT be assumed to multiply quota. Fallback SHALL select only explicitly approved free routes. When no eligible approved free route remains, the request SHALL fail clearly and SHALL NOT fall back to a paid or subscription-backed provider.

### Initial Experimental Operating Profile

The following recommendations are for implementation tuning. They are NOT native 9Router settings, NOT provider guarantees, and MUST be validated against observed behaviour:

- Initial local NVIDIA target: 36 requests per minute
- Initial burst capacity: 1
- Initial maximum long coding-agent sessions: 1

## NVIDIA Rate-Control Decision Boundary

The implementation SHALL follow this decision tree, in preferred order:

1. Use a verified built-in 9Router per-provider/per-model proactive limiter if the pinned release supports it.
2. If not available, determine whether 9Router's NVIDIA or custom OpenAI-compatible provider can target an internal rate-limiting proxy.
3. If technically supported, use a narrowly scoped internal rate-limiting proxy for NVIDIA only.
4. If neither path is supported, limit coding-agent concurrency, configure approved free fallback, monitor 429 behaviour, and document that ServiceHub cannot guarantee pre-emptive 40 RPM enforcement.
5. Do not patch or fork 9Router unless the owner separately approves the maintenance burden.

The ADR does not select a proxy product or mandate an extra container before compatibility is verified.

## Scope

### In scope for later implementation

- one 9Router gateway container;
- persisted verified 9Router state;
- Traefik route at `cerberus.<servicehub-domain>`;
- TLS using existing ServiceHub conventions;
- dashboard access controls;
- authenticated client API access;
- Claude Code integration;
- Codex CLI integration;
- OpenCode integration;
- OpenCode Free provider validation;
- NVIDIA provider integration;
- proactive or compensating NVIDIA rate-control design;
- approved free-provider fallback;
- health, logging, and operational visibility;
- backup and restore;
- upgrade and rollback;
- security and runtime compatibility validation.

### Out of scope initially

- public anonymous proxy access;
- public user registration;
- paid-provider fallback;
- automatic spending;
- browser-cookie import;
- MITM interception;
- personal or employer subscription-session sharing;
- multi-tenant public service;
- prompt/response retention for analytics;
- Headroom or another token-saver sidecar unless separately approved;
- a custom 9Router fork;
- unrelated speech, image, video, search, or embedding features;
- production-critical classification;
- use with confidential or unapproved data.

## Alternatives Considered

| Option | Benefits | Drawbacks | Reason not chosen |
|---|---|---|---|
| **A. Configure each coding client directly** | Less gateway infrastructure | Duplicated endpoints, credentials, and models; no central OpenCode Free/NVIDIA routing policy; inconsistent fallback and visibility; difficult coordination of the NVIDIA rate budget | Limited policy and visibility |
| **B. Run 9Router separately on each workstation** | Lower dependency on a shared ServiceHub instance | Duplicated installation, configuration, state, upgrades, and credentials; inconsistent provider and fallback policy; no aggregate NVIDIA quota coordination | Fragmented policy and quota |
| **C. Deploy 9Router centrally in ServiceHub (OCI)** | Stable endpoint; shared provider and model policy; central fallback configuration; central operational visibility | Extra credential-bearing service; central availability and security responsibility; unresolved need to verify proactive NVIDIA throttling | Selected |
| **D. Use only native client services** | Lowest deployment effort | Failure to provide the desired OpenCode Free and NVIDIA gateway policy; separate quota and identity models; reduced control over free-only fallback | Does not meet policy requirements |
| **E. Defer implementation** | Avoids immediate operational and security risk | Leaves fragmented client configuration and NVIDIA rate handling unresolved | Policy gap remains |

## Rationale

Central 9Router deployment on the OCI platform satisfies the owner's requirements for a unified endpoint, OpenCode Free routing, and NVIDIA provider coordination while preserving the ADR-009 boundary: local inference workloads remain on the local `aiserv` platform. The gateway can be operated as an experimental service and promoted only after implementation validation confirms rate control and client compatibility.

The decision tree for rate-control implementation ensures that the decision does not mandate a specific architecture (e.g., introducing a separate rate-limit proxy) before compatibility is verified. The implementation team retains the flexibility to choose the simplest feasible path from the validated options.

## Consequences

### Positive

- one stable endpoint for coding clients;
- central OpenCode Free and NVIDIA configuration;
- controlled provider/model allowlists;
- central free-only fallback;
- simpler future provider changes;
- one application container for the baseline deployment;
- central usage and failure visibility where available.

### Negative and risks

- additional stateful, credential-bearing service;
- central availability dependency;
- SQLite backup and corruption considerations;
- free-provider instability;
- reliance on rapidly changing client and provider APIs;
- unverified proactive NVIDIA RPM enforcement;
- risk of 429 storms if retry handling is inadequate;
- risk that upstream NVIDIA exhaustion is translated incorrectly;
- possible misleading fallback when a request error is mistaken for rate limiting;
- broader attack surface when remotely exposed;
- upgrade compatibility testing burden.

### Neutral

- clients must be reconfigured;
- every release update requires testing;
- the exact NVIDIA rate-control mechanism remains an implementation decision;
- initial limits must be tuned from observed evidence;
- the ADR does not approve confidential work data for free providers.

## Security and Privacy Requirements

The implementation SHALL provide:

- HTTPS;
- API authentication;
- trusted-IP protection for administration;
- no anonymous proxy use;
- no unnecessary host-port publication;
- least-privilege container operation where supported;
- secret values outside Git;
- restrictive permissions on application state and credential files;
- no secrets in labels, command history, logs, screenshots, or reports;
- redaction of authorisation headers and credential parameters;
- request-body logging disabled by default;
- explicit provider and model allowlists;
- free-only routing by default;
- paid fallback disabled;
- bounded retries and backoff;
- credential rotation procedures;
- backup sensitivity classification;
- data-classification review before external provider use;
- security review before access is widened beyond trusted networks.

If 9Router cannot safely separate dashboard policy from client API policy at the required hostname, the implementation SHALL stop and present secure alternatives rather than weaken administration controls.

### Authentication Layers

Three distinct authentication layers apply:

1. **Traefik access control** — the `TRUSTED_IP` allowlist protects administrative endpoints (dashboard) at the ingress layer.
2. **9Router client API authentication** — if the pinned release supports JWT or API-key authentication for the `/v1` client endpoint, it SHALL be configured; this is separate from Traefik's IP-based controls. The relationship between `JWT_SECRET` and client API keys MUST be verified from upstream documentation before relying on it.
3. **Upstream provider credentials** — NVIDIA credentials, and any credentials required by other approved providers, stored in 9Router's provider configuration, never in Git. OpenCode Free does not assume an API key; its authentication requirements MUST be verified against the pinned release.

## Operational Requirements

### Health and availability

The implementation SHALL validate and provide:

- container state;
- a verified health endpoint or safe health-check method;
- startup and persistence behaviour;
- restart behaviour;
- failure visibility.

### Observability

The implementation SHALL provide visibility, where safely and reliably available, for:

- request count;
- success, error, timeout, and rate-limit outcomes;
- route/provider/model without prompt content;
- latency;
- NVIDIA 429 and exhaustion events;
- fallback events;
- malformed upstream responses;
- container CPU, memory, health, and restart count;
- no high-cardinality or secret-bearing metrics labels.

### Logging

The implementation SHALL ensure that logs do not expose:

- prompts;
- full model responses;
- source code;
- API keys;
- OAuth tokens;
- cookies;
- provider sessions;
- authorisation headers.

### Backup and restore

The implementation SHALL provide:

- identification of all persistent 9Router state;
- protected backup of SQLite and related files;
- consistency-safe backup method;
- restore procedure;
- post-restore functional test;
- credential rotation when exposure is suspected.

### Upgrade and rollback

The implementation SHALL provide:

- pinned release/image;
- release-note review;
- pre-upgrade backup;
- validation of all three coding clients;
- OpenCode Free validation;
- NVIDIA and 429 validation;
- known-good rollback image and configuration;
- migration compatibility review.

## Implementation Validation Gates

ADR acceptance authorises experimental implementation. Operational acceptance (promotion beyond experimental status) requires all 27 gates to pass.

Adoption remains conditional until later implementation demonstrates:

1. a reviewed, pinned 9Router release and image;
2. container start without unnecessary privileges;
3. persistent data survives recreation;
4. HTTPS routing at `cerberus.<servicehub-domain>`;
5. no public native application port;
6. dashboard protected by the approved policy;
7. unauthenticated and invalid API requests rejected;
8. Claude Code compatibility;
9. Codex CLI compatibility;
10. OpenCode compatibility;
11. OpenCode Free availability and usable model routing;
12. NVIDIA API-key provider connectivity;
13. measured NVIDIA behaviour near the planned limit;
14. a verified proactive or compensating 40 RPM control strategy;
15. bounded concurrency;
16. no immediate 429 retry storm;
17. correct handling of `Retry-After` or reset information where available;
18. NVIDIA exhaustion returned as a valid error, not HTTP 200 with an unusable or null completion;
19. NVIDIA HTTP 400 errors remain actionable and do not incorrectly become 429 fallback events;
20. fallback selects only approved free routes;
21. paid routes remain disabled;
22. fail-closed behaviour when free routes are unavailable;
23. no sensitive payload or credential logging;
24. usable health and operational visibility;
25. backup and restore validation;
26. documented upgrade and rollback;
27. no regression to existing ServiceHub services.

Any test not executed MUST be recorded as `NOT RUN`, never reported as passed.

## Decision Reversal Criteria

Require reassessment if:

- authenticated access cannot be secured;
- dashboard access cannot be protected;
- any required client is incompatible;
- OpenCode Free is not reliably available for the intended workflow;
- NVIDIA rate behaviour cannot be controlled or bounded acceptably;
- 9Router causes repeated 429 storms;
- NVIDIA errors are persistently mistranslated;
- free-only fail-closed routing cannot be enforced;
- sensitive payloads or credentials cannot be excluded from logs;
- SQLite state cannot be backed up and restored reliably;
- upstream licensing or provider terms become incompatible;
- maintenance activity becomes insufficient;
- operational burden exceeds the value of central routing.

## Verified Upstream Facts (9Router)

### Evidence References

**Branch-referenced evidence** (not version-pinned; must be revalidated at Gate 1):
- Upstream repository: `https://github.com/decolua/9router`
- Inspected branch: `master`
- Inspection date: 2026-11-02
- Source documents:
  - `README.md` — Docker deployment and quick start
  - `gitbook/content/en/features/combos.md` — fallback strategy
  - `gitbook/content/en/features/smart-routing.md` — reactive fallback behaviour
  - Provider setup examples — NVIDIA configuration

**Pinned implementation evidence**: not yet available. Revalidation required against the selected release tag and image digest (Gate 1).

### Release and deployment (verified)

- Docker images published to Docker Hub under `decolua/9router` with a `latest` tag; versioned-tag availability confirmed during implementation (Gate 1).
- Docker deployment documented with volume persistence (`-v "$HOME/.9router:/app/data"`, `DATA_DIR=/app/data`) and native port `20128` (source: upstream `README.md` Docker quick start). ServiceHub exposes 9Router only through Traefik; the native port is not published (Gate 5).
- SQLite is the application state backend at path configurable via `DATA_DIR` (default `~/.9router`).
- Container starts without privileged requirements in documented examples.

### API and provider routing (verified)

- OpenAI-compatible `/v1/chat/completions` endpoint documented.
- Fallback strategy is **reactive**: on HTTP 429 or transient errors (502/503/504), 9Router automatically switches to the next model in the configured chain (source: `gitbook/content/en/features/combos.md`, `gitbook/content/en/features/smart-routing.md`).
- Provider configuration supports NVIDIA (documented in provider setup examples).
- OpenCode Free provider support: **NOT independently confirmed** in upstream release notes as of inspection. This is an implementation validation gate (Gate 11).

### Rate limiting and retry (verified vs. unverified)

- HTTP 429 triggering reactive fallback: **documented**.
- Bounded retry and backoff: **mentioned in troubleshooting guidance**; exact bounds and configuration options not specified in available docs — implementation must verify (Gate 14, 16).
- `Retry-After` header support: **not explicitly stated** in available documentation; implementation must verify (Gate 17).
- Proactive per-provider/per-model RPM limiter: **not documented** in the reviewed release. This is an implementation validation gate (Gate 14).

### Authentication and access control (verified vs. unverified)

- `JWT_SECRET` environment variable documented for dashboard/API authentication.
- Whether `JWT_SECRET` governs client API-key authentication, dashboard session auth, or both: **not explicitly distinguished** in available docs; implementation must verify.
- Dashboard access and API authentication separation: **to be validated** during implementation (Gate 6).
- Trusted-IP or equivalent access control at the 9Router application level: **not documented**; Traefik-layer `TRUSTED_IP` is the assumed control (Gate 6).

### Unverified capabilities (implementation gates)

- Whether proactive per-provider/per-model rate-limit configuration exists.
- Whether NVIDIA's upstream base URL can be redirected to an internal rate-limiting proxy.
- Whether custom rate-limiting middleware integrates with 9Router's routing.
- Full NVIDIA 429 behaviour and cardinality of error conditions.
- Specific OpenCode Free availability and routing path.
- Logging sanitization for requests, responses, and sensitive headers.

## Related Documents

- [ADR-002 Use Traefik as the Single HTTP Ingress](ADR-002-use-traefik-as-ingress.md) — ingress exposure and middleware behaviour.
- [ADR-005 Use LiteLLM for AI Workload Routing](ADR-005-use-litellm-for-ai-routing.md) — existing LiteLLM routing; **ADR-011 supersedes the gateway-selection portion of ADR-005**. ADR-005 remains authoritative for local `aiserv` workload routing. All other ADR-005 decisions remain binding.
- [ADR-008 Standardise Service Naming, Storage Layout, Bind Mounts, and Environment Variables](ADR-008-standardise-service-naming-storage-and-bind-mounts.md) — service naming, storage, and network conventions applied to 9Router during implementation.
- [ADR-009 Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) — OCI scope for 9Router gateway; local `aiserv` scope unaffected.

## Non-Goals

This ADR does not:

- authorise confidential, employer-owned, or regulated data transmission to free providers;
- guarantee NVIDIA's 40 RPM limit will not be exceeded (implementation must verify control mechanism);
- exclude alternative AI gateways from future evaluation (only 9Router is selected for this decision);
- reduce the need for comprehensive security review before production deployment;
- commit to specific implementation details (rate-limit proxy, middleware, architecture) before validation;
- replace per-client authentication or rate limits with centralised enforcement alone;
- require use of all 9Router features; only documented, verified capabilities are in scope.

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---:|---|
| Create Forgejo issue to track 9Router implementation | Project owner | TBD | Proposed |
| Draft container and Traefik integration (ADR-008 conventions) | Implementation owner | TBD | Proposed |
| Provision credentials for OpenCode Free, NVIDIA, and 9Router | Project owner | TBD | Proposed |
| Implement rate-control proof of concept (decision boundary) | Implementation owner | TBD | Proposed |
| Validate Claude Code, Codex CLI, and OpenCode compatibility | Implementation owner | TBD | Proposed |
| Measure and tune NVIDIA RPM behaviour | Implementation owner | TBD | Proposed |
| Create and test backup/restore procedures | Implementation owner | TBD | Proposed |
| Document health, observability, and operational procedures | Implementation owner | TBD | Proposed |
| Perform security test and compile test report | Implementation owner | TBD | Proposed |
| Obtain owner approval for experimental deployment | Project owner | TBD | Proposed |
| Review promotion beyond experimental status after operational acceptance gates pass | Implementation owner | TBD | Proposed |

---

**ADR Acceptance vs. Operational Acceptance:**
- **ADR acceptance** (owner approval of this Proposed ADR) authorises an experimental implementation.
- **Operational acceptance** (promotion beyond experimental status) requires all 27 Implementation Validation Gates to pass, with results recorded in a final implementation report. Any gate marked `NOT RUN` requires owner review and decision before operational acceptance.
