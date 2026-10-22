# Dashboard Catalogue

> All 8 first-party ServiceHub dashboards + 10 reference dashboards provisioned via Grafana file provider.

---

## First-party dashboards (8)

### 1. ServiceHub Overview
- **UID**: `servicehub-overview`
- **Title**: ServiceHub Overview
- **Purpose**: First operational landing page. Summarizes host, service, ingress, container, auth, observability, and warning/error state. Directs deeper investigation.
- **Intended audience**: On-call, platform operators
- **Primary datasources**: VictoriaMetrics (metrics), VictoriaLogs (logs)
- **Variables**: None
- **Significant panels**:
  - Host CPU used (stat), Host memory used (stat), Filesystem capacity (stat)
  - Service readiness (stat) — internal probe success
  - Pressure-stall information (timeseries) — CPU/Memory/I/O wait rates
  - HTTP traffic and errors (timeseries) — request rate, 5xx rate
  - Container restarts and OOM (timeseries) — 15m window
  - Authentication and authorization failures (timeseries)
  - Observability pipeline health (timeseries) — remote-write, scrape health
  - Recent warning and error logs (logs) — `level:~"warn\|warning\|error\|critical"`
- **Normal/healthy interpretation**: All stat panels green; PSI near 0; readiness = 1; restarts/OOM = 0; auth failures = 0; pipeline health = 1; warning/error log panel empty or low volume.
- **Known valid empty states**: Warning/error log panel empty = healthy. Service readiness stat = 1 for all 8 services.
- **Limitations**: 15m fixed window on restarts/OOM panel (documented in panel). PSI description uses "rate" not "counter" (Stage 7 correction).
- **Related drill-down**: Click through to Infrastructure (host), Applications (services), Traffic and Edge (ingress), Docker and Containers (containers), Observability Health (telemetry), Security (auth failures).

### 2. ServiceHub Applications
- **UID**: `servicehub-applications`
- **Title**: ServiceHub Applications
- **Purpose**: Service-centric correlation of readiness, requests, errors, latency, container resources, task queue, and application logs. Supports one/multiple/All service filtering across the eight bounded logical services.
- **Intended audience**: Application owners, on-call
- **Primary datasources**: VictoriaMetrics, VictoriaLogs
- **Variables**: `service` (query: `label_values(probe_success{probe_type="readiness"}, logical_service)`) — multi-select, include All
- **Significant panels**:
  - Application readiness (stat) — per-service probe success
  - Requests and errors (timeseries) — Traefik request rate by service, 5xx overlay
  - Request latency (timeseries) — p50/p95/p99 from Traefik buckets
  - Container CPU (timeseries) — per-service container CPU
  - Container memory (timeseries) — usage vs limit
  - Authentik task queue (Authentik only) — `authentik_task_queue_size` (only populated for Authentik)
  - Application logs (logs) — filtered by selected `logical_service`
- **Normal/healthy interpretation**: Readiness = 1 per selected service; latency p95 < 300ms; CPU < 70%; memory < 80% limit; task queue stable; logs show INFO/WARN only.
- **Authentik queue limitation**: Only Authentik exposes a task queue metric. Panel shows N/A for other services — expected.
- **Known valid empty states**: Queue panel empty for non-Authentik services.
- **Limitations**: Latency panel 5s plateau artefact documented (quantile interpolation cannot exceed highest finite bucket). Log panel shows Time|Level|Service|Message.
- **Related drill-down**: Traffic and Edge for ingress detail, Docker and Containers for container detail.

### 3. ServiceHub Infrastructure
- **UID**: `servicehub-infrastructure`
- **Title**: ServiceHub Infrastructure
- **Purpose**: Host resource and saturation analysis (node-exporter only).
- **Intended audience**: Platform operators, capacity planning
- **Primary datasources**: VictoriaMetrics
- **Variables**: None
- **Summary row (Node Exporter-style, y=0, h=5, width=4 each)**:
  - **Pressure** (bargauge, id=20): CPU/Memory/I/O PSI "some" stall % (5m rate). Thresholds: yellow ≥20%, red ≥90%.
  - **CPU Busy** (gauge, id=21): 100 × (1 − avg idle-rate over 5m). Thresholds: yellow ≥70%, red ≥85%.
  - **System Load** (gauge, id=22): 100 × node_load1 / CPU cores. Max 200. Thresholds: yellow ≥70%, red ≥100%.
  - **RAM Usage** (gauge, id=23): 100 × (1 − MemAvailable/MemTotal). Thresholds: yellow ≥70%, red ≥85%.
  - **Swap Used** (gauge, id=24): 100 × (SwapTotal−SwapFree) / clamp_min(SwapTotal,1) AND SwapTotal>0. `noValue: "Not configured"`. Thresholds: yellow ≥25%, red ≥60%.
  - **Uptime** (stat, id=25): `node_time_seconds − node_boot_time_seconds`, unit `dtdurations`, green-only.
