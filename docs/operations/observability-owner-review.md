# Owner Review and Acceptance Checklist

> Reusable checklist for ADR-010 final acceptance. Record one decision at the end.

---

## Access and authentication

- [ ] Access Grafana from a trusted source (matches `TRUSTED_IP` allowlist).
- [ ] Confirm built-in Grafana login appears (no redirect to Authentik).
- [ ] Confirm anonymous access is disabled (login required).
- [ ] If safely testable, confirm non-trusted access is denied (HTTP 403 from untrusted source).
- [ ] Confirm no separate `GRAFANA_ALLOWED_CIDRS` variable is in use.

---

## Dashboard review (all 8 first-party)

For each of the eight dashboards, review at 15-minute, 6-hour, and 24-hour ranges where applicable:

- [ ] Titles, units, legends, thresholds, colors render correctly.
- [ ] Empty states render as documented (no error messages).
- [ ] Grid layout has no overlaps or clipping.
- [ ] Log panels show `Time | Level | Service/Container | Message`.
- [ ] Log timestamps are current (within last few minutes for live ranges).
- [ ] No `Max`, `Value`, `requests{...}`, "missing number field", or "missing time field" artifacts.
- [ ] Fixed-window panels are clearly labeled (e.g., "last 10m") and descriptions state they ignore the dashboard time range.
- [ ] Dashboard-range panels follow the time picker.
- [ ] Client/country panels (Traffic and Edge, Security) render correctly.
- [ ] No credentials, API keys, or sensitive query strings are visible in panel text or tooltips.

### Per-dashboard checks

#### ServiceHub Overview
- [ ] Host CPU used, Host memory used, Filesystem capacity stat panels render.
- [ ] Service readiness shows 1 for all 8 services.
- [ ] PSI panel shows CPU/Memory/I/O wait rates.
- [ ] HTTP traffic and errors panel renders.
- [ ] Container restarts and OOM shows 0 (15m fixed window).
- [ ] Authentication and authorization failures shows 0 or low volume.
- [ ] Observability pipeline health shows remote-write success.
- [ ] Recent warning/error logs panel shows `Time | Level | Service | Message`.

#### ServiceHub Applications
- [ ] `service` variable (multi-select, All) filters panels correctly.
- [ ] Application readiness shows 1 for each selected service.
- [ ] Requests and errors panel renders per service.
- [ ] Request latency (p50/p95/p99) renders.
- [ ] Container CPU and memory render per service.
- [ ] Authentik task queue panel shows N/A for non-Authentik services (expected).
- [ ] Application logs show `Time | Level | Service | Message` for selected service.

#### ServiceHub Infrastructure
- [ ] **Pressure** bargauge shows CPU/Memory/I/O bars (y=0 row).
- [ ] **CPU Busy** gauge renders (green/yellow/red thresholds).
- [ ] **System Load** gauge renders (normalized against CPU count).
- [ ] **RAM Usage** gauge renders.
- [ ] **Swap Used** gauge shows percentage OR "Not configured" (if swap disabled).
- [ ] **Uptime** stat shows `dtdurations` format.
- [ ] Detail panels: CPU utilization, Memory composition, Load average (y=5).
- [ ] Detail panels: PSI detail, Filesystem capacity, Inode utilization (y=13).
- [ ] Detail panels: Disk I/O, Network, Read-only mounts (y=21).
- [ ] No isolated Uptime panel at bottom (confirmed removed).

#### ServiceHub Docker and Containers
- [ ] `container` variable (multi-select, All) filters correctly.
- [ ] Container running stat shows 1/0 mapping.
- [ ] CPU usage, Memory and limits, Disk I/O render.
- [ ] Container age stat renders (`colorMode: none`).
- [ ] Restart and OOM indicators render (15m window).
- [ ] Container logs show `Time | Level | Container | Message`.
- [ ] Runtime Limitations row: CPU throttling and Container network documented as unavailable.

#### ServiceHub Database
- [ ] PostgreSQL availability shows 1.
- [ ] Connections, Transactions, Locks and deadlocks, Long-running transactions render.
- [ ] Database size renders.
- [ ] Cache hit ratio shows percent axis.
- [ ] Temporary bytes and WAL size show bytes axis.
- [ ] Replication panels validly empty (no replica configured).

