---
project: ServiceHub
project_code: SVCHUB
document_type: ADR
document_id: ADR-010
title: Establish the ServiceHub Observability Platform with Grafana, VictoriaMetrics, VictoriaLogs, Alloy, and Oracle APM
version: "1.0"
status: Proposed
decision_basis: Supersedes the initial OCI-native-only observability proposal after review of the existing ServiceHub Grafana observability implementation, Oracle APM Always Free limitations, long-term retention requirements, security monitoring requirements, and the need for vendor-neutral telemetry collection
lifecycle_stage: Design
owner: George Li
maintainer: George Li
created: 2026-10-05
updated: 2026-10-16
tags:
  - servicehub
  - architecture
  - observability
  - grafana
  - alloy
  - victoria-metrics
  - victoria-logs
  - oracle-apm
  - security
  - monitoring
  - alerting
related_documents:
  - ADR-008
  - ADR-009
  - ARCHITECTURE
  - DEPLOYMENT-ARCHITECTURE
  - MONITORING-ALERTING
  - LOG-TROUBLESHOOTING
---

# ADR-010: Establish the ServiceHub Observability Platform with Grafana, VictoriaMetrics, VictoriaLogs, Alloy, and Oracle APM

<!-- Allowed status: Draft, Proposed, In Review, Accepted, Rejected, Superseded, Deprecated, Archived -->

## Context

ADR-009 initially removed the self-hosted ServiceHub observability stack from the OCI deployment and proposed replacing it with Oracle Cloud Infrastructure native observability services.

The removed observability stack consisted of:

- Grafana Alloy;
- VictoriaMetrics;
- VictoriaLogs; and
- Grafana.

A subsequent review found that an OCI-native-only design would not fully satisfy ServiceHub's requirements for:

- long-term metrics retention;
- long-term log retention;
- application and container troubleshooting;
- security-event investigation;
- operational dashboards;
- vendor-neutral telemetry collection;
- telemetry correlation across the host, Docker, applications, databases, and edge traffic; and
- continued observability without depending on paid OCI ingestion capacity.

The existing ServiceHub repository already contains an operational observability implementation based on Grafana Alloy, VictoriaMetrics, VictoriaLogs, and Grafana.

The current implementation collects:

- Linux host CPU, memory, pressure, disk-I/O, network, load, process, socket, and hardware metrics through `prometheus.exporter.unix`;
- Docker container CPU, memory, network, filesystem-I/O, process, and lifecycle metrics through `prometheus.exporter.cadvisor`;
- logs from all Docker containers through `loki.source.docker`;
- Traefik metrics through its Prometheus-compatible endpoint;
- Traefik structured access logs;
- GeoIP enrichment of Traefik client addresses;
- selected log-derived Prometheus metrics; and
- Grafana Alloy self-metrics.

Grafana Alloy supports Prometheus-compatible collection, OpenTelemetry pipelines, Loki-compatible log pipelines, relabelling, enrichment, and telemetry routing. It therefore provides a vendor-neutral collection layer without requiring a second OpenTelemetry Collector.

VictoriaMetrics and VictoriaLogs provide ServiceHub-controlled historical storage, while Grafana provides visualization, investigation, and alerting.

Oracle APM remains valuable for distributed tracing and selected application-performance diagnostics. However, an OCI Always Free APM domain is limited to 1,000 spans per hour, throttles excess spans, and retains trace data for 31 days. It is therefore unsuitable as the primary long-term metrics or log store for ServiceHub.

Local AI services, including LiteLLM and the `aiserv` deployment domain, are not deployed on OCI and are outside the scope of this ADR.

The ServiceHub mail platform, including Stalwart and Bulwark, is being relocated away from OCI because OCI does not provide the required direct outbound SMTP delivery path for this deployment. Mail-server and webmail telemetry are therefore outside the OCI scope governed by this ADR. Their future observability requirements SHALL be defined with the destination platform rather than duplicated here.

## Decision Drivers

The observability platform SHALL prioritize:

1. **Security**
   - detect and investigate suspicious access;
   - preserve relevant authentication and system-security events;
   - identify abnormal request or authentication patterns;
   - prevent secrets and credentials from entering retained telemetry.

2. **Stability**
   - detect host, filesystem, Docker, container, database, and application failures;
   - distinguish a running container from a functioning application;
   - detect restart loops, OOM events, storage exhaustion, failed backups, and telemetry-pipeline failures.

3. **Performance**
   - identify CPU, memory, storage, network, JVM, database, and application bottlenecks;
   - correlate user-visible latency with service, container, host, database, log, and trace information;
   - retain sufficient historical data for trend and capacity analysis.

4. **Operational simplicity**
   - extend existing components before introducing new products;
   - avoid overlapping collectors and storage systems;
   - keep alerting actionable and appropriate for a single-operator homelab.

5. **Data ownership**
   - retain long-term ServiceHub metrics and logs under ServiceHub control;
   - use managed OCI telemetry selectively where it provides differentiated value.

## Decision

ServiceHub SHALL retain and extend the self-hosted Grafana observability stack on the OCI-hosted ServiceHub platform.

The authoritative telemetry responsibilities SHALL be:

| Signal or function | Primary component |
|---|---|
| Telemetry collection, enrichment, and routing | Grafana Alloy |
| Historical infrastructure and application metrics | VictoriaMetrics |
| Historical host, container, access, application, and security logs | VictoriaLogs |
| Visualization and operational investigation | Grafana |
| Application and platform alerts | Grafana Alerting |
| Selected distributed traces and APM diagnostics | Oracle APM |
| Independent OCI-instance availability monitoring | OCI Monitoring |
| OCI-hosted VM metrics where useful independently of ServiceHub | OCI Monitoring |

Grafana Alloy SHALL be the common ServiceHub collector and telemetry-routing layer. VictoriaMetrics and VictoriaLogs SHALL remain the primary historical stores. Grafana SHALL remain the primary visualization and investigation interface.

