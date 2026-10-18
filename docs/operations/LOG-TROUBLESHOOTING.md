---
project: ServiceHub
project_code: SVCHUB
document_type: OPS
document_id: LOG-TROUBLESHOOTING
title: ServiceHub Log Troubleshooting
version: "1.0"
status: Draft
lifecycle_stage: Operations
owner: George Li
maintainer: George Li
created: 2026-10-18
updated: 2026-10-18
tags:
  - servicehub
  - operations
  - observability
  - logs
  - troubleshooting
related_documents:
  - MONITORING-ALERTING
  - SERVICE-INVENTORY
  - ADR-010
---

# ServiceHub Log Troubleshooting

> **Status:** Implemented in configuration; runtime verification pending. No query in this guide has yet been executed against the OCI VictoriaLogs service. Treat every query below as `Runtime verification pending`.

## Logging architecture

Grafana Alloy reads Docker container logs through the Docker socket, redacts likely secret patterns, extracts Traefik client and GeoIP fields, and pushes entries to VictoriaLogs. Selective Linux journald sources use bounded labels (`project`, `environment`, `service`, `component`, `source`) and keep usernames, IP addresses, command names, paths, PIDs, and message text as fields or structured metadata rather than metric labels.

Grafana uses the provisioned datasource:

```text
Name:      VictoriaLogs
Type:      victoriametrics-logs-datasource
UID:       victorialogs
Language:  VictoriaLogs LogsQL
```

Do not copy Loki LogQL expressions without confirming compatibility. VictoriaLogs supports stream selectors such as `{project="servicehub"}` and filters such as `| container_name="routetraefik"`, but field names and pipeline operators require runtime verification in Phase 5.

## Core query cookbook

### Docker and service scoping

All logs:

```logsql
{project="servicehub"}
```

Logs for one container:

```logsql
{project="servicehub"} | container_name="routetraefik"
```

Errors and warnings:

```logsql
{project="servicehub"} | level~="error|warn"
```

Known incident window (replace RFC 3339 values before use):

```logsql
{project="servicehub"} | time >= 2026-10-18T00:00:00Z | time <= 2026-10-18T01:00:00Z
```

Status: Runtime verification pending.

### Linux journald

Host security journal:

```logsql
{project="servicehub",source="journal",component="security"}
```

Kernel, storage, and Docker stability events:

```logsql
{project="servicehub",source="journal"} | component~="system|runtime"
```

Systemd failures:

```logsql
{project="servicehub",source="journal",component="systemd"}
```

Firewall events when firewalld logging is enabled:

```logsql
{project="servicehub",source="journal",component="firewall"}
```

Status: Runtime verification pending.

### Traefik and edge traffic

Traefik logs:

```logsql
{project="servicehub"} | container_name="routetraefik"
```

HTTP 5xx responses:

```logsql
{project="servicehub"} | container_name="routetraefik" | DownstreamStatus~="^5..$"
```

Authentication, authorization, missing-resource, and rate-limit responses:

```logsql
{project="servicehub"} | container_name="routetraefik" | DownstreamStatus~="^(401|403|404|429)$"
```

Slow requests:

```logsql
{project="servicehub"} | container_name="routetraefik" | Duration > 2000000000
```

Activity from a source IP:

```logsql
{project="servicehub"} | container_name="routetraefik" | client_ip="203.0.113.10"
```

Activity from a country:

```logsql
{project="servicehub"} | container_name="routetraefik" | geoip_country_code="US"
```

Status: Runtime verification pending. Traefik JSON field names and duration units must be verified in Phase 5.

### Authentik

Authentik authentication and provider failures:

```logsql
{project="servicehub"} | container_name=~"infraauth|infraauthwrk" | level~="error|warn"
```

OIDC and database-connectivity investigation:

```logsql
{project="servicehub"} | container_name=~"infraauth|infraauthwrk" | msg~="(?i)oidc|provider|database|postgres"
```

Status: Runtime verification pending.

### Confluence

Confluence startup and runtime errors:

```logsql
{project="servicehub"} | container_name="webappconf" | level~="error|warn"
```

JVM, database, and timeout events:

```logsql
{project="servicehub"} | container_name="webappconf" | msg~="(?i)jvm|heap|garbage|database|timeout|connection"
```

Status: Runtime verification pending.

### Forgejo and Actions

Forgejo server errors:

```logsql
{project="servicehub"} | container_name="devopsforgejo" | level~="error|warn"
```

Forgejo Actions runner errors:

```logsql
{project="servicehub"} | container_name="devopsrunner" | level~="error|warn"
```

Git, webhook, SSH, database, and job-infrastructure errors:

```logsql
{project="servicehub"} | container_name=~"devopsforgejo|devopsrunner" | msg~="(?i)git|webhook|ssh|database|clone|checkout|docker|resource"
```

Status: Runtime verification pending.

### ownCloud Infinite Scale

Upload, download, WebDAV, authorization, and storage errors:

```logsql
{project="servicehub"} | container_name="webappocis" | msg~="(?i)upload|download|webdav|authorize|authoriz|storage|quota"
```

All oCIS errors and warnings:

```logsql
{project="servicehub"} | container_name="webappocis" | level~="error|warn"
```

Status: Runtime verification pending.

### PostgreSQL

PostgreSQL container errors and connection failures:

```logsql
{project="servicehub"} | container_name="infrapgsql" | level~="error|fatal|panic|warn"
```

Database lock, timeout, and long-transaction evidence:

```logsql
{project="servicehub"} | container_name="infrapgsql" | msg~="(?i)lock|timeout|connection|deadlock|transaction"
```

Status: Runtime verification pending.

### Observability pipeline

Alloy, VictoriaMetrics, VictoriaLogs, and Grafana logs:

```logsql
{project="servicehub",container_name=~"obsvcealloy|obsvcevm|obsvcevlogs|obsvcegrafana"}
```

Pipeline failures:

```logsql
{project="servicehub",container_name=~"obsvcealloy|obsvcevm|obsvcevlogs|obsvcegrafana"} | level~="error|warn"
```

Remote-write and scrape failures visible in Alloy metrics are documented in [Monitoring and Alerting](MONITORING-ALERTING.md).

Status: Runtime verification pending.

## Investigation workflows

1. Confirm the time range, selected environment, and affected service.
2. Start with the relevant service query, then narrow by container, component, or level.
3. Correlate a log event with nearby host, container, Traefik, or database metrics in the ServiceHub dashboards.
4. Use `client_ip`, `geoip_country_code`, `systemd_unit`, and `process_name` for context; do not infer trust from an HTTP header without reviewing the proxy chain.
5. For security incidents, preserve the query result, affected time window, and source IP outside Grafana before remediation.
6. For observability failures, distinguish collector failure from store failure before restarting services on OCI.

## Known limitations

- The VictoriaLogs query fields and operators in this guide are statically selected from configured labels and expected JSON fields. They are not runtime-tested.
- Secret redaction is applied by Alloy before storage; its effectiveness and timeout behavior require runtime verification.
- Structured metadata support and searchability for client IP, GeoIP city, latitude, and longitude require runtime verification.
- Mail-platform logs, probes, and dashboards are Outside scope and intentionally absent.