- **Detailed panels (3 rows)**:
  - Row y=5: CPU utilization (by mode), Memory composition (7 series), Load average (1m/5m/15m + 1m/core + cores)
  - Row y=13: PSI detail, Filesystem capacity, Inode utilization
  - Row y=21: Disk I/O (throughput, IOPS, I/O time, weighted I/O), Network (throughput + errors), Read-only mounts (boolean rw/ro)
- **Normal/healthy interpretation**: Summary row all green; detailed panels show stable baselines; no read-only mounts.
- **Key formulas explained**:
  - System Load is normalized against CPU count (100% = 1m load equals core count).
  - Swap Used returns **no series** (renders "Not configured") when swap is disabled — distinguishes disabled swap from configured 0% usage.
  - Uptime is informational; a recent reboot is not an alarm by itself (correlate with restart/OOM on Overview).
  - Display thresholds are **not** automatically alert policy (separate alert rules exist for pressure, filesystem, inodes).
- **Known valid empty states**: Swap Used = "Not configured" when no swap partition. Read-only mounts panel shows all 0 (rw).
- **Limitations**: No hardware sensors (temps, fans, power, NTP, entropy) — collectors disabled/absent.
- **Related drill-down**: Overview for high-level, Alerts for pressure/filesystem/inode alerts.

### 4. ServiceHub Docker and Containers
- **UID**: `servicehub-docker-containers`
- **Title**: ServiceHub Docker and Containers
- **Purpose**: Container current state, CPU, memory, disk I/O, age, restart/OOM, and logs.
- **Intended audience**: Platform operators, developers
- **Primary datasources**: VictoriaMetrics, VictoriaLogs
- **Variables**: `container` (query: `label_values(container_last_seen{name=~"servicehub-.*"}, name)`) — multi-select, include All
- **Significant panels**:
  - Container running (stat) — `< bool 90` fix (Stage 7), value mapping 1/0
  - CPU usage (timeseries) — per-container
  - Memory and limits (timeseries) — usage + limit
  - Container disk I/O (timeseries) — read/write bytes
  - Container age (stat) — `colorMode: none` (informational)
  - Restart and OOM indicators (timeseries) — 15m window
  - Container logs (logs) — filtered by selected container
- **Runtime Limitations row** (text panels):
  - CPU throttling: metric not collected
  - Container network: per-interface identity not available
- **Known valid empty states**: OOM/restart panels flat at 0 = healthy.
- **Limitations**: Throttling/network identity documented as unavailable.

### 5. ServiceHub Database
- **UID**: `servicehub-database`
- **Title**: ServiceHub Database
- **Purpose**: PostgreSQL availability, connections, transactions, locks, long-running activity, database size, cache, temporary bytes, WAL, and supported collectors.
- **Intended audience**: Database operators, platform operators
- **Primary datasources**: VictoriaMetrics
- **Variables**: None
- **Significant panels**:
  - PostgreSQL availability (stat) — `pg_up`
  - Connections (timeseries) — active, idle, max
  - Transactions (timeseries) — commit/rollback rate
  - Locks and deadlocks (timeseries)
  - Long-running transactions (timeseries)
  - Database size (timeseries)
  - Cache hit ratio (timeseries) — 0–100% axis
  - Temporary bytes and WAL size (timeseries) — bytes axis
- **Valid empty/not-applicable states**: Replication panels empty (no replica configured) — expected.

