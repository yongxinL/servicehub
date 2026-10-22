# Alert Catalogue and Runbook

> All 27 Grafana-managed alert rules across 3 groups. Evaluation interval: 60s per group.

---

## Global state

```
Alert evaluation:     configured (GF_ALERTING_enabled=true; 27 rules provisioned)
Notification delivery: NOT CONFIGURED (no contact points; evaluation runs but nobody is paged)
External watchdog:    NOT CONFIGURED (no independent whole-host monitor)
```

**Notification delivery and external watchdog are intentionally deferred** pending owner configuration. This document is the runbook until then.

---

## Group 1: `servicehub-infrastructure-critical` (12 rules, critical)

| UID | Title | Severity | Source | For | NoData | ExecErr | Healthy | First step | Dashboard | Tuning owner |
|-----|-------|----------|--------|-----|--------|---------|---------|-------------|-----------|--------------|
| `servicehub-fs-critical` | Filesystem critically full | critical | `100 * (1 - avail/size)` > 95% | 5m | NoData | Error | Below 95% | Check `df -h`, largest directories | Infrastructure | Platform |
| `servicehub-inode-critical` | Inode exhaustion imminent | critical | `100 * (1 - files_free/files)` > 95% | 5m | NoData | Error | Below 95% | `find / -xdev -inum ...`, check small files | Infrastructure | Platform |
| `servicehub-fs-readonly` | Filesystem became read-only | critical | `max(node_filesystem_readonly) > 0.5` | 1m | NoData | Error | 0 (all rw) | `mount`, `dmesg` for I/O errors | Infrastructure | Platform |
| `servicehub-traefik-critical` | Traefik unavailable | critical | `min(probe_success{...traefik...}) < 1` | 2m | Alerting | Alerting | 1 | Check Traefik container, `/ping` | Traffic and Edge | Platform |
| `servicehub-authentik-critical` | Authentik unavailable | critical | `min(probe_success{...authentik...}) < 1` | 2m | Alerting | Alerting | 1 | Check Authentik server/worker | Applications | Identity team |
| `servicehub-confluence-critical` | Confluence unavailable | critical | `min(probe_success{...confluence...}) < 1` | 2m | Alerting | Alerting | 1 | Check Confluence container | Overview | Workspace team |
| `servicehub-forgejo-critical` | Forgejo unavailable | critical | `min(probe_success{...forgejo...}) < 1` | 2m | Alerting | Alerting | 1 | Check Forgejo container | Applications | DevOps |
| `servicehub-ocis-critical` | ownCloud Infinite Scale unavailable | critical | `min(probe_success{...ocis...}) < 1` | 2m | Alerting | Alerting | 1 | Check oCIS container | Applications | Storage team |
| `servicehub-container-restart-loop` | Container restart loop | critical | `changes(container_start_time_seconds[10m]) > 0` | 5m | NoData | Error | 0 changes | `docker ps`, `docker logs <container>` | Docker and Containers | Platform |
| `servicehub-container-oom` | Container OOM event | critical | `increase(container_oom_events_total[5m]) > 0` | 0s | NoData | Error | 0 events | `dmesg \| grep -i oom`, check memory limits | Docker and Containers | Platform |
| `servicehub-telemetry-ingestion` | Telemetry remote-write failed | critical | `sum(increase(prometheus_remote_storage_samples_failed_total[5m])) > 0` | 2m | Alerting | Alerting | 0 | Check Alloy→VM connectivity | Observability Health | Platform |
| `servicehub-postgresql-critical` | PostgreSQL unavailable | critical | `min(pg_up) < 1` | 2m | Alerting | Alerting | 1 | Check PostgreSQL container | Database | Platform |

---

## Group 2: `servicehub-capacity-warning` (8 rules, warning)

| UID | Title | Severity | Source | For | NoData | ExecErr | Healthy | First step | Dashboard | Tuning owner |
|-----|-------|----------|--------|-----|--------|---------|---------|-------------|-----------|--------------|
| `servicehub-fs-warning` | Filesystem approaching capacity | warning | `100 * (1 - avail/size)` > 85% | 15m | NoData | Error | Below 85% | `du -sh`, plan cleanup | Infrastructure | Platform |
| `servicehub-cpu-pressure` | Sustained CPU pressure | warning | `rate(node_pressure_cpu_waiting_seconds_total[5m]) > 0.2` | 10m | NoData | Error | ≤0.2 | `top`, identify hot processes | Infrastructure | Platform |
| `servicehub-memory-pressure` | Sustained memory pressure | warning | `rate(node_pressure_memory_waiting_seconds_total[5m]) > 0.2` | 10m | NoData | Error | ≤0.2 | `free -h`, check swap | Infrastructure | Platform |
| `servicehub-io-pressure` | Sustained I/O pressure | warning | `rate(node_pressure_io_waiting_seconds_total[5m]) > 0.2` | 10m | NoData | Error | ≤0.2 | `iostat`, check disk queue | Infrastructure | Platform |
| `servicehub-tls-expiry` | TLS certificate approaching expiry | warning | `probe_ssl_earliest_cert_expiry - time() < 14 days` | 1h | NoData | Error | >14 days | Check certbot/Traefik ACME renewal | Traffic and Edge | Platform |
| `servicehub-traefik-5xx` | Sustained Traefik HTTP 5xx rate | warning | `(sum(rate(5xx[5m])) or vector(0)) / clamp_min(sum(rate(all[5m])), 1) > 0.05` | 10m | NoData | Error | ≤5% | Check upstream service, Traefik access logs | Traffic and Edge | Platform |
| `servicehub-traefik-latency` | Sustained Traefik latency degradation | warning | `histogram_quantile(0.95, ...) > 2s` | 10m | NoData | Error | p95 <2s | Top slow services panel | Traffic and Edge | Platform |
| `servicehub-runner-warning` | Forgejo Actions Runner unavailable | warning | `max(time() - container_last_seen{devopsrunner}) > 5m` | 5m | Alerting | Error | <5m | Check runner container | Overview | DevOps |

