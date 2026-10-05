---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-010
title: Collect OCI Logs and Integrate Service Telemetry with Oracle APM
version: "1.0"
status: Proposed
decision_basis: Split from ADR-009 on 2026-10-05 after a review found that ADR-009 required Oracle APM, Monitoring, Logging, and Tracing but no collector, credential, or configuration for them exists in the repository; the collection and integration design is recorded here for owner approval before implementation
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-05
updated: 2026-10-05
tags:
  - servicehub
  - architecture
  - oci
  - observability
  - logging
  - apm
related_documents:
  - ADR-009
  - ARCHITECTURE
  - DEPLOYMENT-ARCHITECTURE
  - MONITORING-ALERTING
---

# ADR-010: Collect OCI Logs and Integrate Service Telemetry with Oracle APM

<!-- Allowed status: Draft, Proposed, In Review, Accepted, Rejected, Superseded, Deprecated, Archived -->

## Context

[ADR-009](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) removed `compose/obsvce.yml` (VictoriaMetrics, VictoriaLogs, Alloy, Grafana) from the OCI deployment and required Oracle Cloud native observability to replace it. ADR-009 deliberately did not design the replacement; that work is recorded here.

Evidence of the current gap, verified on 2026-10-05:

- [env.example](../../env.example) defines no Oracle APM, OCI logging, or OCI credential variables.
- [docker-compose.yml](../../docker-compose.yml) includes only `route`, `infra`, `devops`, `webapp`, and `mailsv`; no telemetry collector service exists.
- No service in `compose/*.yml` exports traces, and no OCI agent configuration is recorded anywhere in the repository.
- [Monitoring and alerting](../operations/MONITORING-ALERTING.md) previously asserted that OCI APM, Monitoring, Logging, and Tracing are in use; they are not configured.

Two different credential models are involved, which is the main source of confusion:

| Signal | Destination | Credential |
|---|---|---|
| Traces and application metrics | Oracle APM | Data upload endpoint + **private data key** (bearer `dataKey` header) |
| Browser real-user monitoring | Oracle APM | Data upload endpoint + **public data key** |
| Container and application logs | OCI Logging / Logging Analytics | OCI IAM (instance principal or API signing key) — **no data key** |
| Host metrics | OCI Monitoring | OCI IAM, collected by the Oracle Cloud Agent |

## Decision

Oracle telemetry SHALL be collected with the host-level Oracle Cloud Agent on the OCI instance, and application telemetry SHALL be exported to Oracle APM with OpenTelemetry where a service supports it, as follows.

### 1. Credentials in `.env`

`env.example` SHALL gain three empty variables under the [ADR-008](ADR-008-standardise-service-naming-storage-and-bind-mounts.md) prefix convention:

```text
APM_DATA_UPLOAD_ENDPOINT=""   # APM domain details page, region specific
APM_PRIVATE_DATA_KEY=""       # APM domain → Data Keys → private
APM_PUBLIC_DATA_KEY=""        # only if browser RUM is enabled later
```

Defaults SHALL be empty strings, not `<PLACEHOLDER>` tokens: `scripts/setup.sh` replaces placeholder tokens with generated secrets, which would corrupt values that cannot be generated locally.

Log collection SHALL NOT consume these variables. It authenticates as an OCI instance principal (dynamic group) and needs no key material in the repository.

### 2. Log collection

Container logs SHALL be collected by the Oracle Cloud Agent **Logging** plugin using an OCI Logging agent configuration on the OCI instance:

- Input: Docker JSON logs under `/var/lib/docker/containers/*/*-json.log`, parsed as JSON.
- Destination: an OCI Logging log group and custom log created for ServiceHub.
- Scope: all containers in the deployed OCI scope (`route`, `infra`, `devops`, `webapp`, `mailsv`).

The agent configuration, log group, and IAM policy SHALL be recorded in [Monitoring and alerting](../operations/MONITORING-ALERTING.md) when implemented. If search, parsing, or dashboards over logs are later required, a Service Connector SHALL route the OCI Logging log group to OCI Logging Analytics; this is not part of the initial implementation.

### 3. Host metrics

Host CPU, memory, disk, and network metrics SHALL be published by the Oracle Cloud Agent **Monitoring** plugin to OCI Monitoring. No repository change is required; enabling and verifying the plugin is an implementation step.

### 4. APM integration

Traces and application metrics SHALL be exported over OTLP to the APM domain:

```text
Traces   https://<data-upload-endpoint>/20200101/opentelemetry/private/v1/traces
Metrics  https://<data-upload-endpoint>/20200101/opentelemetry/v1/metrics
Header   Authorization: dataKey <APM_PRIVATE_DATA_KEY>
```

Integration is opt-in per service, in this order:

| Priority | Service | Method |
|---|---|---|
| 1 | LiteLLM | `OTEL_*` environment variables pointing at the endpoints above |
| 2 | Confluence | Oracle APM Java agent (`-javaagent`), which also enables browser-agent injection if RUM is adopted |
| 3 | Others | Reassess only if a service gains practical OpenTelemetry support |

Traefik, Authentik, Forgejo, Stalwart, and oCIS SHALL rely on the log collection in decision 2: attaching a vendor agent to those third-party images is not supported in practice, and access plus container logs give the request-level visibility they need.

### 5. Browser real-user monitoring

RUM is deferred. It requires the public data key to be exposed to browsers through a Traefik middleware and SHALL be reconsidered only after decisions 1 to 4 are running.

### 6. Egress

