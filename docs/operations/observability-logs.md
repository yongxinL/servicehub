# Logs Catalogue

> Source matrix, display standard, post-cutover boundary, labels vs metadata, useful queries.

All logs flow through Alloy → VictoriaLogs → Grafana. VictoriaLogs datasource UID: `victorialogs`. Push endpoint: `http://obsvcevlogs:9428/insert/loki/api/v1/push`. Retention: **30 days** (`--retentionPeriod=30d`, owner-approved).

---

## Source matrix

| Source | Alloy component | Message field | Level/severity | Service/container identity | Important structured metadata | Dashboard use | Limitations |
|--------|----------------|---------------|----------------|---------------------------|------------------------------|---------------|-------------|
| **Journal — SSH** | `loki.source.journal "ssh"` (`_COMM=sshd`) | `MESSAGE` (via `extracted_message`) | `priority_name` (emerg..debug) → `priority` (0..7) | `service="linux-host" component="security" source="journal"` | `syslog_identifier`, `transport`, `process_name` | Security (SSH/sudo) | — |
| **Journal — sudo** | `loki.source.journal "sudo"` (`_COMM=sudo`) | `MESSAGE` | `priority_name`/`priority` | `service="linux-host" component="security"` | `syslog_identifier`, `process_name` | Security (SSH/sudo) | — |
| **Journal — auth (logind)** | `loki.source.journal "authentication"` (`_SYSTEMD_UNIT=systemd-logind.service`) | `MESSAGE` | `priority_name`/`priority` | `service="linux-host" component="security"` | `syslog_identifier` | Security (auth log) | — |
| **Journal — kernel** | `loki.source.journal "kernel"` (`_TRANSPORT=kernel`) | `MESSAGE` | `priority_name`/`priority` | `service="linux-host" component="system"` | `transport="kernel"` | Observability Health, Security | — |
| **Journal — Docker** | `loki.source.journal "docker"` (`_SYSTEMD_UNIT=docker.service`) | `MESSAGE` | `priority_name`/`priority` | `service="docker" component="runtime"` | `syslog_identifier` | Observability Health | — |
| **Journal — systemd** | `loki.source.journal "systemd"` (`_COMM=systemd`) | `MESSAGE` | `priority_name`/`priority` | `service="linux-host" component="systemd"` | `syslog_identifier` | Observability Health | — |
| **Journal — firewall** | `loki.source.journal "firewall"` (`SYSLOG_IDENTIFIER=firewalld`) | `MESSAGE` | `priority_name`/`priority` | `service="linux-host" component="firewall"` | `syslog_identifier` | Security, Observability Health | — |
| **Container — Authentik** | `loki.source.docker` → `loki.process.container_logs` (match `logical_service="authentik"`) | `event` JSON field → `extracted_message` | `level` JSON field → structured metadata `level` | `logical_service="authentik"` | `level`, `status`, `method`, `path` | Applications, Security (Authentik failures) | Pre-cutover records have `_msg` placeholder |
| **Container — oCIS** | `loki.process.container_logs` (match `logical_service="ocis"`) | `message` JSON field → `extracted_message` | `level` JSON field → structured metadata | `logical_service="ocis"` | `level`, `method`, `path`, `status` | Applications, Security | Pre-cutover records have `_msg` placeholder |
| **Container — Forgejo** | `loki.process.container_logs` (plain-text pass-through) | Original line (VictoriaLogs uses line as message) | May have no level | `logical_service="forgejo"` | — | Applications, Security (Forgejo failures) | No structured level in plain text |
| **Container — Grafana** | `loki.process.container_logs` (plain-text) | Original line | May have no level | `logical_service="grafana"` | — | Observability Health | — |
| **Container — Alloy** | `loki.process.container_logs` (plain-text) | Original line | May have no level | `logical_service="victoriametrics"\|"victorialogs"\|"alloy"` | — | Observability Health | — |
| **Container — PostgreSQL / MariaDB** | `loki.process.container_logs` (plain-text) | Original line | May have no level | `logical_service` unset (excluded workload) | — | Observability Health | No `logical_service` — not in 8 bounded set |
| **Traefik access logs** | `loki.source.docker` → `loki.process.geoip_enrichment` | JSON line kept (no human-readable `_msg` synthesized) | `DownstreamStatus` present as field | `project="servicehub"` via geoip pipeline | `RequestMethod`, `RequestHost`, `RequestPath`, `RouterName`, `DownstreamStatus`, `Duration`, `ClientHost` (as structured metadata `client_ip`), `geoip_country_code` (label), `geoip_country_name/city/lat/lon` (structured metadata) | Traffic and Edge (access logs, GeoIP panels) | Path/query strings deliberately not displayed (LogSQL cannot strip query params); `_msg` placeholder remains (JSON has no `_msg`) |