Oracle APM SHALL supplement rather than replace the self-hosted observability platform.

## 1. Observability Architecture

The target architecture SHALL be:

```text
                         OCI external monitoring
                                  |
                                  v
                         OCI compute instance
                                  |
    +-----------------------------+-----------------------------+
    |                             |                             |
    v                             v                             v
Linux host metrics          Linux host logs               Docker runtime
    |                             |                       /             \
    |                             |                      v               v
    |                             |              Container metrics   Container logs
    |                             |                      |               |
    +-----------------------------+----------------------+---------------+
                                  |
                     Native application metrics
                     - Traefik
                     - Authentik
                     - ownCloud Infinite Scale
                     - PostgreSQL
                     - Confluence JMX, when implemented
                                  |
                     Availability and TLS probes
                                  |
                                  v
                           Grafana Alloy
                        /        |        \
                       /         |         \
                      v          v          v
             VictoriaMetrics  VictoriaLogs  Oracle APM
                 metrics          logs      selected traces
                      \            /
                       \          /
                          Grafana
                       dashboards and alerts
```

No additional general-purpose metrics collector, log collector, or OpenTelemetry Collector SHALL be introduced unless an identified requirement cannot be satisfied by Grafana Alloy.

## 2. Host Metrics

The existing Linux host collection through `prometheus.exporter.unix` SHALL be retained.

It SHALL continue to collect, where supported:

- CPU time and utilization;
- CPU pressure-stall information;
- memory usage, availability, buffers, cache, and swap;
- memory pressure-stall information;
- disk reads, writes, transferred bytes, and I/O time;
- I/O pressure-stall information;
- network traffic, packet counts, errors, and drops;
- system load;
- blocked and running processes;
- boot and system time;
- TCP, network, socket, and entropy information; and
- relevant hardware-monitoring information.

## 3. Host Filesystem Monitoring

The previous decision to disable host filesystem collection SHALL be reviewed and superseded where necessary to provide correct host-capacity monitoring.

ServiceHub SHALL collect actual host filesystem capacity and inode metrics for the filesystems backing:

- the Linux root filesystem;
- the Docker data root;
- ServiceHub persistent bind mounts;
- VictoriaMetrics;
- VictoriaLogs;
- application databases;
- Confluence data;
- Forgejo repositories and Actions data;
- ownCloud Infinite Scale data;
- backup staging locations where applicable.

The implementation SHALL collect at least:

- filesystem total size;
- available and free space;
- used percentage;
- total and available inodes;
- inode utilization;
- read-only filesystem state.

Any host filesystem mounted into Alloy for observation SHALL be mounted read-only and limited to the minimum required host paths.

Container filesystem metrics SHALL NOT be treated as a substitute for actual host filesystem capacity.

## 4. Host Logs

Grafana Alloy SHALL collect a selective set of Linux host logs and forward them to VictoriaLogs.

The initial host-log scope SHALL include:

### Security

- successful and failed SSH authentication;
- sudo activity;
- user and account changes where available;
- operating-system authentication failures;
- firewall deny or drop events where enabled.

### Stability

- kernel errors;
- OOM-killer events;
- Docker daemon errors;
- systemd service failures;
- filesystem and storage errors;
- significant network-interface errors;
- unexpected reboot and shutdown events.

Host-journal collection SHALL be filtered to avoid retaining high-volume, low-value informational messages without an operational requirement.

## 5. Docker and Container Telemetry

The existing cAdvisor collection SHALL be retained with Docker-only collection enabled.

Every ServiceHub container SHALL receive baseline telemetry for:

- CPU usage;
- CPU throttling;
- memory usage;
- memory working set;
- memory limit;
- RSS, cache, and swap;
- network receive and transmit volume;
- network packet errors and drops;
- filesystem reads and writes;
- process and task state;
- container start time;
- last-seen time;
- resource specifications and limits.

All container `stdout` and `stderr` output SHALL continue to be collected through `loki.source.docker` and forwarded to VictoriaLogs.

Docker local log rotation SHALL remain configured even when logs are shipped to VictoriaLogs, because local unbounded Docker log files can exhaust host storage.

## 6. Privileged Collector Security

Grafana Alloy SHALL be treated as a privileged infrastructure component.

Its access to:

- the Docker socket;
- Docker runtime information;
- host procfs;
- host sysfs;
- selected host filesystem paths; and
- host journals

creates a high-impact security boundary.

The implementation SHALL therefore ensure:

- the Docker socket is never externally exposed;
- Alloy administrative and metrics interfaces are internal only;
- host mounts are read-only wherever possible;
- Alloy images are version-controlled or pinned according to ServiceHub dependency policy;
- unnecessary Linux capabilities and mounts are not granted;
- configuration changes are version-controlled;
- Alloy telemetry endpoints are not routed through public Traefik entrypoints.

The architectural acceptance of Docker-socket access SHALL be recorded as an explicit risk rather than treated as ordinary application access.

## 7. Application Availability Probes

Resource metrics SHALL NOT be treated as proof of application availability.

Grafana Alloy's embedded blackbox exporter SHALL be used to monitor supported HTTP, HTTPS, TCP, TLS, DNS, or protocol endpoints.

Initial availability probes SHALL cover:

- Traefik;
- Authentik;
- Confluence;
- Forgejo;
- ownCloud Infinite Scale;
- Grafana;
- critical PostgreSQL availability through the database exporter or equivalent check.

Where a service provides distinct liveness and readiness endpoints, readiness SHALL be preferred for operational service-health monitoring.

## 8. TLS and DNS Monitoring

Public ServiceHub HTTPS endpoints SHALL be monitored for:

- successful TLS handshake;
- certificate validity;
- certificate expiration;
- endpoint availability;
- probe response duration.

DNS monitoring SHOULD verify resolution of critical ServiceHub hostnames and external names required for identity, public ingress, and other key integrations.

TLS and DNS checks SHALL use Alloy blackbox probes where practical rather than introduce a separate synthetic-monitoring service.