Collection runs on the OCI host, not inside a stack container, so it needs outbound TCP 443 to `*.oraclecloud.com` permitted by the host's security list or firewall; without it, collection silently fails. The [ADR-009](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) Confluence egress rule does not apply here and SHALL NOT be relaxed for it — Confluence itself gains no APM egress.

### 7. Fallback option

If the host agent cannot meet parsing or labelling requirements, a single containerised collector (Fluent Bit with the `oracle_log_analytics` output, plus an OTel collector exporting to APM) MAY be introduced as a new compose include. That would extend the ADR-009 OCI service scope beyond `route`, `infra`, `devops`, `webapp`, and `mailsv`, so it requires an ADR-009 scope amendment and is explicitly excluded from this decision.

### 8. Out of scope

Observability for locally hosted `aiserv` services remains a separate ADR-009 follow-up: the local platform has no Oracle Cloud Agent, so it needs its own approach.

## Decision Drivers

- ADR-009 removed the self-hosted stack without a replacement, leaving the OCI deployment with no log or metric collection.
- Logs and APM traces use different credential models; conflating them produces a design that cannot work.
- The OCI deployment scope in ADR-009 is fixed to five domains, so adding a collector container has governance cost beyond its runtime cost.
- The repository convention is that configuration lives in `env.example` and Compose, not only in a cloud console.
- Ingested spans and log volume are billed by OCI, so the design must start narrow.

## Non-Goals

This ADR does not prescribe:

- Dashboard, alarm, or alert-routing design.
- Log retention, sampling, or cost-control values.
- Restoring the self-hosted Grafana/VictoriaMetrics/VictoriaLogs stack.
- The local `aiserv` observability strategy.

## Options Considered

1. Host-level Oracle Cloud Agent for logs and host metrics, plus per-service OTLP export to APM (selected).
2. A containerised collector in Compose (Fluent Bit + OTel collector) for logs and traces.
3. Per-service OCI SDK log appenders writing directly to OCI Logging Analytics.

## Rationale

Option 1 needs no new container, no credential material in the repository for logs, and no change to the ADR-009 deployment scope; it also gives host metrics that the self-hosted stack used to provide. Option 2 keeps configuration in Git but requires an OCI config file or API key on the host, adds a service to a scope that ADR-009 deliberately narrowed, and duplicates what the pre-installed agent already does. Option 3 requires code changes in every service, which is impossible for the third-party images that make up most of the platform.

## Positive Consequences

- Log and host-metric collection resumes without changing the deployment scope.
- The APM credential model is written down, so the endpoint and data key are not misapplied to logs.
- Collection stays outside `.env` for logs, limiting the blast radius of a leaked repository secret.
- Existing self-hosted history is not required for the first signals to arrive.

## Negative Consequences

- The agent configuration lives in the OCI console rather than in the repository, so it is recorded as documentation and can drift from it.
- Per-service OTLP instrumentation gives uneven coverage: only LiteLLM and Confluence are practical candidates at first.
- No application traces exist for services without OpenTelemetry support, so root-cause analysis still leans on logs.

## Risks

- The OCI Logging plugin or agent configuration may not accept the Docker log glob or may not have read permission on the container log directory; mitigate by verifying collection on a deployed instance during implementation, with residual risk until that evidence is recorded.
- `APM_PRIVATE_DATA_KEY` is a bearer credential that lets anyone who reads `.env` push telemetry; mitigate by keeping `.env` at mode 600, out of Git, and out of build contexts, and by rotating the key in the APM domain if exposed.
- Ingested spans and log volume are billable; mitigate by starting with log collection only and by enabling trace export for one service at a time, with residual cost uncertainty until volume is observed.
- Collection failures are silent (data simply stops arriving); mitigate by checking for recent log entries and APM traces after every egress, agent, or credential change.
- The local `aiserv` platform remains unobserved; this is tracked as an ADR-009 follow-up rather than by this decision.

## Implementation Evidence

None as of 2026-10-05. Verified absences:

- [env.example](../../env.example) — no `APM_*` or OCI logging variables.
- [docker-compose.yml](../../docker-compose.yml) — no collector include.
- [Compose domain files](../../compose/) — no OTLP or APM configuration.
- [Monitoring and alerting](../operations/MONITORING-ALERTING.md) — status note corrected to reference this ADR instead of claiming the services are in use.

## Related Documents

- [ADR-009 Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) — retires the self-hosted stack and defers the replacement to this record.
- [Monitoring and alerting](../operations/MONITORING-ALERTING.md) — where the implemented agent configuration and credentials are recorded.
- [Deployment architecture](../architecture/DEPLOYMENT-ARCHITECTURE.md) — deployment scope this collection sits inside.

## Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---|---|
| Create the APM domain, log group, and custom log; record the data upload endpoint, data keys, and log group OCID in `env.example` and `MONITORING-ALERTING` | ServiceHub Architecture | TBD | Proposed |
| Enable the Oracle Cloud Agent Logging and Monitoring plugins and record the agent configuration for Docker JSON logs | ServiceHub Architecture | TBD | Proposed |
| Export LiteLLM traces and metrics to APM over OTLP and verify arrival in the APM domain | ServiceHub Architecture | TBD | Proposed |
| Evaluate the Oracle APM Java agent for Confluence | ServiceHub Architecture | TBD | Proposed |
| Confirm outbound TCP 443 to `*.oraclecloud.com` from the OCI host (security list or firewall) | George Li | TBD | Proposed — host level, independent of the Confluence allow list |
| Record cost and retention decisions once ingest volume is observed | George Li | TBD | Proposed |