---

## Dashboard display standard

Every first-party log panel shows, at minimum:

```
Time | Level | Service/Container | Message
```

- **Time**: Frame timestamp from VictoriaLogs (`_time` preserved by not dropping it in `| fields`).
- **Level**: For structured sources (Authentik, oCIS, journal), the normalized `level`/`priority_name`. Plain-text sources (Forgejo, Grafana, Alloy, PostgreSQL) legitimately show **no level** — not a fabricated `UNK` class.
- **Service/Container**: `logical_service` (8 bounded values) or `container_name` (Docker panel).
- **Message**: The human-readable line — `extracted_message` for JSON sources, raw line for plain-text, JSON line for Traefik (structured fields render as chips).

**Traefik access logs**: Display selected fields `RequestMethod`, `RequestHost`, `RouterName`, `DownstreamStatus`, `Duration` via `displayedFields`. Request path and query string **omitted** — LogSQL cannot strip query parameters, so path column excluded rather than shown unsanitized.

---

## Post-cutover boundary

- **Stage 5 cutover**: Message-field mapping corrected (Authentik `event`, oCIS `message`, journal `MESSAGE`, plain-text pass-through).
- **Only post-cutover records** are guaranteed to contain the corrected message mapping.
- **Historical placeholders** (`missing _msg field; see docs.victoriametrics.com/...#message-field`) are retained until normal log retention expires.
- **Telemetry must not be deleted** merely to clean old presentation artifacts.

---

## Labels versus metadata

| Category | Treatment | Rationale |
|----------|-----------|-----------|
| **Low-cardinality stream labels** | `project`, `environment`, `instance`, `service`, `component`, `source`, `logical_service` (8 values), `geoip_country_code` (bounded), `event_source="journald"` | Promoted to VictoriaLogs stream labels for fast filtering and bounded cardinality. |
| **Structured metadata** | `syslog_identifier`, `transport`, `process_name`, `level`, `status`, `method`, `path`, `client_ip`, `geoip_country_name`, `geoip_city_name`, `geoip_location_latitude`, `geoip_location_longitude`, secret-filtered fields | Searchable in VictoriaLogs but **not** stream labels — keeps stream cardinality bounded while enabling deep investigation. |
| **Client IP** | Structured metadata only (`client_ip`) — **never a stream label** | Unbounded cardinality would break VictoriaLogs; searchable for investigation. |
| **GeoIP country** | `geoip_country_code` promoted to label (bounded ~250); city/coordinates as structured metadata | Enables country-level aggregation panels without cardinality explosion. |
| **Message text** | Never a label | Unbounded; rendered as `Line` / `Message` column. |
| **Secrets** | `loki.secretfilter` redacts with `<REDACTED:$SECRET_NAME>` before write | Prevents credentials/API keys from entering storage. |

---

## Useful queries (VictoriaLogs LogSQL)

> Use in Grafana **Explore** with VictoriaLogs datasource. All queries bounded by time range.

| Purpose | Query |
|---------|-------|
| Logs for one logical service | `{project="servicehub", logical_service="authentik"}` |
| Warnings/errors over bounded range | `{project="servicehub"} \| filter level =~ "warn\|warning\|error\|critical" \| limit 200` |
| Traefik 5xx access records | `{project="servicehub"} \| filter DownstreamStatus =~ "5.." \| limit 100` |
| SSH/sudo records | `{project="servicehub", component="security"} \| limit 100` |
| Authentik failures | `{project="servicehub", logical_service="authentik"} \| filter level =~ "warn\|warning\|error\|critical" \| limit 50` |
| Records after message cutover (no `_msg` placeholder) | `{project="servicehub"} \| filter Line !~ "missing _msg field" \| limit 200` |
| Container logs for specific container | `{project="servicehub", container_name="servicehub-infraauth-1"}` |
| All security journals (SSH, sudo, logind, firewall) | `{project="servicehub", service="linux-host", component=~"security\|firewall"}` |
| VictoriaLogs ingestion rate | `{project="servicehub"} \| stats count() as logs by (__stream__) \| limit 50` |

> **Note**: VictoriaLogs LogSQL uses `| filter` (not `|=` / `!=` Loki syntax). `logical_service` is the primary bounded filter for application logs.

---

## Related documents

- [Observability Operations Guide](observability.md) — data flow, components
- [Dashboard Catalogue](observability-dashboards.md) — log panels per dashboard
- [Metrics Catalogue](observability-metrics.md) — metric-side identity and labels
- [Alert Catalogue](observability-alerts.md) — log-based alert rules (none currently; alerts are metric-based)