## 9. Traefik Telemetry

Traefik SHALL remain the primary edge-traffic telemetry source.

ServiceHub SHALL retain collection of:

- Traefik operational logs;
- structured Traefik access logs;
- request counts and request rate;
- HTTP response-status counts;
- request and response duration;
- entrypoint, router, and backend-service metrics;
- TLS and configuration-reload information where available;
- client-source information;
- GeoIP enrichment.

Authorization headers, cookies, session tokens, API keys, and other credentials SHALL be dropped or redacted before log ingestion.

Detailed client IP information SHALL remain queryable in VictoriaLogs. Arbitrary client IP addresses SHALL NOT normally be used as persistent metric-label values because of metric cardinality risk.

Country, status, router, and service aggregations MAY be retained as bounded-cardinality metrics.

The existing `traefik_access_client_ip_requests_total` metric SHALL be reviewed and removed, limited, or redesigned if it creates unbounded metric-series growth.

## 10. Authentik Telemetry

Authentik SHALL receive native application monitoring in addition to generic container monitoring.

Alloy SHALL scrape Authentik Prometheus-compatible metrics from the server, worker, and applicable outposts over an internal-only observability network.

ServiceHub SHALL also retain and classify relevant Authentik events, including:

- authentication failures;
- provider and OIDC failures;
- worker failures;
- outpost errors;
- database-connectivity errors;
- application startup and configuration failures;
- security-relevant authentication activity where present in application logs.

Individual failed logins SHALL normally be retained for investigation but SHALL NOT automatically generate notifications. Alerts SHOULD operate on abnormal rates, sustained failure patterns, or service unavailability.

## 11. ownCloud Infinite Scale Telemetry

The ownCloud Infinite Scale proxy metrics SHALL be scraped initially.

The initial scope SHALL include:

- request totals;
- request rate;
- HTTP failures;
- error totals;
- request-duration histograms;
- proxy health;
- build or version information.

The implementation SHALL begin with proxy metrics and expand to additional oCIS internal services only when a demonstrated troubleshooting or capacity requirement exists.

The oCIS application logs SHALL continue to flow through container `stdout` or `stderr` into VictoriaLogs. Debug logging SHALL only be enabled temporarily during troubleshooting because it can significantly increase output volume.

## 12. Confluence Telemetry

Confluence SHALL initially receive:

- generic container metrics;
- container logs;
- Traefik request and latency metrics;
- Traefik access logs;
- availability probes.

Confluence JVM and application metrics SHOULD be added in a later implementation phase through a supported JMX-to-Prometheus exporter.

The Confluence JMX scope SHOULD include:

- JVM heap and non-heap usage;
- garbage-collection count and duration;
- thread count and blocked threads;
- request and application metrics;
- database connection-pool usage;
- database latency and pool-exhaustion indicators;
- supported Confluence application and plugin metrics.

The JMX exporter endpoint SHALL remain internal and SHALL NOT be publicly routed.

## 13. PostgreSQL Telemetry

PostgreSQL SHALL receive native database monitoring.

Grafana Alloy's built-in PostgreSQL exporter SHOULD be used rather than deploying a separate exporter container where compatible.

The initial PostgreSQL scope SHALL include:

- database availability;
- active, idle, and maximum connections;
- connection utilization;
- failed connections where available;
- transaction rate;
- commits and rollbacks;
- locks and lock waits;
- deadlocks;
- long-running transactions;
- database size and growth;
- cache and temporary-data indicators;
- WAL and storage-health indicators where appropriate.

A least-privilege monitoring database role SHALL be used.

Database credentials SHALL be supplied through ServiceHub's approved secret mechanism and SHALL NOT be committed to the repository.

## 14. Forgejo and Forgejo Actions

Forgejo SHALL initially use:

- generic container metrics;
- application and access logs;
- Traefik request metrics;
- Traefik access logs;
- HTTP availability probes.

Forgejo Actions Runner telemetry SHALL be logically distinguishable from the Forgejo server.

Logs SHOULD include normalized fields equivalent to:

```text
service="forgejo"
component="server"
```

and:

```text
service="forgejo"
component="runner"
```

The implementation SHOULD provide visibility into:

- runner availability;
- runner connectivity failures;
- job infrastructure failures;
- checkout or clone failures;
- Docker execution failures;
- resource-exhaustion failures.

A dedicated Forgejo metrics project SHALL NOT be required until the existing baseline is shown to be insufficient.

## 15. Observability-Stack Self-Monitoring

The observability platform SHALL monitor itself.

### Grafana Alloy

Monitor:

- scrape-target status;
- scrape failures;
- remote-write failures;
- log-pipeline failures;
- dropped or rejected telemetry where exposed;
- configuration and pipeline health.

### VictoriaMetrics

Monitor:

- ingestion health;
- ingestion errors;
- query health and latency;
- active-series growth;
- storage consumption;
- retention and storage growth;
- failed writes.

### VictoriaLogs

Monitor:

- log-ingestion rate;
- ingestion failures;
- query failures;
- query latency where exposed;
- storage growth;
- rejected log entries.

### Grafana

Monitor:

- Grafana availability;
- datasource connectivity;
- alert-rule evaluation failures;
- notification-delivery failures;
- dashboard/datasource provisioning failures where exposed.

ServiceHub SHALL be capable of detecting stale or missing telemetry so that an absence of data is not misinterpreted as a healthy platform.

## 16. Metrics, Logs, and Traces Ownership

Telemetry SHALL be routed according to signal responsibility.

### Metrics

VictoriaMetrics SHALL be the primary historical store for:

- host metrics;
- filesystem metrics;
- container metrics;
- application metrics;
- database metrics;
- probe metrics;
- observability-stack metrics;
- bounded-cardinality derived metrics.

### Logs

VictoriaLogs SHALL be the primary historical store for:

