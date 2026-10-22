# Observability Operations Guide

> Platform-local metrics, logs, probes, dashboards, and Grafana-managed alert evaluation for ServiceHub.

## Purpose and scope

This document describes the operational observability platform (ADR-010) deployed as the `obsvce` stack. It provides:

- **Metrics**: Host, container, Traefik, native application (Authentik, oCIS, Alloy, PostgreSQL), and blackbox probe metrics → VictoriaMetrics → Grafana
- **Logs**: Journal (SSH, sudo, logind, kernel, Docker, systemd, firewall), container logs, Traefik access logs → Alloy → VictoriaLogs → Grafana
- **Dashboards**: 8 first-party ServiceHub dashboards + 10 reference dashboards provisioned via file provider
- **Alert evaluation**: 27 Grafana-managed rules across 3 groups; evaluation enabled, notification delivery intentionally not configured

External tracing (OCI APM), an independent host watchdog, and Logs Drilldown are deferred/disabled and documented in Limitations.

---

## Data flow

```
Host metrics (node_exporter via unix exporter) --------+
Container metrics (cAdvisor) ---------------------------+
Native service metrics (Authentik, oCIS, PostgreSQL) ---+--> Alloy --> VictoriaMetrics --> Grafana
Blackbox probes (internal readiness, public HTTPS/TLS) -+

Journal logs (security, system, kernel, Docker) --------+
Container logs (Docker JSON, Authentik JSON, oCIS JSON, plain-text) -+--> Alloy --> VictoriaLogs --> Grafana
Traefik access logs (JSON) -----------------------------+
```

All components communicate over the internal Docker `subnet` network. VictoriaMetrics and VictoriaLogs expose host-bound management ports (`127.0.0.1:8428`, `127.0.0.1:9428`) for host-side health checks; Alloy and Grafana use the internal Docker DNS names.

---

## Component responsibilities

| Component | Role | Key config | Data produced |
|-----------|------|------------|---------------|
| **Alloy** (`obsvcealloy`) | Single telemetry collector. Scrapes Prometheus endpoints, tails Docker/journal logs, runs blackbox probes, enriches with GeoIP, forwards metrics to VictoriaMetrics and logs to VictoriaLogs. | `shared/grafana/alloy/config.alloy` (973 lines), `postgres.alloy`, `blackbox.yml` | `project="servicehub"` label on all series/streams; bounded `logical_service` identity (8 values); GeoIP country code as label |
| **VictoriaMetrics** (`obsvcevm`) | Long-term metric storage, Prometheus-compatible query API, remote-write receiver. | `compose/obsvce.yml`, `--storageDataPath=/storage` | Metrics from Alloy scrapes; `/health` endpoint |
| **VictoriaLogs** (`obsvcevlogs`) | Long-term log storage, LogSQL/LogQL query API, Loki-compatible push endpoint. | `compose/obsvce.yml`, `--storageDataPath=/vlogs` | Logs from Alloy; `/health` endpoint |
| **Grafana** (`obsvcegrafana`) | Visualization, dashboard provisioning, alert evaluation. Built-in auth + Traefik `TRUSTED_IP` allowlist. Plugins: `victoriametrics-logs-datasource`; Drilldown: Metrics enabled, Logs/Traces disabled. | `shared/grafana/provisioning/` (datasources, dashboards, alerting) | 18 dashboards provisioned, 27 alert rules loaded |
| **cAdvisor** (embedded in Alloy) | Container CPU, memory, disk I/O, network, restart/OOM metrics. | `prometheus.exporter.cadvisor` in `config.alloy` | `container_*`, `container_label_*` → relabeled to `compose_service` + `logical_service` |
| **node/host exporter** (unix exporter) | Host CPU, memory, filesystem, disk, network, PSI, load, uptime. | `prometheus.exporter.unix` in `config.alloy` (procfs/sysfs/rootfs from `/host/*`) | `node_*` metrics with `job="obstack"` |
| **PostgreSQL exporter** | Optional (enabled via `POSTGRES_EXPORTER_ENABLED=true`). Database connections, transactions, locks, cache, WAL, size. | `shared/grafana/alloy/postgres.alloy` | `pg_*` metrics |
| **Blackbox probes** | Internal readiness (`/ping`, `/health/ready`, `/status`, `/api/healthz`, `/status.php`) and public HTTPS/TLS/cert expiry. | `prometheus.exporter.blackbox` + `blackbox.yml` | `probe_success`, `probe_ssl_earliest_cert_expiry`, `probe_duration_seconds` with `target_class=internal|external` |
| **Traefik** | Ingress metrics (`traefik_service_*`) + JSON access logs (via Docker log driver → Alloy). | Traefik `metrics.prometheus` + Docker logging | Request rate/latency/codes, open connections, TLS state, config reloads, access logs |

---

