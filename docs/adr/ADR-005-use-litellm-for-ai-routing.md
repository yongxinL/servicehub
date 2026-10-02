---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-005
title: Use LiteLLM for AI Workload Routing
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
  - ai
  - litellm
related_documents:
  - ARCHITECTURE
  - DATA-FLOW
  - PHASE-003
---

# ADR-005: Use LiteLLM for AI Workload Routing

## Context

Hermes and other AI clients need one API target while ServiceHub provides a local llama.cpp inference service and a configured cloud provider. Routing must consider privacy, input size, complexity, local health, and provider failures.

## Decision

Use LiteLLM as the AI workload router, with `hephaestus` for local inference and `prometheus` for the configured cloud target.

## Decision Drivers

- One API endpoint for clients.
- Configurable local and cloud providers.
- Content-based routing hook.
- Context-window and provider-failure fallback configuration.
- PostgreSQL usage database and Prometheus metrics.

## Options Considered

1. LiteLLM with local and cloud targets.
2. Direct client connections to each provider.
3. Local inference only.
4. A custom reverse proxy.

## Rationale

The repository includes LiteLLM configuration, a smart routing hook, health-based edge checks, privacy keywords, complexity and size thresholds, local and cloud model definitions, fallback settings, and metrics collection.

## Positive Consequences

- Stable client API.
- Central visibility into routing decisions and metrics.
- Local default path for private workloads.
- Explicit fallback and context-window handling.

## Negative Consequences

- LiteLLM is a critical AI dependency.
- Routing policy may misclassify intent.
- Cloud fallback can send data externally unless fallback is disabled.
- Runtime provider and token availability are external dependencies.

## Risks

- Keyword rules are heuristic and require tests.
- Local model resource use may cause unhealthy states.
- Fallbacks can defeat a user's privacy expectation if not controlled.
- Published LiteLLM port and API-key protection require review.

## Implementation Evidence

- [compose/aiagn.yml](../../compose/aiagn.yml)
- [LiteLLM README](../../shared/litellm/README.md)
- [default configuration](../../shared/litellm/config.default.yaml)
- [smart router](../../shared/litellm/smartrouter.py)
- [llama.cpp service](../../compose/aiagn.yml)

## Related Documents

- [Data flow](../architecture/DATA-FLOW.md)
- [AI platform phase](../phases/PHASE-003-ai-platform.md)
- [Baseline test plan](../testing/TEST-001-platform-baseline-validation.md)

## Follow-up Actions

- Execute privacy, local, cloud, unhealthy-local, and context-window routing tests.
- Review published port protection.
- Record actual cloud-provider availability without exposing credentials.