- Linux host logs;
- Docker daemon logs;
- container logs;
- application logs;
- Traefik access logs;
- authentication and security events;
- observability-platform logs.

### Traces

Oracle APM SHALL be used selectively for supported applications where distributed tracing materially improves diagnosis.

Oracle APM SHALL NOT be used as:

- the primary historical log store;
- the primary infrastructure-metrics store;
- a replacement for VictoriaMetrics;
- a replacement for VictoriaLogs;
- a destination for every ServiceHub application by default.

## 17. Oracle APM Integration

Oracle APM integration SHALL remain opt-in per service.

When Oracle APM tracing is implemented, ServiceHub SHALL configure:

```text
APM_DATA_UPLOAD_ENDPOINT=""
APM_PRIVATE_DATA_KEY=""
```

A public APM data key SHALL only be introduced if browser Real User Monitoring is separately approved and implemented.

The private APM data key SHALL:

- remain outside Git;
- not appear in `env.example` except as an empty variable;
- not be written into operational documentation;
- be supplied only to components that require it;
- be rotated if exposed.

The actual APM endpoint MAY be treated as non-secret configuration, while the private data key SHALL be treated as a secret.

Confluence Oracle APM Java Agent integration SHALL remain an evaluation action rather than an implementation requirement. Any evaluation SHALL consider JVM compatibility, supportability, performance overhead, upgrade persistence, and operational value.

## 18. Grafana Dashboards

Grafana SHALL be the primary ServiceHub visualization and operational-investigation interface.

ServiceHub SHALL maintain the following first-party dashboards:

1. **ServiceHub Overview**
2. **Infrastructure**
3. **Docker and Containers**
4. **Traffic and Edge**
5. **Security**
6. **Applications**
7. **Database**
8. **Observability Health**

### ServiceHub Overview

The landing dashboard SHALL summarize:

- host health and resource pressure;
- filesystem capacity;
- critical-service availability;
- container restarts and OOM events;
- HTTP traffic and error state;
- authentication failures;
- active critical alerts;
- observability-pipeline health.

### Infrastructure

The dashboard SHALL cover:

- CPU;
- memory;
- pressure-stall information;
- filesystem capacity;
- inodes;
- disk activity;
- network;
- system load;
- host uptime.

### Docker and Containers

The dashboard SHALL cover:

- running, stopped, missing, and unhealthy containers;
- CPU;
- memory and limits;
- CPU throttling;
- network;
- disk I/O;
- start time and last-seen state;
- restart loops and OOM events where observable.

### Traffic and Edge

The dashboard SHALL cover:

- Traefik request rate;
- HTTP status distribution;
- p50, p95, and p99 response latency;
- latency and errors by service or router;
- TLS availability and certificate expiration;
- GeoIP request distribution;
- selected web-security patterns.

### Security

The dashboard SHALL correlate:

- SSH authentication;
- sudo activity;
- Authentik authentication failures;
- Forgejo authentication failures;
- Traefik 401, 403, 404, and 429 responses;
- requests by country;
- recent security-relevant log events.

### Applications

The dashboard SHALL provide a service selector and a common view of:

- availability;
- request rate;
- error rate;
- latency;
- CPU;
- memory;
- restarts.

Service-specific sections SHALL be introduced for Authentik, ownCloud Infinite Scale, Confluence, Forgejo, and Forgejo Actions as their native telemetry becomes available.

### Database

The dashboard SHALL cover:

- PostgreSQL availability;
- connections and saturation;
- transactions;
- locks and deadlocks;
- long-running transactions;
- database size and growth;
- storage and WAL indicators.

### Observability Health

The dashboard SHALL cover:

- Alloy scrape and export health;
- VictoriaMetrics ingestion, query, and storage health;
- VictoriaLogs ingestion, query, and storage health;
- Grafana health;
- datasource connectivity;
- alert evaluation and notification state;
- last-received metrics and logs where practical.

Community or vendor dashboards MAY be retained as reference dashboards but SHALL NOT be treated as the authoritative ServiceHub operational interface.

## 19. Dashboard Provisioning and Drill-Down

ServiceHub-owned dashboards SHALL be version-controlled and provisioned where practical.

The proposed repository structure is:

```text
observability/
├── alloy/
├── grafana/
│   ├── dashboards/
│   │   ├── servicehub-overview.json
│   │   ├── infrastructure.json
│   │   ├── docker-containers.json
│   │   ├── traffic-edge.json
│   │   ├── security.json
│   │   ├── applications.json
│   │   ├── database.json
│   │   └── observability-health.json
│   └── provisioning/
└── alerts/
```

Dashboards SHOULD support contextual drill-down from:

- ServiceHub overview to component dashboards;
- traffic symptoms to application dashboards;
- application symptoms to database metrics;
- metric anomalies to relevant VictoriaLogs queries;
- log events to related Oracle APM traces where correlation identifiers exist.

Dashboard links SHOULD preserve the selected service and incident time range wherever practical.

## 20. Grafana Alerting

Grafana Alerting SHALL be the primary alert engine for ServiceHub platform and application conditions.

The initial implementation SHALL use Grafana-managed alerting.

`vmalert` and Alertmanager SHALL NOT be introduced initially. They MAY be reconsidered if ServiceHub later requires:

- a large alert-rule catalogue;
- Git-managed datasource-side rule evaluation;
- alert evaluation independent of Grafana;
- more advanced alert-state persistence or routing;
- multiple Grafana instances.

Alerting SHALL follow this principle:

> Collect broadly, dashboard intelligently, and alert narrowly.

An alert SHALL normally be created only when the detected condition is actionable.

### Initial critical alerts

- OCI host unavailable;
- host filesystem above the critical utilization threshold;
- inode exhaustion;
- filesystem becomes read-only;
- critical service unavailable;
- container restart loop;
- container OOM kill;
- PostgreSQL unavailable;
- Traefik unavailable;
- Authentik unavailable;
- Confluence unavailable;
- Forgejo unavailable;
- ownCloud Infinite Scale unavailable;
- scheduled backup failure;
- telemetry ingestion stopped or failed.

