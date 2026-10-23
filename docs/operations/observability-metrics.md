# Metrics Catalogue

> Meaningful metric families, formulas, and consumers. Not an exhaustive series list.

All metrics live in VictoriaMetrics with `project="servicehub"` and `environment` labels. Scrape interval is 30s (probes 30s internal / 60s public). Retention: **90 days** (`--retentionPeriod=90d`, owner-approved). Datasource UID: `victoriametrics`.

---

## Host metrics (node/unix exporter, `job="obstack"`)

| Family | Formula / query | Unit | Interpretation | Dashboard | Alert |
|--------|-----------------|------|----------------|-----------|-------|
| CPU Busy | `100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))` | % | Time not idle, averaged across cores | Infrastructure (CPU Busy, Overview) | — (Pressure covers contention) |
| CPU mode utilization | `avg by (mode) (rate(node_cpu_seconds_total[5m])) * 100` | % | Per-mode breakdown (idle, user, system, iowait…) | Infrastructure (CPU utilization) | — |
| Normalized System Load | `100 * node_load1 / count(count by (cpu)(node_cpu_seconds_total))` | % | 1m load ÷ core count; >100% = load exceeds cores | Infrastructure (System Load) | — |
| RAM Usage | `clamp_min((1 - MemAvailable/MemTotal) * 100, 0)` | % | Share of RAM not available | Infrastructure (RAM Usage), Overview | — |
| Memory composition | `MemTotal - MemAvailable`, `Cached`, `Buffers`, `SReclaimable`, `MemAvailable`, `SwapTotal - SwapFree`, `SwapTotal` | bytes | Used overlaps reclaimable; Cached/SReclaimable overlap | Infrastructure (Memory composition) | — |
| Swap Used | `(100 * (SwapTotal - SwapFree) / clamp_min(SwapTotal, 1)) and (SwapTotal > 0)` | % | Percent of swap in use; **no series when swap disabled** → renders "Not configured" | Infrastructure (Swap Used) | — |
| PSI CPU/Memory/I/O | `rate(node_pressure_{cpu,memory,io}_waiting_seconds_total[5m])` | stall fraction (1.0 = fully stalled) | "some" task stall rate over 5m | Infrastructure (Pressure, PSI detail), Overview | `servicehub-{cpu,memory,io}-pressure` (>0.2 for 10m) |
| Filesystem utilization | `100 * (1 - node_filesystem_avail_bytes / node_filesystem_size_bytes)` | % | Per validated mountpoint (virtual FS excluded) | Infrastructure, Overview | `servicehub-fs-warning` (>85%, 15m), `servicehub-fs-critical` (>95%, 5m) |
| Inode utilization | `100 * (1 - node_filesystem_files_free / node_filesystem_files)` | % | Inode exhaustion risk | Infrastructure | `servicehub-inode-critical` (>95%, 5m) |
| Read-only mounts | `node_filesystem_readonly` | 0/1 | Boolean; **not** on percent axis | Infrastructure (Read-only mounts) | `servicehub-fs-readonly` (max >0.5, 1m) |
| Disk throughput/IOPS | `rate(node_disk_{read,written}_bytes_total[5m])`, `rate(node_disk_{reads,writes}_completed_total[5m])` | B/s, IOPS | Excludes sr0/loop/ram/fd | Infrastructure (Disk I/O) | — |
| Disk saturation | `rate(node_disk_io_time_seconds_total[5m])`, `rate(node_disk_io_time_weighted_seconds_total[5m])` | ratio | I/O time ratio; weighted = queue depth × time | Infrastructure (Disk I/O) | — |
| Network throughput/errors | `rate(node_network_{receive,transmit}_{bytes,errs}_total[5m])` | B/s, errs/s | Excludes `lo` | Infrastructure (Network) | — |
| Uptime | `node_time_seconds - node_boot_time_seconds` | seconds | Informational | Infrastructure (Uptime) | — |

---

## Container metrics (cAdvisor, `job="cadvisor"`)

Identity: `name` (full container name), `compose_service` (compose label), `logical_service` (bounded 8-value mapping). `container_label_*` dropped to respect VictoriaMetrics' 40-label limit.