### 6. ServiceHub Traffic and Edge
- **UID**: `servicehub-traffic-edge`
- **Title**: ServiceHub Traffic and Edge
- **Purpose**: Traefik request rates, codes, latency, Apdex/SLO, payload throughput, entrypoints, services, connections, reloads, TLS, access logs, clients, and countries.
- **Intended audience**: Platform operators, security, capacity planning
- **Primary datasources**: VictoriaMetrics (metrics), VictoriaLogs (access logs + GeoIP)
- **Variables**: None
- **Significant panels**:
  - Request rate by service (timeseries)
  - HTTP status codes incl. websocket 0 (timeseries) — `code="0"` = websocket upgrade, not error
  - Response latency (timeseries) — p50/p95/p99 from `traefik_service_request_duration_seconds_bucket`
  - Service errors (timeseries) — 4xx/5xx rate
  - TLS endpoint state (timeseries) — blackbox probe TLS
  - **Latency and SLO row**:
    - Apdex score (stat) — satisfied (≤0.3s) + tolerating (≤1.2s)/2 / total
    - Top slow services (timeseries) — p95 per service
    - Services failing SLO 300ms (timeseries) — violation ratio = 1 − (≤0.3s / all)
    - Services failing SLO 1200ms (timeseries) — violation ratio = 1 − (≤1.2s / all)
  - **Ten-minute HTTP outcomes row** (intentional fixed 10m window, `increase()`):
    - 2xx requests, 5xx requests, Non-2xx/non-5xx (stat)
  - Request/response body throughput (timeseries) — B/s
  - Request rate by entrypoint (timeseries)
  - Open connections by entrypoint (timeseries)
  - Config reloads, last hour (stat) — fixed 1h window
  - TLS certificate expiry, Traefik source (stat)
  - **GeoIP panels** (VictoriaLogs):
    - Top 10 Countries by Traffic (bargauge)
    - Traefik access logs (logs) — structured fields: method, host, status, duration; path/query omitted
    - Client IP Distribution, Geographic Distribution (piecharts/bargauges)
    - Country traffic trend (timeseries) — formerly "Countries, last 6 hours"
- **Native metrics vs VictoriaLogs**: Metrics panels use Traefik Prometheus endpoint; GeoIP/client/country/access-log panels use VictoriaLogs.
- **Apdex formula**: Uses live bucket boundaries 0.1/0.3/1.2/5.0/+Inf; no interpolation needed. Display thresholds: Good ≥0.94, Needs attention 0.85–0.94, Poor <0.85 (proposed defaults, not policy).
- **Intentional fixed windows**: 10m HTTP outcomes (panels 25–27), 1h config reloads (panel 19), 15m restart/OOM on Overview — descriptions state "ignores dashboard time range".
- **Dashboard-range panels**: All others follow time picker.
- **Access-log path/query privacy**: Deliberately omitted — LogSQL cannot strip query parameters.
- **Known valid empty states**: GeoIP panels empty until traffic arrives; access-log panel shows placeholder `missing _msg field` (Traefik JSON has no `_msg` — documented limitation).
- **Limitations**: `code="0"` is websocket, not error. SLO violation ratios are display ratios, not alert policy.

### 7. ServiceHub Security
- **UID**: `servicehub-security`
- **Title**: ServiceHub Security
- **Purpose**: Focused operational security signals, not a SIEM.
- **Intended audience**: Security operators, on-call
- **Primary datasources**: VictoriaMetrics (Traefik status codes), VictoriaLogs (journal + app logs)
- **Variables**: None
- **Significant panels**:
  - SSH and sudo journal (logs) — journal `sshd`/`sudo` matches
  - Traefik 401/403/404/429 (timeseries)
  - Authentik failures (logs) — `logical_service="authentik" level~"warn|error"`
  - Forgejo failures (logs) — `logical_service="forgejo" level~"warn|error"`
  - Top 5 Countries by Traffic (bargauge) — GeoIP
  - Total Unique Countries (stat)
  - Top 5 Public Client IPs (piechart)
  - Recent security logs (logs) — security component journals + app failures
  - Edge Security Summary (row) — textual summary
- **Honest Forgejo empty state**: Forgejo may not produce structured failure logs — panel empty = not necessarily healthy, documented.
- **Known valid empty states**: Auth/Forgejo failure log panels empty = no failures.