### Initial warning alerts

- host filesystem above warning threshold;
- sustained CPU pressure;
- sustained memory pressure;
- sustained I/O pressure;
- sustained Traefik HTTP 5xx rate;
- sustained Traefik latency degradation;
- Forgejo Actions Runner unavailable;
- Confluence JVM or garbage-collection pressure once JMX is implemented;
- abnormal authentication-failure rate;
- TLS certificate approaching expiration;
- observability storage growth approaching capacity.

Single failed logins, occasional HTTP 404 responses, transient CPU spikes, and other normal Internet or workload noise SHALL remain queryable without generating individual notifications.

Alerts SHALL use suitable persistence windows, grouping, and recovery behavior to reduce alert fatigue.

## 21. External Availability Monitoring

The ServiceHub Grafana observability stack runs on the same OCI host as the services it monitors.

Grafana cannot reliably notify the owner if the entire OCI VM, network path, or self-hosted observability stack is unavailable.

OCI Monitoring SHALL therefore provide independent external coverage for at least:

- compute-instance availability;
- relevant OCI infrastructure failure;
- failure conditions that prevent Grafana Alerting from operating.

OCI Monitoring SHALL complement rather than duplicate every ServiceHub application alert.

## 22. Backup Monitoring

Backup success SHALL be observable and alertable.

The monitoring implementation SHOULD expose:

- last successful backup timestamp;
- last backup result;
- backup duration;
- backup size;
- backup destination status where available.

Failure to complete an expected backup within the approved schedule SHALL generate a critical alert.

Backup monitoring SHALL cover the ServiceHub data stores and persistent data protected by the documented backup architecture.

## 23. Telemetry Labels

ServiceHub telemetry SHALL use consistent labels or fields where applicable.

The target normalized dimensions are:

```text
project="servicehub"
environment="<environment>"
instance="<hostname>"
service="<logical-service>"
component="<logical-component>"
container_name="<container-name>"
compose_project="<compose-project>"
compose_service="<compose-service>"
```

Not every value SHALL necessarily be stored as an indexed label in every backend. The final implementation SHALL account for backend cardinality and query characteristics.

Service and component names SHALL follow the ServiceHub naming conventions defined by ADR-008 and related architecture documents.

## 24. Cardinality Control

Metrics SHALL use bounded-cardinality dimensions.

The following SHALL NOT normally be promoted to metric labels:

- arbitrary client IP addresses;
- user IDs;
- email addresses;
- request IDs;
- trace IDs;
- session IDs;
- dynamic URL paths;
- unrestricted repository names;
- arbitrary error messages.

These values MAY remain searchable as log fields or trace attributes.

Where a diagnostic dimension is operationally useful but unbounded, analysis SHALL normally occur in VictoriaLogs rather than VictoriaMetrics.

Alloy relabelling, filtering, and aggregation SHOULD be used to prevent unnecessary or unbounded metric-series growth.

## 25. Log Sanitation

Telemetry SHALL not deliberately retain secrets or reusable credentials.

The collection pipeline and source applications SHALL drop, redact, or avoid recording:

- authorization headers;
- cookies and session tokens;
- API keys;
- passwords;
- OAuth tokens;
- secret environment values;
- private APM data keys;
- other reusable authentication material.

Traefik access-log header and field filtering SHALL be configured accordingly.

Sensitive personal identifiers SHALL only be retained where necessary for security or operational investigation and SHALL be subject to the applicable retention policy.

## 26. Retention and Capacity

Retention SHALL be determined separately for telemetry classes based on:

- security value;
- troubleshooting value;
- capacity;
- privacy;
- operational cost.

The actual retention periods SHALL be recorded in `MONITORING-ALERTING.md`, not hard-coded in this ADR.

The initial planning ranges SHOULD consider:

- infrastructure metrics: up to 12 months;
- application metrics: 6 to 12 months;
- ordinary application logs: approximately 90 days;
- HTTP access logs: approximately 90 days;
- security logs: up to 12 months;
- debug logs: short-term and temporary;
- Oracle APM traces: subject to the configured APM-domain retention.

Retention settings SHALL only be finalized after actual ingestion rate and storage growth are measured.

## 27. Log Troubleshooting Documentation

Implementation of this ADR SHALL include a dedicated operational guide:

```text
docs/operations/LOG-TROUBLESHOOTING.md
```

The guide SHALL document:

- the ServiceHub logging architecture;
- log labels and structured fields;
- use of Grafana Explore with VictoriaLogs;
- tested basic query patterns;
- service-specific query examples;
- host and Docker troubleshooting;
- security-investigation workflows;
- performance-investigation workflows;
- metric-to-log correlation;
- log-to-trace correlation where available;
- common incident playbooks;
- known query and datasource limitations;
- a ready-to-copy query cookbook.

The guide SHALL include tested examples for:

- all logs for one service;
- error and warning logs;
- one container;
- known incident time windows;
- Traefik HTTP 5xx responses;
- Traefik 401, 403, 404, and 429 responses;
- slow Traefik requests;
- activity from a source IP;
- activity from a country;
- Authentik authentication and provider failures;
- Confluence startup, JVM, database, and timeout errors;
- Forgejo Git, webhook, SSH, and database errors;
- Forgejo Actions Runner failures;
- ownCloud upload, download, WebDAV, authorization, and storage errors;
- Linux SSH, sudo, firewall, kernel, OOM, and Docker-daemon events;
- observability pipeline failures.

The examples SHALL use the actual VictoriaLogs datasource query syntax configured in Grafana. Loki LogQL examples SHALL NOT be copied unmodified unless confirmed compatible with the configured VictoriaLogs datasource.

High-cardinality diagnostic context SHALL remain queryable without being indiscriminately promoted to metric labels.

## 28. Operational Documentation Boundaries

This ADR defines:

