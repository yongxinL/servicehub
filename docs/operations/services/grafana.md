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

## Dashboard architecture and Stage 6 decisions

### First-party dashboards

| UID / File | Title | Purpose | Stage 6 changes |
|---|---|---|---|
| `servicehub-overview` | ServiceHub Overview | High-level red/amber/green across all domains | None |
| `servicehub-infrastructure` | ServiceHub Infrastructure | Host-level CPU, memory, load, disk, network, PSI | **Enhanced:** Memory → Memory composition (7 series), Load → Load average (adds 1m/CPU count and CPU cores), Disk I/O (+ IOPS, I/O time ratio, weighted I/O), Network (+ receive/transmit errors) |
| `servicehub-traffic-edge` | ServiceHub Traffic and Edge | Edge traffic, TLS, bounded GeoIP | **Enhanced:** Added Request rate by entrypoint, Open connections by entrypoint, Config reloads (last hour), TLS cert expiry (Traefik); shifted geo panels down 10 grid units |
| `servicehub-docker-containers` | ServiceHub Docker and Containers | cAdvisor-based container CPU/memory/disk | None (evaluated: CPU throttling unsupported, per-container network identity-less root only → no additions) |
| `servicehub-applications` | ServiceHub Applications | Application-level RED metrics | None |
| `servicehub-database` | ServiceHub Database | PostgreSQL exporter metrics | None |
| `servicehub-observability-health` | ServiceHub Observability Health | Telemetry pipeline health (Alloy, VM, VL, Grafana) | None |
| `servicehub-security` | ServiceHub Security | SSH/sudo, Authentik/Forgejo/Traefik failures, GeoIP, recent logs | **Layout restructured:** 2×2 top row (SSH/sudo, Traefik 4xx, Authentik, Forgejo), full-width row label, 3-panel geo summary (Top 5 Countries w=10, Total Countries w=4, Top 5 Public IPs w=10), full-width recent logs; Forgejo empty state documented honestly |

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