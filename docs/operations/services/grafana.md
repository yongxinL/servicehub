# Grafana — ServiceHub

> Dashboards for visualizing metrics and logs.

## Overview

[Grafana](https://grafana.com/) is the visualization layer of the observability stack (`obsvce`). It reads metrics from [VictoriaMetrics](victoriametrics.md) and logs from [VictoriaLogs](victorialogs.md). The `obsvcegrafana` service is defined in [`compose/obsvce.yml`](../../../compose/obsvce.yml) and built from [`shared/grafana/Dockerfile`](../../../shared/grafana/Dockerfile) (`FROM grafana/grafana:latest`). A one-shot `obsvcegrafanainit` container fixes data-directory ownership before Grafana starts.

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcegrafana` (+ one-shot `obsvcegrafanainit`) |
| URL | `https://${OBSERVABILITY_DOMAIN}` |
| Internal port | 3000 |
| Database | SQLite (embedded, persisted to `${APPS_DATA}/obsvce/grafana`) |
| Data sources | VictoriaMetrics (`obsvcevm:8428`), VictoriaLogs (`obsvcevlogs:9428`) |
| Auth | Built-in Grafana auth + Traefik `grafana-allowlist@file` middleware (`TRUSTED_IP` only) |
| Plugin | `victoriametrics-logs-datasource` |
| Drilldown plugins | **Enabled:** Metrics Drilldown (`grafana-metricsdrilldown-app`); **Disabled:** Logs Drilldown (`grafana-lokiexplore-app`), Traces Drilldown (`grafana-exploretraces-app`) |
| Depends on | `routetraefik`, `obsvcegrafanainit`, `obsvcealloy` |

## Configuration

Set in `.env` (see [`env.example`](../../../env.example)):

| Variable | Description |
|---|---|
| `OBSERVABILITY_DOMAIN` | Grafana hostname (e.g. `stats.example.com`) |
| `OBSERVABILITY_ADMIN_USER` | Grafana admin username |
| `OBSERVABILITY_ADMIN_PASSWORD` | Grafana admin password |

Grafana settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` | `${OBSERVABILITY_ADMIN_USER}` / `${OBSERVABILITY_ADMIN_PASSWORD}` | Local admin account |
| `GF_SERVER_DOMAIN` / `GF_SERVER_ROOT_URL` | `${OBSERVABILITY_DOMAIN}` | Correct URLs behind Traefik |
| `GF_USERS_ALLOW_SIGN_UP` | `false` | No self-registration |
| `GF_INSTALL_PLUGINS` | `victoriametrics-logs-datasource` | Logs datasource |
| `GF_PLUGINS_DISABLE_PLUGINS` | `grafana-lokiexplore-app,grafana-exploretraces-app` | Hide incompatible Drilldown apps |

## Provisioning

Both provisioning files are mounted read-only from [`provisioning/`](../../../shared/grafana/provisioning):

| File | Purpose |
|---|---|
| [`provisioning/datasources/datasources.yml`](../../../shared/grafana/provisioning/datasources/datasources.yml) | VictoriaMetrics (default) and VictoriaLogs data sources |
| [`provisioning/dashboards/dashboards.yml`](../../../shared/grafana/provisioning/dashboards/dashboards.yml) | Loads dashboards from `/var/lib/grafana/dashboards` |

Pre-built dashboards in [`dashboards/`](../../../shared/grafana/dashboards) are mounted at `/var/lib/grafana/dashboards/observability` and include:

- **First-party ServiceHub dashboards (8):** Overview, Infrastructure, Traffic and Edge, Docker and Containers, Applications, Database, Observability Health, Security
- **Reference dashboards (10):** Node Exporter Full, cAdvisor Explorer/Dashboard, Docker Dashboard/Containers Overview, Traefik Full Observability/Official Standalone, VictoriaMetrics Overview, VictoriaLogs Explorer/Internal State

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/lib/grafana` | `${APPS_DATA}/obsvce/grafana` | SQLite database, users, settings, local dashboard edits |

`obsvcegrafanainit` runs as root and normalizes ownership to UID/GID `472` (the Grafana user) and permissions to `775` on every boot, so the bind mount stays writable.

## Operations

```bash
# Start / restart
docker compose up -d obsvcegrafana

# Follow logs
docker compose logs -f obsvcegrafana

# Re-run the ownership fix
docker compose up obsvcegrafanainit
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../../shared/grafana/Dockerfile) | Image build (`FROM grafana/grafana:latest`) |
| [`provisioning/`](../../../shared/grafana/provisioning) | Data source and dashboard provisioning |
| [`dashboards/`](../../../shared/grafana/dashboards) | Pre-built dashboard JSON |
| [`alloy/`](../../../shared/grafana/alloy) | Grafana Alloy collector — see [alloy/README.md](../../../shared/grafana/alloy/README.md) |
| [`geoip/`](../../../shared/grafana/geoip) | GeoIP database used by Alloy log enrichment |

## Dashboard architecture and Stage 6/7 decisions

### First-party dashboards

| UID / File | Title | Purpose | Stage 7 changes |
|---|---|---|---|
| `servicehub-overview` | ServiceHub Overview | Executive landing page: host, apps, ingress, containers, telemetry health. Not a troubleshooting surface. | Renamed `Host CPU` → **Host CPU used**, `Host memory` → **Host memory used**; PSI and restart/OOM descriptions made explicit; log panels now show message body |
| `servicehub-infrastructure` | ServiceHub Infrastructure | Host Linux saturation analysis (node-exporter only) | Read-only state split out of the percent-capacity axis into its own **Read-only mounts** panel; disk queries filter `sr0`/loop/ram/fd; PSI description corrected (rate, not counter); uptime stat color set to neutral (`colorMode: none`) |
| `servicehub-traffic-edge` | ServiceHub Traffic and Edge | Traefik ingress performance, SLO, TLS, connections, access logs, GeoIP | **New rows:** Latency and SLO (Apdex, top slow services, 300 ms and 1200 ms violation ratios) and Ten-minute HTTP outcomes + payload size (2xx/5xx/other, request/response throughput). TLS state separated from certificate expiry. Status panel documents `code=0` as websocket. Grid restructured. |
| `servicehub-docker-containers` | ServiceHub Docker and Containers | Container runtime troubleshooting (cAdvisor) | **Bug fix:** `Container state` → **Container running** — the query used a bare `<` comparison, which in PromQL is a *filter*, so the card showed elapsed seconds (≈27.4) instead of a state. Now uses `< bool 90` with a 1/0 value mapping. Container age `colorMode: none` (informational, not an alarm) |
| `servicehub-applications` | ServiceHub Applications | Service-centric cross-signal investigation | Latency panel documents the 5 s plateau artefact (quantile interpolation cannot exceed the highest finite bucket) |
| `servicehub-database` | ServiceHub Database | PostgreSQL availability and workload | **Split** `Cache, temp, and WAL` into **Cache hit ratio** (percent axis, 0–100) and **Temporary bytes and WAL size** (bytes). A ratio was previously plotted on a bytes axis |
| `servicehub-observability-health` | ServiceHub Observability Health | Telemetry pipeline health and monitoring gaps | Remote-write legends changed from opaque component hashes (`c35da8`) to meaningful names; alertlist description states it shows firing/pending/no-data only |
| `servicehub-security` | ServiceHub Security | Concise security-relevant operational summary | Regression validation only; log panels now show message body |

### Log panel display standard (Stage 8, correcting Stage 7)

Every first-party log panel shows, at minimum:

```text
Timestamp | Level | Service or container | Message
```

**Frame contract (verified live in Stage 8).** The VictoriaLogs datasource returns every frame as
`Time | Line | id | labels | streams | streamId`. Non-promoted fields (for example `level`,
`container_name`, `logical_service`, `RequestMethod`, `Duration`) live inside the packed JSON
`labels` column, which the Logs visualization renders as field chips.

**The Stage 7 `| fields` clause was wrong and has been removed.** A trailing
`| fields _msg, level, container_name, logical_service` that omits `_time` destroys the frame's
`Time` column (it becomes `-6795364578872`, rendered as 1754-08-31) and, because these streams
promote their real message into `_msg` only at the stream level, returns the literal placeholder
`missing _msg field; see docs.victoriametrics.com/...#message-field` as the `Line` body. Stage 7's
claim that this clause "promotes the message body into the frame's `Line` field" was refuted by
direct frame inspection in Stage 8.

**Implementation (Stage 8).** Log panels query the plain stream selector with no trailing
projection — `{project="servicehub",...}` — or, when filtering is needed, use `| filter`
clauses only. The datasource then returns the real event time and the ingested line as `Line`.
Panels that want a reduced column set (Traefik access logs) must include `_time` in the
`| fields` list to keep the `Time` column intact.

**Traefik access-log caveat (Stage 7 decision retained).** Traefik ingests its JSON line
verbatim and legitimately has no `_msg`, so its `Line` renders the `missing _msg field`
placeholder; its structured fields (method, host, status, duration) are shown via
`displayedFields` chips. Request path and query strings remain deliberately excluded:
LogSQL on this datasource cannot strip query parameters, so the path column is omitted
rather than shown unsanitized.

**Level filters (Stage 8).** The corpus contains `warn`, `warning`, `error`, and `critical`
as distinct level values (plus sources with no level at all). Warning/error panels filter
`level:~"warn|warning|error|critical"` so real `warning`- and `critical`-classified records
are not silently dropped, as the earlier two-term `error|warn` filter did.

**Levels.** `level` is only present for structured sources. Grafana and plain-text sources
legitimately show no level rather than a fabricated `UNK` class.

### Traefik SLO panel semantics (Stage 7)

Apdex and SLO panels use `traefik_service_request_duration_seconds_bucket`, whose live bucket boundaries are exactly `0.1`, `0.3`, `1.2`, `5.0`, `+Inf` — so the owner-requested thresholds map onto real buckets without interpolation.

```text
Satisfied  = rate(bucket{le="0.3"})
Tolerating = rate(bucket{le="1.2"}) - Satisfied
Total      = rate(bucket{le="+Inf"})

Apdex = (Satisfied + Tolerating / 2) / Total
```

**PromQL caveat (verified against the live endpoint).** The `le` label survives the `rate()` and therefore the selector, so dividing `rate(bucket{le="0.3"}) / rate(bucket{le="+Inf"})` in place yields an **empty result** — the two sides never match on `le`. Each ratio must be aggregated away from `le` *before* the binary operation:

```promql
sum by (logical_service) (rate(...{le="0.3"}[5m]))
  / sum by (logical_service) (rate(...{le="+Inf"}[5m]))
```

**Display thresholds.** Good ≥ 0.94, Needs attention 0.85–0.94, Poor < 0.85. These are proposed operational defaults, **not** owner-approved SLO policy.

| Panel | Semantics | Metric |
|---|---|---|
| Apdex score | Score over 0–1 from the formula above | `traefik_service_request_duration_seconds_bucket` |
| Top slow services | p95 latency per `logical_service` | same bucket metric via `histogram_quantile` |
| Services failing SLO 300ms | Violation **ratio** = 1 − (≤0.3 s / all) | same bucket metric |
| Services failing SLO 1200ms | Violation **ratio** = 1 − (≤1.2 s / all) | same bucket metric |
| 2xx / 5xx / non-2xx-non-5xx, last 10m | `increase()` over 10m, unit *requests* | `traefik_service_requests_total` |
| Request / response body throughput | `rate()` of byte counters, unit *B/s* | `traefik_service_requests_bytes_total`, `traefik_service_responses_bytes_total` |
| Open connections by entrypoint | Count gauge, distinct from request rate | `traefik_open_connections` |

**`code="0"` is not an HTTP error.** Live series inspection shows `code="0"` occurs exclusively with `protocol="websocket"` — websocket upgrades have no HTTP response status. It is neither success nor error and is labelled as such.

### Stage 8 decisions summary

| Workstream | Decision |
|---|---|
| **A — Log rendering** | Removed the destructive `| fields _msg, level, container_name, logical_service` clause from all first-party log panels. The clause (without `_time`) produced `Time = 1754-08-31` and `Line = "missing _msg field"`. Plain stream selectors now return correct `Time` and real message text. Traefik rows in Docker/Applications logs show the placeholder — documented limitation, not an ingestion defect. |
| **B — Infrastructure summary** | Replaced the six stat cards with a Node Exporter-style compact row at y=0, h=5, width 4 each: Pressure (`bargauge`, CPU/Memory/I/O bars), CPU Busy, System Load (max 200), RAM Usage and Swap Used (`gauge` radial), Uptime (`stat`, `dtdurations`, green-only). Detail panels re-balanced into three rows (CPU/Memory/Load at y=5, Pressure/FS/Inodes at y=13, Disk I/O/Network/Read-only at y=21). Removed the bottom-isolated full-size Uptime panel and the pre-existing grid overlap (Inode utilization vs Read-only mounts both at x=16,y=8). Swap Used guards zero-swap with `... and (SwapTotal > 0)` plus `clamp_min(SwapTotal, 1)`; the series disappears when swap is disabled and `noValue` renders "Not configured". Root cause of the old `97508966400%`: VictoriaMetrics treats a non-`bool` comparison (`SwapTotal > 0`) as a *filter*, returning the raw byte value rather than `1`, so multiplying the percentage by it produced the byte count as a percent. |
| **C — Time-range semantics** | Four traffic-edge Top-N/distribution panels had unjustified `timeFrom` overrides (5m, 1h, 1h, 6h) — removed; panels now follow dashboard range. Retitled `Countries, last 6 hours` → `Country traffic trend`. Intentional fixed windows (10m HTTP outcomes 25–27, 1h config reloads 19, 15m restart/OOM on Overview) keep their window in the expr and descriptions state "ignores the dashboard time range". |
| **D — Access-log timestamps** | Traefik access-log panel (traffic-edge id=7) now includes `_time` in its `| fields` list. Frame inspection confirms `Time` = 2026-10-22 across 15m/6h/24h ranges. `Duration` remains a nanosecond string in `labels`; the panel shows it via `displayedFields`. |
| **E — Alert NoData** | `servicehub-fs-readonly`: changed `node_filesystem_readonly{...} == 1` (PromQL filter → empty vector when all rw) to `max(node_filesystem_readonly{...})` (raw metric, value 0 when healthy) with condition threshold > 0.5. `servicehub-traefik-5xx`: split numerator and denominator into separate queries A/B, ratio computed in expression `A / clamp_min(B, 1)`, so an empty 5xx series yields 0 ratio → Normal, not NoData. Rule UIDs unchanged. |

### No additional dashboards (Workstream K)

Decision: **no new first-party dashboards.** The eight existing dashboards cover overview, applications, host infrastructure, containers, PostgreSQL, traffic/edge, security, and observability health. Traefik SLO panels live in Traffic and Edge; logs stay inside the relevant operational dashboards and Explore; reference dashboards remain references. A future tracing/service-dependency dashboard is deferred until such a backend exists.

### Reference dashboards (kept in `dashboards/reference/`)

| File | Source | Classification | Notes |
|---|---|---|---|
| `1860_node-exporter-full.json` | grafana.com/1860 | **KEEP IN REFERENCE ONLY** | Host-oriented; only CPU/memory/load/disk/network patterns adopted into ServiceHub Infrastructure. Do not mix host metrics into container dashboards. |
| `21743_docker-containers-overview.json` / `19792_cadvisor-dashboard.json` / `14282_cadvisor-explorter.json` | grafana.com | **KEEP IN REFERENCE ONLY** | cAdvisor presentation/layout concepts noted; ServiceHub Docker and Containers already uses correct identity (`name`/`compose_service`). |
| `n5bu_kv45` / `17346_traefik-dashboard.json` / `16152_traefik-observability-dashboard.json` | grafana.com | **ADOPT/ADAPT selectively** | See Traefik classification below. |

### Node Exporter Full (1860) — candidate classification

| Panel family | Decision | Target ServiceHub dashboard | Rationale |
|---|---|---|---|
| CPU utilization by mode | **ADOPT** | Infrastructure | Already present as "CPU utilization" |
| Load averages (1m/5m/15m) | **ADOPT** | Infrastructure | Enhanced with 1m/CPU count and CPU cores |
| Memory composition | **ADOPT** | Infrastructure | Expanded to 7-series breakdown (Used, Cached, Buffers, SReclaimable, Available, Swap used, Swap total) |
| Swap usage/activity | **ADOPT** | Infrastructure | Included in Memory composition |
| Filesystem capacity & inodes | **ADOPT** | Infrastructure | Already present |
| Disk throughput / IOPS / I/O time / weighted I/O | **ADOPT** | Infrastructure | All added to Disk I/O panel |
| Network throughput & errors | **ADOPT** | Infrastructure | Errors added to Network panel |
| PSI (CPU/memory/IO wait) | **ADOPT** | Infrastructure | Already present |
| System uptime | **ADOPT** | Infrastructure | Already present |
| Hardware temps, fans, power, NTP/PPS, entropy, etc. | **REJECT** | — | Collectors disabled/absent; not operationally useful |
| Virtual filesystems / duplicate mounts | **REJECT** | — | Stage 1 already excludes |

### Traefik Official Standalone — candidate classification

| Panel family | Decision | Target ServiceHub dashboard | Rationale |
|---|---|---|---|
| Request rate by entrypoint | **ADOPT** | Traffic and Edge | Added (panel 17) |
| Request rate by service/backend | **ADAPT** | Traffic and Edge | Already covered by "Request rate by service" (panel 1) |
| Status-code classes (2xx/3xx/4xx/5xx) | **ADAPT** | Traffic and Edge | Already covered by "HTTP status distribution" (panel 2) — legends deliberate |
| 4xx/5xx rate over time | **REJECT** | — | Duplicates "Service errors" (panel 4) |
| Latency p50/p90/p95/p99 | **ADAPT** | Traffic and Edge | Already in "Response latency" (panel 3, p50/p95/p99) |
| Open connections by entrypoint | **ADOPT** | Traffic and Edge | Added (panel 18) |
| Config reload success/last | **ADOPT** | Traffic and Edge | Added (panel 19) |
| TLS cert expiry (Traefik source) | **ADOPT** | Traffic and Edge | Added (panel 20); blackbox probe TLS panel remains (panel 5) — no duplicate |
| Apdex score | **ADOPT** | Traffic and Edge | Added (panel 21); buckets 0.3/1.2 s verified live |
| Top slow services (p95) | **ADOPT** | Traffic and Edge | Added (panel 22) |
| SLO violation ratios 300 ms / 1200 ms | **ADOPT** | Traffic and Edge | Added (panels 23, 24); separate thresholds per owner request |
| 10m HTTP outcomes (2xx/5xx/other) | **ADOPT** | Traffic and Edge | Added (panels 25–27) |
| Request/response byte throughput | **ADOPT** | Traffic and Edge | Added (panels 28, 29); `traefik_service_requests_bytes_total` / `_responses_bytes_total` verified live |
| Top services/backends | **REJECT** | — | "Request rate by service" exists; bounded by `logical_service` |
| Router/service health | **REJECT** | — | Metric not available |

### Drilldown investigation results

#### Metrics Drilldown (`grafana-metricsdrilldown-app` v3.0.0)

- **Status:** **Compatible, enabled**
- **Datasource:** VictoriaMetrics (`prometheus` type, UID `victoriametrics`)
- **Discovery APIs verified (200 via Grafana proxy):**
  - `/api/v1/label/__name__/values` — 1055 metric names
  - `/api/v1/status/tsdb` — TSDB status
  - `/api/v1/metadata` — metric metadata
  - `/api/v1/query`, `/api/v1/query_range` — query execution
- **Plugin logic:** Checks `datasource.type === "prometheus"` OR regex `/^grafana-[0-9a-z]+prometheus-datasource$/`. VictoriaMetrics datasource type is `prometheus` → passes.
- **Page bootstrap:** `defaultDatasource: "VictoriaMetrics"`
- **Action:** No provisioning change needed; kept enabled.

#### Logs Drilldown (`grafana-lokiexplore-app` v3.0.0)

- **Status:** **Incompatible — documented limitation**
- **Datasource support:** Plugin module code only references `loki` type (grep for `victoriametrics-logs` returns 0). No VictoriaLogs discovery API support.
- **VictoriaLogs `drilldown-limits` endpoint:** Returns generic "Hello from VM data source!" (not a real drilldown endpoint).
- **Supported workflow:** Use **Explore** with VictoriaLogs datasource for ad-hoc log queries (works correctly).
- **Action:** Disabled via `GF_PLUGINS_DISABLE_PLUGINS=grafana-lokiexplore-app` to avoid presenting a broken UI. Explore remains fully functional.

#### Traces Drilldown (`grafana-exploretraces-app` v3.0.0)

- **Status:** **Unavailable — no tracing backend**
- **Current state:** No Tempo datasource exists; OCI APM disabled pending connection configuration and owner approval.
- **Error:** UI previously showed "Datasource was not found" (stale reference).
- **Investigation:** No stale Tempo datasource references found in provisioning (`datasources.yml`, dashboards, Alloy config). Page loads 200 but cannot query.
- **Action:** Disabled via `GF_PLUGINS_DISABLE_PLUGINS=grafana-exploretraces-app`. Documented as deferred. No fake Tempo datasource provisioned.

#### Explore (VictoriaMetrics / VictoriaLogs)

- **Status:** **Verified working**
- **Metrics:** `up`, label/series discovery, instant/range queries all return 200
- **Logs:** LogSQL queries via VictoriaLogs proxy return correct results
- **Regression:** None

### OCI APM

**Status:** Disabled. No tracing backend configured. Connection endpoint/key not provided. Owner approval required before activation. This stage makes no changes to OCI state.

### Security controls verified

- Grafana ingress: `TRUSTED_IP` allowlist only (`grafana-allowlist@file` middleware)
- No `GRAFANA_ALLOWED_CIDRS` configured
- Built-in Grafana auth (`GF_SECURITY_ADMIN_USER/PASSWORD`)
- No Authentik forward-auth on Grafana (correctly removed in Stage 5)
- `.env` not committed, not staged
- No secrets in repo
- No package/browser artifacts staged

## See also

- [VictoriaMetrics](victoriametrics.md) — metrics data source
- [VictoriaLogs](victorialogs.md) — logs data source
- [Grafana Alloy](../../../shared/grafana/alloy/README.md) — collector
- [Authentik](authentik.md) — forward-auth
- [Root README — Observability](../../../README.md#observability-stack-obsvce)
- [ADR-010 Establish ServiceHub Observability Platform](../../../docs/architecture/adr/ADR-010-establish-servicehub-observability-platform.md)