- the observability architecture;
- component responsibilities;
- required telemetry categories;
- security and cardinality rules;
- dashboard categories;
- alerting ownership;
- Oracle APM's role;
- documentation deliverables.

`MONITORING-ALERTING.md` SHALL define:

- implemented collectors;
- scrape targets;
- service endpoints;
- exact metric catalogue;
- exact log sources and filters;
- dashboard inventory and UIDs;
- health probes;
- alert expressions;
- thresholds;
- persistence windows;
- severity;
- notification routing;
- retention values;
- OCI external monitoring;
- implementation-verification evidence.

`LOG-TROUBLESHOOTING.md` SHALL define:

- tested VictoriaLogs queries;
- investigation workflows;
- service-specific troubleshooting;
- security investigation;
- performance diagnosis;
- metric/log/trace correlation.

Dashboard JSON, Alloy configuration, Grafana provisioning, and alert provisioning SHALL remain version-controlled implementation artifacts.

## 29. Explicitly Excluded Components

The following components SHALL NOT be added as part of the initial ADR-010 implementation:

- Prometheus, because VictoriaMetrics is the metrics store;
- Loki, because VictoriaLogs is the log store;
- vmagent, because Grafana Alloy performs collection and routing;
- a separate OpenTelemetry Collector, because Grafana Alloy provides the required OpenTelemetry collection/routing capability;
- Alertmanager and `vmalert`, because Grafana-managed alerting is sufficient initially;
- Grafana Pyroscope, because continuous code-level profiling is not currently justified;
- Splunk or another SIEM, because VictoriaLogs and Grafana satisfy the current operational and security-investigation requirements;
- a second general-purpose Docker metrics exporter;
- LiteLLM or other local `aiserv` telemetry, because local AI services are outside the OCI ServiceHub deployment.
- Stalwart, Bulwark, or other relocated mail-platform telemetry, because the mail platform is outside the OCI ServiceHub deployment governed by this ADR.

These exclusions MAY be reconsidered through a subsequent decision if an evidenced requirement cannot be met by the approved architecture.

## 30. Options Considered

### Option 1: OCI-native observability only

Use Oracle Cloud Agent, OCI Monitoring, OCI Logging, and Oracle APM as the entire observability environment.

**Rejected as the primary design.**

Advantages:

- fewer self-hosted components;
- direct OCI integration;
- vendor-managed storage and interfaces.

Disadvantages:

- Oracle APM Always Free limits and retention;
- less control over long-term metrics and log retention;
- increased dependency on OCI ingestion and pricing;
- reduced portability;
- existing ServiceHub observability implementation would be discarded;
- less suitable for consolidated long-term homelab analysis.

### Option 2: Self-hosted Grafana stack only

Use Alloy, VictoriaMetrics, VictoriaLogs, and Grafana with no Oracle observability integration.

**Not selected as the complete design.**

Advantages:

- maximum data ownership;
- long-term retention under ServiceHub control;
- vendor-neutral collection;
- no OCI APM ingestion dependency.

Disadvantages:

- no external observer if the OCI VM fails;
- no use of Oracle APM's specialized tracing capabilities;
- the observability platform shares the same failure domain as the workloads.

### Option 3: Hybrid ServiceHub-owned observability plus selective OCI services

Use Alloy, VictoriaMetrics, VictoriaLogs, and Grafana as the primary platform; use Oracle APM selectively for traces and OCI Monitoring for independent VM-level visibility.

**Selected.**

This option provides:

- durable ServiceHub-owned metrics and logs;
- a single vendor-neutral collector;
- selective managed APM capabilities;
- independent external VM monitoring;
- controlled cost and ingestion;
- long-term operational visibility;
- reduced vendor lock-in.

### Option 4: Introduce Prometheus, Loki, Alertmanager, and a separate OpenTelemetry Collector

**Rejected.**

This would duplicate functions already supplied by VictoriaMetrics, VictoriaLogs, Grafana Alerting, and Grafana Alloy without a demonstrated ServiceHub requirement.

## 31. Rationale

The selected architecture preserves the substantial observability implementation already present in ServiceHub while addressing identifiable gaps.

Grafana Alloy already provides the collection, enrichment, routing, and exporter capabilities required by the platform. VictoriaMetrics and VictoriaLogs provide controlled historical storage. Grafana provides a unified operational interface and alerting. Oracle APM adds selective distributed tracing without becoming the persistence layer for every signal.

The design deliberately separates:

- metrics from logs;
- logs from traces;
- historical storage from specialized APM;
- internal platform monitoring from external VM monitoring;
- architecture from operational configuration.

This separation reduces duplicated telemetry, controls cardinality and storage growth, and lets ServiceHub retain observability continuity if Oracle APM is changed or discontinued.

## 32. Positive Consequences

- ServiceHub retains long-term control of metrics and logs.
- Existing observability assets remain useful.
- Security, stability, and performance are first-class monitoring objectives.
- Filesystem-capacity and host-security blind spots are removed.
- Container-running state is separated from application readiness.
- Native Authentik, oCIS, PostgreSQL, and later Confluence metrics provide better application insight.
- Grafana provides a coherent dashboard and investigation experience.
- Logs can be investigated through documented and repeatable workflows.
- Oracle APM can provide tracing without becoming the primary data store.
- OCI Monitoring provides an external observer for complete VM failure.
- No unnecessary duplicate collectors or storage systems are introduced.
- Dashboard, collector, and alert definitions can be version-controlled.
- Applications can use vendor-neutral telemetry interfaces.

## 33. Negative Consequences

- The observability stack consumes OCI VM CPU, memory, and storage.
- The observability platform shares a host failure domain with most monitored services.
- Grafana Alloy requires privileged host and Docker access.
- Long-term retention requires active storage-capacity management.
- Application-native metrics require per-service configuration.
- Confluence JMX monitoring requires a JVM configuration change.
- PostgreSQL monitoring requires a least-privilege monitoring credential.
- More dashboards and alerts require maintenance and testing.
- Telemetry pipelines can fail silently unless their own health is monitored.
- Security and log retention increase privacy and data-governance responsibility.