### 8. ServiceHub Observability Health
- **UID**: `servicehub-observability-health`
- **Title**: ServiceHub Observability Health
- **Purpose**: Health of collection, storage, scrape, remote write, ingestion, alert evaluation, and known coverage gaps.
- **Intended audience**: Platform operators
- **Primary datasources**: VictoriaMetrics, VictoriaLogs
- **Variables**: None
- **Significant panels**:
  - Collector and store readiness (stat) — probe_success for VM, VLogs, Grafana, Alloy
  - Remote-write health (timeseries) — `prometheus_remote_storage_samples_failed_total`
  - Scrape health (stat) — `up` for all scrape jobs
  - Storage capacity (timeseries) — VM/VLogs disk usage
  - Observability logs (logs) — Alloy, VM, VLogs, Grafana logs
  - Recent log ingestion (timeseries) — log volume over time
  - Live alert evaluation (alertlist) — firing/pending/no-data only
  - Notification and watchdog coverage (text) — documents: evaluation enabled, delivery not configured, external watchdog not configured
- **Alert evaluation vs notification vs watchdog**: Clearly distinguished in text panel.

---

## Reference dashboards (10)

| File | Source UID | Source | Classification | Notes |
|------|------------|--------|----------------|-------|
| `1860_node-exporter-full.json` | `rYdddlPWk` | grafana.com/1860 | **REFERENCE ONLY** | Host-oriented; only CPU/memory/load/disk/network patterns adopted into ServiceHub Infrastructure |
| `21743_docker-containers-overview.json` | `ae3c41d7-cea5-4cca-a918-5708706b4d1a` | grafana.com/21743 | **REFERENCE ONLY** | cAdvisor presentation concepts; ServiceHub Docker already uses correct identity |
| `19792_cadvisor-dashboard.json` | `9AJV_mnIk` | grafana.com/19792 | **REFERENCE ONLY** | Layout concepts only |
| `14282_cadvisor-explorter.json` | `pMEd7m0Mz` | grafana.com/14282 | **REFERENCE ONLY** | Explorer layout concepts |
| `19724_docker-dashboard.json` | `bc96dd35-dc52-4ae0-a77e-01c9e04e00cb` | grafana.com/19724 | **REFERENCE ONLY** | Docker overview concepts |
| `n5bu_kv45` / `17346_traefik-dashboard.json` | `n5bu_kv45` | grafana.com/17346 | **ADOPT/ADAPT SELECTIVELY** | See Traffic and Edge classification |
| `16152_traefik-observability-dashboard.json` | `traefik-full-obs` | grafana.com/16152 | **ADOPT/ADAPT SELECTIVELY** | See Traffic and Edge classification |
| `16151_victoriametric-overview.json` | `vm-overview` | grafana.com/16151 | **REFERENCE ONLY** | VM self-monitoring |
| `22759-victorialogs-explorer.json` | `bdpzp3w3jkt8ga` | grafana.com/22759 | **REFERENCE ONLY** | VLogs exploration |
| `24585-victorialogs-internal-state.json` | `be5zidev_vlogs` | grafana.com/24585 | **REFERENCE ONLY** | VLogs internal state |

**Authoritative status**: Reference-only. Not maintained for ServiceHub operations. Selective patterns adopted into first-party dashboards as documented in [grafana.md](services/grafana.md#node-exporter-full-1860--candidate-classification) and [Traefik classification](services/grafana.md#traefik-official-standalone--candidate-classification).

**Datasource requirements**: Reference dashboards may reference datasources not provisioned (Prometheus, Loki, Tempo). They will show "No data" or errors in this environment.

---

## Cross-dashboard conventions

- **Log panel display standard** (all first-party): `Time | Level | Service/Container | Message`
- **Fixed-window panels**: Clearly titled (e.g., "last 10m", "last 1h", "last 15m") and descriptions state "ignores the dashboard time range".
- **Dashboard-range panels**: Follow the time picker.
- **Variables**: Only Applications and Docker and Containers have variables (multi-select with "All").
- **Healthy empty states**: Documented per-dashboard above.
- **Known limitations**: Documented per-dashboard above.

---

## Total inventory

- **First-party ServiceHub dashboards**: 8
- **Reference dashboards**: 10
- **Total provisioned**: 18