| Family | Formula / query | Unit | Interpretation | Dashboard | Alert |
|--------|-----------------|------|----------------|-----------|-------|
| Current/running state | `container_last_seen{name=~"servicehub-.*"}` (age = `time() - value`); `time() - container_last_seen > 90` = gone | s | Last-seen timestamp; age panel informational | Docker and Containers | `servicehub-runner-warning` (runner not seen 5m) |
| CPU | `rate(container_cpu_usage_seconds_total{name=~"servicehub-.*"}[5m])` | cores | Per-container CPU seconds/s | Applications, Docker and Containers | — |
| Memory / limits | `container_memory_working_set_bytes`, `container_spec_memory_limit_bytes` | bytes | Working set vs cgroup limit | Applications, Docker and Containers | — |
| Disk I/O | `rate(container_fs_{reads,writes}_bytes_total[5m])` | B/s | Per-container filesystem I/O | Docker and Containers | — |
| Restarts | `changes(container_start_time_seconds{compose_service=~"..."}[10m])` | count | Frequent restarts = crash loop | Overview, Docker and Containers | `servicehub-container-restart-loop` (>0 in 10m, critical) |
| OOM | `increase(container_oom_events_total{compose_service=~"..."}[5m])` | count | Kernel OOM kills | Overview, Docker and Containers | `servicehub-container-oom` (>0 in 5m, critical) |
| CPU throttling | **Not collected** | — | cAdvisor throttling metrics unavailable via current collection path | (documented limitation) | — |
| Network identity | **Not collected per-interface** | — | Only aggregate `container_network_*` | (documented limitation) | — |

---

## Traefik metrics (`job="traefik"`)

Identity: `service` label is `<compose>@docker`, relabeled to bounded `logical_service`.

| Family | Formula / query | Unit | Interpretation | Dashboard | Alert |
|--------|-----------------|------|----------------|-----------|-------|
| Requests by service | `sum by (logical_service) (rate(traefik_service_requests_total[5m]))` | req/s | Per-service request rate | Traffic and Edge, Applications, Overview | — |
| Requests by entrypoint | `sum by (entrypoint) (rate(traefik_entrypoint_requests_total[5m]))` | req/s | web/websecure split | Traffic and Edge | — |
| Status classes | `sum by (code) (rate(traefik_service_requests_total[5m]))` | req/s | 2xx/3xx/4xx/5xx; `code="0"` = websocket upgrade (not an error) | Traffic and Edge, Overview | `servicehub-traefik-5xx` (5xx ratio >5% for 10m) |
| Request-duration buckets | `traefik_service_request_duration_seconds_bucket` | histogram | Live boundaries: 0.1, 0.3, 1.2, 5.0, +Inf | Traffic and Edge | — |
| p95 latency | `histogram_quantile(0.95, sum by (le) (rate(traefik_service_request_duration_seconds_bucket[5m])))` | s | 95th percentile; 5s plateau artefact documented | Traffic and Edge, Applications | `servicehub-traefik-latency` (p95 >2s for 10m) |
| Apdex | `(rate(bucket{le="0.3"}) + (rate(bucket{le="1.2"}) - rate(bucket{le="0.3"}))/2) / rate(bucket{le="+Inf"})` — aggregated away from `le` before division | score 0–1 | Satisfied (≤300ms) + Tolerating (≤1200ms)/2 over total | Traffic and Edge (Apdex score) | — |
| SLO 300ms violation | `1 - (sum by (logical_service) (rate(bucket{le="0.3"}[5m])) / sum by (logical_service) (rate(bucket{le="+Inf"}[5m])))` | ratio | Share of requests over 300ms | Traffic and Edge | — |
| SLO 1200ms violation | same with `le="1.2"` | ratio | Share over 1200ms | Traffic and Edge | — |
| 2xx/5xx/other, last 10m | `increase(traefik_service_requests_total{code=~"2.."}[10m])` etc. | requests | Fixed 10m window | Traffic and Edge | — |
| Request/response throughput | `rate(traefik_service_requests_bytes_total[5m])`, `rate(traefik_service_responses_bytes_total[5m])` | B/s | Payload throughput | Traffic and Edge | — |
| Open connections | `traefik_open_connections` | count | By entrypoint | Traffic and Edge | — |
| Config reloads | `traefik_config_reloads_total` | count | Fixed 1h window (increase) | Traffic and Edge | — |
| TLS state / cert expiry | `traefik_tls_certs_not_after` (Traefik source); `probe_ssl_earliest_cert_expiry{target_class="external"}` (blackbox) | unix s | Cert expiry countdown | Traffic and Edge | `servicehub-tls-expiry` (<14 days, 1h) |

**PromQL caveat**: The `le` label survives `rate()`, so `rate(bucket{le="0.3"}) / rate(bucket{le="+Inf"})` in place returns empty (sides never match on `le`). Aggregate with `sum by (logical_service)` before dividing.

---

## Application / native metrics

| Source | Job | Key families | Notes |
|--------|-----|--------------|-------|
| Authentik server | `authentik_server` (port 9300) | `authentik_requests`, `authentik_task_queue_size`, worker/task metrics | Task queue panel (Applications) is Authentik-only |
| Authentik worker | `authentik_worker` (port 9300) | Same families, `component="worker"` | — |
| oCIS | `ocis_proxy` (port 9205) | Proxy request metrics | Component `component="proxy"` |
| Alloy | `alloy` (self-scrape :9080) | `alloy_config_last_load_successful`, `prometheus_remote_storage_*`, scrape metrics | Powers pipeline-health panels/alerts |
| PostgreSQL | `postgresql` (via postgres exporter, optional) | `pg_up`, `pg_stat_*` | Enabled with `POSTGRES_EXPORTER_ENABLED=true` |