## 34. Risks and Mitigations

### Host storage exhaustion

VictoriaMetrics, VictoriaLogs, Docker, databases, repositories, and application files all consume the same host storage.

Mitigations:

- restore correct filesystem and inode monitoring;
- implement warning and critical thresholds;
- retain Docker local log rotation;
- monitor VictoriaMetrics and VictoriaLogs storage growth;
- define retention based on measured ingestion.

### Alloy or Docker-socket compromise

Alloy has privileged access to Docker and selected host resources.

Mitigations:

- keep Alloy internal;
- restrict and minimize mounts;
- use read-only mounts where possible;
- pin or control images;
- version-control configuration;
- do not expose administrative interfaces;
- document the privilege boundary.

### Metric cardinality growth

GeoIP data, client IPs, user identifiers, paths, and arbitrary application fields can create unbounded series.

Mitigations:

- keep high-cardinality context in VictoriaLogs;
- use bounded metric dimensions;
- remove or constrain per-client-IP derived metrics;
- review active-series growth;
- apply relabelling and filtering.

### Sensitive information in logs

Application and access logs may contain credentials, tokens, personal data, or private content.

Mitigations:

- redact sensitive headers;
- avoid debug logging by default;
- sanitize at the source or Alloy pipeline;
- document sensitive-field policy;
- use appropriate retention.

### Alert fatigue

Internet scanning, transient spikes, and normal workload variation can produce noisy alerts.

Mitigations:

- alert only on actionable conditions;
- use persistence windows;
- aggregate repeated conditions;
- alert on rates and patterns rather than individual events;
- begin with a small rule set.

### Complete OCI VM failure

Grafana and its alert engine cannot notify if the entire VM is unavailable.

Mitigation:

- retain independent OCI Monitoring for compute-instance availability.

### Oracle APM quota or retention limits

The Always Free APM domain may throttle spans and only retains trace data for a limited period.

Mitigations:

- keep historical metrics in VictoriaMetrics;
- keep historical logs in VictoriaLogs;
- send traces selectively;
- apply sampling;
- monitor Oracle APM ingestion if implemented.

## 35. Non-Goals

This ADR does not:

- define every PromQL, MetricsQL, or VictoriaLogs query;
- establish final retention durations;
- establish every alert threshold;
- establish the final notification channel;
- require tracing for every service;
- monitor local `aiserv` workloads from the OCI deployment;
- monitor Stalwart, Bulwark, or other mail-platform workloads after they are relocated away from OCI;
- introduce Loki, Prometheus, Pyroscope, vmagent, Alertmanager, `vmalert`, Splunk, or a separate SIEM;
- require browser real-user monitoring;
- prescribe a complete enterprise incident-management process;
- replace application-specific audit records with ordinary logs;
- require all available metrics from every application.

## 36. Implementation Phases

### Phase 1: Correct foundational gaps

1. Remove LiteLLM scrape targets, dashboards, alerting, labels, and OCI observability references.
2. Restore correct host filesystem and inode monitoring.
3. Add selective Linux host journal collection.
4. Add service availability probes.
5. Add TLS certificate monitoring.
6. Add initial Grafana alerting.
7. Add OCI external VM-availability monitoring.
8. Add backup-success telemetry.

### Phase 2: Security-critical application telemetry

1. Add Authentik metrics and readiness monitoring.
2. Normalize authentication and security log fields.
3. Review and constrain client-IP metric cardinality.
4. Build the Security dashboard.

### Phase 3: Application and database telemetry

1. Add ownCloud Infinite Scale proxy metrics.
2. Add PostgreSQL metrics.
3. Add Forgejo Actions Runner availability and log separation.
4. Add observability-stack self-monitoring.
5. Build the Applications and Database dashboards.

### Phase 4: Advanced diagnostics

1. Evaluate and add Confluence JMX metrics.
2. Evaluate selected Oracle APM traces.
3. Add metric-to-log and log-to-trace links.
4. Refine retention from observed volume.
5. Refine alert thresholds using operating history.

## 37. Implementation Evidence

No v1.0 implementation evidence is recorded as of 2026-10-15.

Existing implementation evidence to preserve and verify includes:

- Grafana Alloy Unix metrics collection;
- Grafana Alloy cAdvisor collection with Docker-only behavior;
- Docker log collection through `loki.source.docker`;
- VictoriaMetrics metric ingestion;
- VictoriaLogs log ingestion;
- Traefik metric scraping;
- Traefik structured access logs;
- GeoIP enrichment;
- Grafana community/reference dashboards;
- Grafana Alloy self-metrics.

Implementation SHALL record evidence for each phase in `MONITORING-ALERTING.md`.

Evidence SHOULD include:

- relevant configuration paths;
- active scrape-target status;
- example metric names;
- example ingested logs;
- probe results;
- dashboard UIDs;
- alert test results;
- notification test results;
- filesystem visibility;
- observed retention and storage growth;
- screenshot or query evidence where appropriate.

## 38. Follow-up Actions