#### ServiceHub Traffic and Edge
- [ ] Request rate by service renders.
- [ ] HTTP status codes shows 2xx/3xx/4xx/5xx; `code=0` labeled as websocket.
- [ ] Response latency (p50/p95/p99) renders.
- [ ] Service errors (4xx/5xx rate) renders.
- [ ] TLS endpoint state renders.
- [ ] **Latency and SLO row**: Apdex score, Top slow services, Services failing SLO 300ms, Services failing SLO 1200ms.
- [ ] **Ten-minute HTTP outcomes row**: 2xx, 5xx, Non-2xx/non-5xx (fixed 10m window).
- [ ] Request/response body throughput render.
- [ ] Request rate by entrypoint, Open connections by entrypoint render.
- [ ] Config reloads (last hour, fixed 1h window) renders.
- [ ] TLS certificate expiry (Traefik) renders.
- [ ] Top 10 Countries by Traffic (VictoriaLogs bargauge) renders.
- [ ] Traefik access logs panel shows structured fields; path/query omitted (expected).
- [ ] Client IP Distribution, Geographic Distribution, Country traffic trend render.
- [ ] Total Unique Countries stat renders.

#### ServiceHub Security
- [ ] SSH and sudo journal log panel shows `Time | Level | Service | Message`.
- [ ] Traefik 401/403/404/429 panel renders.
- [ ] Authentik failures log panel renders.
- [ ] Forgejo failures log panel renders (empty = no failures OR no structured logs — documented).
- [ ] Top 5 Countries, Total Unique Countries, Top 5 Public Client IPs render.
- [ ] Recent security logs show `Time | Level | Service | Message`.

#### ServiceHub Observability Health
- [ ] Collector and store readiness shows 1 for VM/VLogs/Grafana/Alloy.
- [ ] Remote-write health shows 0 failures.
- [ ] Scrape health shows all targets up.
- [ ] Storage capacity renders.
- [ ] Observability logs show `Time | Level | Service | Message`.
- [ ] Recent log ingestion renders (timeseries).
- [ ] Live alert evaluation shows firing/pending/no-data only.
- [ ] Notification and watchdog coverage text panel documents evaluation enabled, delivery deferred, watchdog deferred.

---

## Infrastructure verification (explicit)

- [ ] Pressure CPU/Memory/I/O bars render.
- [ ] CPU Busy gauge renders.
- [ ] System Load gauge (normalized against CPU count) renders.
- [ ] RAM Usage gauge renders.
- [ ] Swap Used shows percentage OR "Not configured" (zero-swap behavior).
- [ ] Uptime renders in top summary row.
- [ ] Detailed panels (CPU, memory, load, PSI, filesystem, inode, disk, network, read-only) retained.

---

## Alerts

- [ ] Review current firing/pending/NoData states via Grafana Alerting UI or API.
- [ ] Verify real warnings are understood (CPU/memory/IO pressure if firing).
- [ ] Confirm notification delivery remains intentionally deferred (no contact points).
- [ ] Confirm external watchdog remains intentionally deferred.
- [ ] Confirm `servicehub-traefik-5xx` is healthy (rule health ok, not error).
- [ ] Confirm `servicehub-fs-readonly` is healthy (rule health ok, not error).

---

## Explore and Drilldown

- [ ] Test VictoriaMetrics in Explore (query `up`, label/series discovery, instant/range).
- [ ] Test VictoriaLogs in Explore (LogSQL query, e.g., `{project="servicehub"} | stats count()`).
- [ ] Test Metrics Drilldown (works with Prometheus-compatible VictoriaMetrics).
- [ ] Confirm Logs Drilldown behavior matches documentation (disabled; use Explore with VictoriaLogs).
- [ ] Confirm Traces Drilldown behavior matches documentation (disabled; no tracing backend).

---

## Final decision

Record exactly one:

```
ACCEPTED FOR MERGE
CHANGES REQUIRED
DEFERRED
```

> Do not merge based solely on automated validation. This checklist requires owner acceptance.

---

## Sign-off

- Reviewer: ________________________
- Date: ________________________
- Decision: ________________________
- Notes: ________________________

---

## Related documents

- [Observability Operations Guide](observability.md)
- [Dashboard Catalogue](observability-dashboards.md)
- [Metrics Catalogue](observability-metrics.md)
- [Logs Catalogue](observability-logs.md)
- [Alert Catalogue](observability-alerts.md)
- [Grafana Operations Guide](services/grafana.md)
