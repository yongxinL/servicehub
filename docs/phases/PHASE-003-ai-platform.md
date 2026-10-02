---
project: ServiceHub
project_code: SVCHUB
document_type: PHASE
document_id: PHASE-003
title: AI Platform
version: "1.0"
status: Draft
lifecycle_stage: Planning
owner: George Li
maintainer: George Li
created: 2026-10-01
updated: 2026-10-01
tags:
  - servicehub
  - phase
  - ai
  - litellm
related_documents:
  - PRD-001
  - ADR-005
  - DATA-FLOW
  - TEST-001
---

# PHASE-003: AI Platform

## Objective

Provide local and cloud AI routing through LiteLLM with privacy-sensitive local handling, client access, health-based fallback, and measurable routing decisions.

## Scope

- Hermes agent and workspace.
- LiteLLM proxy, configuration, smart router, database, and metrics.
- Local llama.cpp inference.
- Open WebUI client.
- Optional FastCRW, SearXNG, LightPanda, and Chromium components outside the default stack.

## Deliverables

- [AI Compose domain](../../compose/aiagn.yml)
- [Open WebUI service](../../compose/wbapp.yml)
- [LiteLLM configuration](../../shared/litellm/config.default.yaml)
- [Smart router](../../shared/litellm/smartrouter.py)
- [Hermes image and profile configuration](../../shared/hermesagent/)
- [llama.cpp service](../../shared/llamacpp/)

## Requirements Addressed

- FR-007
- SEC-008
- NFR-006
- OBS-001, OBS-004
- MR-002

## Dependencies

- PostgreSQL for LiteLLM usage data.
- Model availability and sufficient local resources.
- Cloud provider credentials and network access.
- Optional renderer and search services for full Hermes web tooling.
- Client configuration and authentication.

## Tasks

- [x] Local and cloud model targets are configured.
- [x] Privacy, size, complexity, health, and fallback rules exist.
- [x] Health checks exist for Hermes, LiteLLM, and llama.cpp.
- [x] LiteLLM metrics configuration exists.
- [ ] Validate local model download or cache load.
- [ ] Validate local inference response and health.
- [ ] Validate cloud routing without exposing credentials.
- [ ] Validate privacy requests remain local and do not fall back.
- [ ] Validate explicit local/cloud tags.
- [ ] Validate unhealthy-local and context-window routes.
- [ ] Validate Open WebUI and Hermes client authentication.
- [ ] Record phase acceptance evidence.

## Risks

- Resource exhaustion or slow local startup.
- Heuristic routing misclassification.
- Cloud fallback may externalise privacy-sensitive content.
- Published API ports may be reachable beyond intended clients.
- Optional web-search components are not in the default stack.

## Acceptance Criteria

- Local health and an inference request succeed.
- Cloud route succeeds when configured, without recording credentials.
- Privacy requests use local routing and fallback behaviour matches policy.
- Large, complex, unhealthy-local, and context-window cases route as configured.
- Hermes and Open WebUI can authenticate and reach the intended target.
- LiteLLM metrics appear in VictoriaMetrics.
- Test evidence is linked.

## Evidence Required

- Health responses with secret headers redacted.
- Routing logs for each test class.
- Resource and startup timing.
- Client test results.
- Metrics query results.

## Completion Summary

**Retrospective validation required.** AI configuration is present, but routing, privacy, availability, and phase completion remain unverified.

## Follow-up Work

- Execute AI portions of [TEST-001](../testing/TEST-001-platform-baseline-validation.md).
- Review direct port protections.
- Add privacy-routing regression tests.