## Health and validation

### Safe component health checks

```bash
# Alloy
curl -fsS http://localhost:9080/health

# VictoriaMetrics
curl -fsS http://localhost:8428/health

# VictoriaLogs
curl -fsS http://localhost:9428/health

# Grafana
curl -fsS http://localhost:3000/api/health
```

### Safe bounded log checks (last 50 lines)

```bash
docker compose logs -n 50 obsvcealloy
docker compose logs -n 50 obsvcevm
docker compose logs -n 50 obsvcevlogs
docker compose logs -n 50 obsvcegrafana
```

### Datasource health checks (via Grafana API)

```bash
# requires GF admin creds
GP=$(docker exec servicehub-obsvcegrafana-1 printenv GF_SECURITY_ADMIN_PASSWORD)
GIP=$(docker inspect servicehub-obsvcegrafana-1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
curl -s -u "Captain.Li:$GP" http://$GIP:3000/api/datasources/proxy/uid/victoriametrics/api/v1/query?query=up
curl -s -u "Captain.Li:$GP" http://$GIP:3000/api/datasources/proxy/uid/victorialogs/select/logsql/query?query={project="servicehub"}'| stats count()'
```

### Dashboard provisioning verification

```bash
# Count provisioned dashboards via Grafana API
curl -s -u "Captain.Li:$GP" http://$GIP:3000/api/search | jq 'length'
# Should return 18 (8 first-party + 10 reference)
```

### Alert rule count verification

```bash
curl -s -u "Captain.Li:$GP" http://$GIP:3000/api/prometheus/grafana/api/v1/rules \
| jq '.data.groups[] | {name: .name, rules: .rules | length}'
# Should return 3 groups, 27 total rules
```

### Minimal service recreation

```bash
# Recreate Grafana only (provisioning changes)
docker compose up -d --no-deps --force-recreate obsvcegrafana

# Recreate Alloy only (config changes)
docker compose up -d --no-deps --force-recreate obsvcealloy

# Full observability stack restart (last resort)
docker compose up -d obsvcevm obsvcevlogs obsvcealloy obsvcegrafana obsvcegrafanainit
```

### Rollback principles

- Configuration is file-provisioned: revert the file, `docker compose up -d --force-recreate` the affected service.
- Telemetry data (VictoriaMetrics/VictoriaLogs volumes) is **never deleted** during rollback.
- No `docker compose down -v` — destroys persisted telemetry.

---

## Known limitations and deferred capabilities

| Limitation | Status | Rationale |
|------------|--------|-----------|
| **No notification contact point** | Intentional | Alert evaluation runs; delivery (email, webhook, PagerDuty, etc.) requires owner configuration. |
| **No independent external host watchdog** | Intentional | Platform self-monitors via `servicehub-alloy-critical`, `servicehub-scrape-failure`, `servicehub-victoriametrics-critical`, etc. An external watchdog would require separate infrastructure. |
| **OCI APM disabled** | Deferred | `OCI_APM_ENABLED=false` by default. Requires `OCI_APM_OTLP_ENDPOINT`, `OCI_APM_DATA_KEY`, and owner approval. Log export permanently disabled by policy. |
| **No trace backend** | Deferred | No Tempo/Jaeger provisioned. Traces Drilldown plugin disabled (`grafana-exploretraces-app`). |
| **Logs Drilldown disabled** | Documented limitation | `grafana-lokiexplore-app` is Loki-only; VictoriaLogs has no drilldown endpoint. Use **Explore** with VictoriaLogs datasource instead. |
| **Historical `_msg` placeholders retained** | Until retention expiry | Stage 5 message-field cutover fixed new records; pre-cutover records keep the `missing _msg field` placeholder until normal log retention expires. Telemetry must not be deleted to clean presentation artifacts. |
| **Per-container CPU throttling unavailable** | Not collected | cAdvisor `throttled_time`/`throttled_periods` metrics not scraped; cgroup v2 throttling not exposed via current Docker socket path. |
| **Per-container network identity unavailable** | Not collected | cAdvisor does not expose per-container network I/O by interface; only aggregate `container_network_*` available. |
| **Confluence JMX/exporter deferred** | Not implemented | No JMX exporter for Confluence; native metrics limited to HTTP readiness probe. |

---

## Related documents

- [Grafana Operations Guide](services/grafana.md) — access, datasources, provisioning, Explore/Drilldown
- [Dashboard Catalogue](observability-dashboards.md) — all 8 first-party + 10 reference dashboards
- [Metrics Catalogue](observability-metrics.md) — metric families, formulas, consumers
- [Logs Catalogue](observability-logs.md) — source matrix, display standard, queries
- [Alert Catalogue](observability-alerts.md) — all 27 rules, NoData artifacts
- [Owner Review Checklist](observability-owner-review.md) — reusable acceptance checklist
