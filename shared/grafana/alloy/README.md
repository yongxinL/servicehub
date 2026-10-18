# Grafana Alloy — ServiceHub

> Telemetry collector for host metrics, container metrics, and logs.

## Overview

[Grafana Alloy](https://grafana.com/docs/alloy/) is the collector of the observability stack (`obsvce`). It gathers host metrics, container metrics and logs, enriches Traefik access logs with GeoIP data, and writes metrics to [VictoriaMetrics](../../../docs/operations/services/victoriametrics.md) and logs to [VictoriaLogs](../../../docs/operations/services/victorialogs.md). It is defined by the `obsvcealloy` service in [`compose/obsvce.yml`](../../../compose/obsvce.yml) and built from [`shared/grafana/alloy/Dockerfile`](Dockerfile) (`FROM grafana/alloy:latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcealloy` |
| HTTP API port | 9080 (internal only) |
| Config | [`config.alloy`](config.alloy) (mounted read-only at `/etc/alloy`) |
| Depends on | `obsvcevm` and `obsvcevlogs` (healthy) |
| Health check | `curl -fsS http://localhost:9080/health` every 30 s |
| Privileged | yes — cAdvisor needs the host `/proc`, `/sys` and Docker socket |

> **Privileged access:** The Alloy container runs in privileged mode (`--privileged`) because cAdvisor requires access to the host's `/proc`, `/sys`, and Docker socket to collect container metrics.

## Collectors and pipelines

| Pipeline | Source | Destination |
|---|---|---|
| Host metrics | built-in `unix` exporter (procfs/sysfs; host filesystem collection is expanded under ADR-010) | VictoriaMetrics |
| Container metrics | built-in cAdvisor (`docker_only=true`) | VictoriaMetrics |
| Traefik metrics | scrape `routetraefik:8080` | VictoriaMetrics |
| Alloy self-metrics | scrape `localhost:9080` | VictoriaMetrics (single authoritative ingestion path) |
| Host journal | selective SSH, sudo, logind, kernel, Docker, systemd, and firewalld matches | VictoriaLogs |
| Container logs | Docker socket discovery, secret filtering, GeoIP | VictoriaLogs |
| Internal probes | documented readiness endpoints | VictoriaMetrics |
| Public probes | HTTPS, DNS, and TLS | VictoriaMetrics |

GeoIP enrichment uses [`../geoip/GeoLite2-City.mmdb`](../geoip/GeoLite2-City.mmdb) and retains client IP, city, and coordinate detail as structured metadata. Only country code is retained as a bounded VictoriaLogs stream label; individual client IPs are not promoted to metric labels.

## Mounts

| Container path | Host path | Purpose |
|---|---|---|
| `/etc/alloy` | [`shared/grafana/alloy`](.) | Alloy configuration |
| `/geoip/GeoLite2-City.mmdb` | [`shared/grafana/geoip`](../geoip) | GeoIP database |
| `/host/root` | host `/` (ro) | filesystem and inode metrics; broad read boundary |
| `/var/run/docker.sock` | host Docker socket (rw) | cAdvisor + log discovery |
| `/host/proc`, `/host/sys` | host (ro) | unix exporter paths |
| `/sys/fs/cgroup` | host (ro) | cAdvisor cgroup stats |
| `/var/log/journal`, `/run/log/journal` | host journal (ro) | selective journald sources |
| `/etc/machine-id` | host machine ID (ro) | journal discovery |

ADR-010 supersedes the relevant ADR-008 mount restriction for this observability collector. The host root is mounted read-only; `/var/lib/docker` and the containerd socket are not separately mounted.

## Operations

```bash
# Start / restart
docker compose up -d obsvcealloy

# Follow logs
docker compose logs -f obsvcealloy

# Open the Alloy UI (host)
open http://localhost:9080
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM grafana/alloy:latest`) + curl for health checks |
| [`config.alloy`](config.alloy) | Collectors, scrape jobs, remote-write endpoints and log pipelines |

## See also

- [VictoriaMetrics](../../../docs/operations/services/victoriametrics.md) — metrics destination
- [VictoriaLogs](../../../docs/operations/services/victorialogs.md) — logs destination
- [Grafana](../../../docs/operations/services/grafana.md) — dashboards
- [Root README — Observability](../../../README.md#observability-stack-obsvce)