---

## PostgreSQL metrics (`job="postgresql"`, optional exporter)

| Family | Query | Interpretation | Dashboard | Alert |
|--------|-------|----------------|-----------|-------|
| Availability | `pg_up` | Exporter's view of PostgreSQL liveness | Database | `servicehub-postgresql-critical` (min <1, 2m) |
| Connections | `pg_stat_database_numbackends`, `pg_settings_max_connections` | Active per DB vs limit | Database | — |
| Transactions | `rate(pg_stat_database_xact_commit[5m])`, `xact_rollback` | Commit/rollback rate | Database | — |
| Locks / deadlocks | `pg_stat_database_deadlocks`, `pg_locks_count` | Lock contention | Database | — |
| Long-running activity | `pg_stat_activity_count{state="active"}`, max tx duration | Stuck transactions | Database | — |
| Database size | `pg_database_size_bytes` | Growth tracking | Database | — |
| Cache hit ratio | `pg_stat_database_blks_hit / (blks_hit + blks_read) * 100` | Percent axis | Database | — |
| Temp bytes / WAL | `pg_stat_database_temp_bytes`, `pg_wal_lsn_diff`/size | Spill + WAL volume | Database | — |
| Tables / I/O | `pg_stat_user_tables_*`, `pg_stat_database_blks_*` | Collector-supported set | Database | — |
| Replication | `pg_replication_*` families | **Not applicable** — no replica configured; panels validly empty | Database | — |

Collector boundary: only exporters' documented collectors are scraped; unsupported families (e.g., `pg_stat_statements` without the extension) return no series.

---

## Probe metrics (blackbox, `component="probe"`)

| Family | Formula / query | Interpretation | Dashboard | Alert |
|--------|-----------------|----------------|-----------|-------|
| Internal readiness | `probe_success{probe_type="readiness", target_class="internal"}` | 1 = endpoint returned 2xx. Targets: Traefik `/ping`, Authentik server+worker `/-/health/ready/`, Confluence `/status`, Forgejo `/api/healthz`, oCIS `/status.php`, Grafana `/api/health`, VM `/health`, VLogs `/health` | Overview, Applications, Observability Health | `servicehub-{traefik,authentik,confluence,forgejo,ocis,victoriametrics,victorialogs,grafana}-critical` (min <1, 2m) |
| Public HTTPS | `probe_success{probe_type="https", target_class="external"}` | Public endpoints: DOMAIN_NAME (expected redirect), IDENTITY/WORKSPACE/SOURCECODE/CLOUD (2xx), OBSERVABILITY (admin restricted — **expected to fail/403 from non-trusted sources**; restricted-200 success criteria) | Traffic and Edge, Observability Health | — |
| TLS / certificate expiry | `probe_ssl_earliest_cert_expiry{probe_type="https"} - time()` | Seconds until public cert expires | Traffic and Edge | `servicehub-tls-expiry` (<14 days, 1h) |
| Probe duration | `probe_duration_seconds` | End-to-end HTTP duration | Traffic and Edge, Applications | — |

---

## Identity and cardinality

- **Exactly eight `logical_service` values**: `authentik`, `confluence`, `forgejo`, `ocis`, `traefik`, `grafana`, `victoriametrics`, `victorialogs`. Mapping is relabel-only (Alloy); workloads outside the eight (PostgreSQL, runners, one-shot jobs) get **no** `logical_service` value — no fallback. Stream/series cardinality stays bounded.
- **Excluded workload behavior**: Containers outside the eight are visible via `compose_service`/`name` labels but never via `logical_service`.
- **Client IP is not a Prometheus label** — it lives only in VictoriaLogs structured metadata (searchable, not a stream label) to protect stream cardinality. GeoIP **country code** is a bounded label; city/coordinates stay structured metadata.
- **Bounded labels used by alerts/dashboards**: `project`, `environment`, `logical_service`, `compose_service`, `service`, `job`, `instance`, `probe_type`, `target_class`, `component`, `code`, `le`, `mountpoint`, `device`, `mode`, `name` (container).

---

## Related documents

- [Observability Operations Guide](observability.md) — data flow, components, health checks
- [Dashboard Catalogue](observability-dashboards.md) — panels that consume these metrics
- [Alert Catalogue](observability-alerts.md) — alert expressions built on these families
- [Logs Catalogue](observability-logs.md) — log-side identity and metadata