---

## Group 3: `servicehub-observability-pipeline` (7 rules, critical)

| UID | Title | Severity | Source | For | NoData | ExecErr | Healthy | First step | Dashboard | Tuning owner |
|-----|-------|----------|--------|-----|--------|---------|---------|-------------|-----------|--------------|
| `servicehub-victoriametrics-critical` | VictoriaMetrics unavailable | critical | `min(probe_success{...victoriametrics...}) < 1` | 2m | Alerting | Alerting | 1 | Check VM container, `/health` | Observability Health | Platform |
| `servicehub-victorialogs-critical` | VictoriaLogs unavailable | critical | `min(probe_success{...victorialogs...}) < 1` | 2m | Alerting | Alerting | 1 | Check VLogs container, `/health` | Observability Health | Platform |
| `servicehub-grafana-critical` | Grafana unavailable | critical | `min(probe_success{...grafana...}) < 1` | 2m | Alerting | Alerting | 1 | Check Grafana container | Observability Health | Platform |
| `servicehub-alloy-critical` | Alloy unavailable | critical | `min(up{job="alloy"}) < 1` | 2m | Alerting | Alerting | 1 | Check Alloy container, `docker compose logs obsvcealloy` | Observability Health | Platform |
| `servicehub-alloy-config-failed` | Alloy configuration load failed | critical | `alloy_config_last_load_successful < 1` | 1m | Alerting | Alerting | 1 | Validate config: `docker compose logs obsvcealloy` | Observability Health | Platform |
| `servicehub-scrape-failure` | Prometheus scrape target down | critical | `min(up{job=~"obstack\|cadvisor\|traefik\|alloy\|internal\|public\|authentik_server\|authentik_worker\|ocis_proxy\|postgresql"}) < 1` | 3m | Alerting | Alerting | All up | Check target health, network | Observability Health | Platform |
| `servicehub-log-ingestion-stopped` | Log ingestion stopped | critical | `{project="servicehub"} \| stats count() < 1` (no logs in 5m) | 5m | Alerting | Alerting | >0 logs/min | Check Alloy→VLogs pipeline | Observability Health | Platform |

---

## NoData artifact investigation

Two rules were previously reported as producing persistent NoData artifacts:

### `servicehub-traefik-5xx` — **RESOLVED (correction applied in this closure)**
- **Prior state (Stage 8, commit 695acbd)**: Rule was split into queries A (5xx numerator) and B (total denominator) with a math expression C, but the condition query had a self-reference (`params: [C]`), causing Grafana to reject it with `expression 'C' cannot reference itself` — rule health `error`, unable to evaluate.
- **Root cause**: Copy/paste error in Stage 8 — when splitting the single ratio expression into A/B + math node C, the condition's `query.params` was not updated from `A` to `C`.
- **Correction applied**: Single-expression ratio `(sum(rate(5xx[5m])) or vector(0)) / clamp_min(sum(rate(all[5m])), 1)` with condition referencing query A. `or vector(0)` ensures the numerator yields 0 (not empty) when no 5xx series exist, so healthy state → Normal (not NoData). Validated live against VictoriaMetrics: returns 0 on healthy host.
- **Current state**: rule health `ok`, state `inactive` (Normal).

### `servicehub-fs-readonly` — **RESOLVED (Stage 8 fix verified correct)**
- **Prior state**: Rule used `node_filesystem_readonly{...} == 1` — PromQL filter, which returns empty when all filesystems are rw → NoData artifact.
- **Stage 8 fix**: Changed to `max(node_filesystem_readonly{...})` (raw metric, value 0 when healthy) with condition threshold > 0.5. Correct structure (expression `A`, `params: [A]`).
- **Current state**: rule health `ok`, state `inactive` (Normal). Correct: healthy filesystem → value 0 → Normal; read-only → value 1 → Firing.

**Both NoData artifacts are resolved. No suppression was applied to real firing conditions.**

---

## Verification

```bash
GP=$(docker exec servicehub-obsvcegrafana-1 printenv GF_SECURITY_ADMIN_PASSWORD)
GIP=$(docker inspect servicehub-obsvcegrafana-1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
curl -s -u "Captain.Li:$GP" \
  http://$GIP:3000/api/prometheus/grafana/api/v1/rules \
| jq '.data.groups[] | {name, rules: [.rules[] | {name, state, health}]}'
```

Expected: 3 groups, 27 rules, all health `ok` (firing/pending states are normal per host conditions).

---

## Tuning and rollback ownership

- **Alert expressions**: maintained by platform team; changes via PR to `shared/grafana/provisioning/alerting/servicehub.yml`.
- **Threshold tuning**: owner decision; document rationale in PR.
- **Rollback**: `git revert <commit>`; `docker compose up -d --no-deps --force-recreate obsvcegrafana`.
- **No telemetry deletion** on rollback.

---

## Related documents

- [Observability Operations Guide](observability.md) — pipeline, health checks
- [Metrics Catalogue](observability-metrics.md) — alert source formulas
- [Dashboard Catalogue](observability-dashboards.md) — panels that consume alerted metrics
- [Owner Review Checklist](observability-owner-review.md) — acceptance steps