| Action | Owner | Due date | Status |
|---|---|---:|---|
| Update ADR-009 to retain the OCI `obsvce` deployment scope or document the approved exception | ServiceHub Architecture | TBD | Proposed |
| Remove LiteLLM from OCI observability configuration and documentation | ServiceHub Architecture | TBD | Proposed |
| Restore host filesystem and inode monitoring with minimum read-only host access | ServiceHub Architecture | TBD | Proposed |
| Add selective Linux journal collection | ServiceHub Architecture | TBD | Proposed |
| Add HTTP/HTTPS/TCP/TLS service probes through Alloy blackbox exporter | ServiceHub Architecture | TBD | Proposed |
| Add initial Grafana alert rules | ServiceHub Architecture | TBD | Proposed |
| Configure independent OCI compute-instance monitoring | George Li | TBD | Proposed |
| Add backup-success telemetry and backup-failure alert | ServiceHub Architecture | TBD | Proposed |
| Add Authentik metrics and readiness monitoring | ServiceHub Architecture | TBD | Proposed |
| Add oCIS proxy metrics | ServiceHub Architecture | TBD | Proposed |
| Add PostgreSQL monitoring with a least-privilege role | ServiceHub Architecture | TBD | Proposed |
| Add observability-stack self-monitoring | ServiceHub Architecture | TBD | Proposed |
| Review `traefik_access_client_ip_requests_total` cardinality | ServiceHub Architecture | TBD | Proposed |
| Create the eight ServiceHub-owned Grafana dashboards | ServiceHub Architecture | TBD | Proposed |
| Version-control Grafana dashboard and alert provisioning | ServiceHub Architecture | TBD | Proposed |
| Create `LOG-TROUBLESHOOTING.md` with tested VictoriaLogs queries | ServiceHub Architecture | TBD | Proposed |
| Evaluate Confluence JMX metrics | ServiceHub Architecture | TBD | Proposed |
| Evaluate selective Oracle APM tracing after the baseline platform is stable | George Li | TBD | Proposed |
| Measure ingestion volume and finalize retention values | George Li | TBD | Proposed |

## 39. Related Documents

- [ADR-008 Standardise Service Naming, Storage, and Bind Mounts](ADR-008-standardise-service-naming-storage-and-bind-mounts.md)
- [ADR-009 Rescope the OCI Deployment, Relocate AI Services to Local Infrastructure, and Harden Platform Boundaries](ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md)
- [Monitoring and Alerting](../../operations/MONITORING-ALERTING.md)
- [Log Troubleshooting](../../operations/LOG-TROUBLESHOOTING.md)
- [Deployment Architecture](../DEPLOYMENT-ARCHITECTURE.md)
- [Architecture](../ARCHITECTURE.md)

---

# Appendix A: AI Coding Agent Implementation Prompt

```text
Implement ADR-010 in controlled phases.

Treat ADR-010 as the authoritative architecture decision. Do not introduce
additional observability products outside the approved stack.

Approved stack:

- Grafana Alloy for collection, enrichment, probing, and routing
- VictoriaMetrics for metrics
- VictoriaLogs for logs
- Grafana for dashboards, investigation, and initial alerting
- OCI Monitoring for independent VM-level availability monitoring
- Oracle APM only for later, selective application traces

Explicitly excluded for this implementation:

- LiteLLM and all local aiserv telemetry
- Stalwart, Bulwark, and all relocated mail-platform telemetry
- Prometheus
- Loki
- vmagent
- vmalert
- Alertmanager
- Pyroscope
- a separate OpenTelemetry Collector
- Splunk or another SIEM

Before modifying files:

1. Inspect the current observability implementation and identify:
   - Compose services and mounts
   - Alloy configuration and pipelines
   - VictoriaMetrics and VictoriaLogs configuration
   - Grafana provisioning and dashboards
   - current alert configuration
   - current LiteLLM observability references
   - current ADR-008 and ADR-009 constraints

2. Produce a gap analysis mapped to ADR-010 sections.

3. Produce a phased implementation plan with:
   - exact files to add or modify
   - security impact
   - restart or migration impact
   - validation procedure
   - rollback procedure

Do not implement every phase in one uncontrolled change.

Implement Phase 1 first:

- remove LiteLLM from OCI observability configuration and documentation;
- restore correct host filesystem and inode monitoring using the minimum
  necessary read-only host mounts;
- add selective Linux journal collection;
- add Alloy blackbox probes for critical ServiceHub services;
- add TLS certificate-expiry monitoring;
- add observability-pipeline self-health metrics;
- add a minimal initial Grafana alert set;
- add backup-success telemetry if the current backup implementation provides
  a suitable signal.

Preserve the existing:

- Unix host metrics;
- cAdvisor Docker metrics;
- Docker log collection;
- Traefik metrics;
- Traefik access logs;
- GeoIP enrichment;
- VictoriaMetrics integration;
- VictoriaLogs integration;
- Grafana provisioning.

Review the cardinality of traefik_access_client_ip_requests_total. Prefer
retaining individual IP addresses as VictoriaLogs fields rather than
VictoriaMetrics labels.

Use consistent telemetry dimensions where practical:

- project=servicehub
- environment
- instance
- service
- component
- container_name
- compose_project
- compose_service

Do not promote unbounded values such as client IP, email address, request ID,
trace ID, session ID, dynamic URL path, or arbitrary error text to metrics
labels.

Create or update:

- docs/operations/MONITORING-ALERTING.md
- docs/operations/LOG-TROUBLESHOOTING.md
- Grafana dashboard provisioning
- Grafana alert provisioning
- Alloy configuration
- Compose configuration only where required

ServiceHub-owned dashboard targets:

1. ServiceHub Overview
2. Infrastructure
3. Docker and Containers
4. Traffic and Edge
5. Security
6. Applications
7. Database
8. Observability Health

Community dashboards may remain in a separate Reference folder.

LOG-TROUBLESHOOTING.md must contain tested queries using the actual configured
VictoriaLogs Grafana datasource syntax. Do not assume Loki LogQL compatibility.
Include host, Docker, Traefik, Authentik, Confluence, Forgejo, Forgejo Actions,
oCIS, PostgreSQL, security, and performance investigation workflows.

For each implemented capability, record evidence in MONITORING-ALERTING.md:

- configuration path
- active target or component health
- representative metric
- representative ingested log
- probe result
- dashboard UID where applicable
- alert test and recovery result
- notification test result where applicable

Do not mark ADR-010 as implemented solely because the configuration files exist.
Implementation is complete only after successful runtime verification.

Stop after completing and validating Phase 1. Report:

- files changed
- requirements implemented
- requirements deferred
- validation evidence
- security implications
- any detected conflict with ADR-008 or ADR-009
- recommended next phase
```
