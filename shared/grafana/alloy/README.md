# Grafana Alloy — ServiceHub

> Telemetry collector for host metrics, container metrics, and logs.

## Overview

[Grafana Alloy](https://grafana.com/docs/alloy/) is the collector of the observability stack (`obsvc`). It gathers host metrics, container metrics and logs, enriches Traefik access logs with GeoIP data, and writes metrics to [VictoriaMetrics](../../victoriametrics/README.md) and logs to [VictoriaLogs](../../victorialogs/README.md). It is defined by the `obsvcgrafaly` service in [`compose/obsvc.yml`](../../../compose/obsvc.yml) and built from [`shared/grafana/alloy/Dockerfile`](Dockerfile) (`FROM grafana/alloy:latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcgrafaly` |
| HTTP API port | 9080 (internal only) |
| Config | [`config.alloy`](config.alloy) (mounted read-only at `/etc/alloy`) |
| Depends on | `obsvcvicmtrx` and `obsvcviclogs` (healthy) |
| Health check | `curl -fsS http://localhost:9080/health` every 30 s |
| Privileged | yes — cAdvisor needs the host `/proc`, `/sys` and Docker socket |

> **Privileged access:** The Alloy container runs in privileged mode (`--privileged`) because cAdvisor requires access to the host's `/proc`, `/sys`, and Docker socket to collect container metrics.

## Collectors and pipelines

| Pipeline | Source | Destination |
|---|---|---|
| Host metrics | built-in `unix` exporter (procfs/sysfs/rootfs) | VictoriaMetrics |
| Container metrics | built-in cAdvisor (`docker_only=true`) | VictoriaMetrics |
| Traefik metrics | scrape `routetraefik:8080` | VictoriaMetrics |
| LiteLLM metrics | scrape `aiagnlitellm:12380/metrics/` | VictoriaMetrics |
| Alloy self-metrics | scrape `localhost:9080` | VictoriaMetrics (log-derived counters) |
| Container logs | Docker socket discovery | VictoriaLogs (GeoIP-enriched) |

GeoIP enrichment uses [`../geoip/GeoLite2-City.mmdb`](../geoip/GeoLite2-City.mmdb) and generates `traefik_access_client_ip_requests_total` and `traefik_country_requests_total` counters. Private RFC-1918 IPs are assigned a fixed internal location since the GeoIP database has no entry for them.

## Mounts

| Container path | Host path | Purpose |
|---|---|---|
| `/etc/alloy` | [`shared/grafana/alloy`](.) | Alloy configuration |
| `/geoip/GeoLite2-City.mmdb` | [`shared/grafana/geoip`](../geoip) | GeoIP database |
| `/var/run/docker.sock` | host Docker socket (rw) | cAdvisor + log discovery |
| `/var/lib/docker` | host (ro) | cAdvisor container filesystem stats |
| `/host/proc`, `/host/sys`, `/rootfs` | host (ro) | unix exporter paths |
| `/sys/fs/cgroup` | host (ro) | cAdvisor cgroup stats |
| `/run/containerd/containerd.sock` | host (ro) | containerd discovery |

## Operations

```bash
# Start / restart
docker compose up -d obsvcgrafaly

# Follow logs
docker compose logs -f obsvcgrafaly

# Open the Alloy UI (host)
open http://localhost:9080
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM grafana/alloy:latest`) + curl for health checks |
| [`config.alloy`](config.alloy) | Collectors, scrape jobs, remote-write endpoints and log pipelines |

## See also

- [VictoriaMetrics](../../victoriametrics/README.md) — metrics destination
- [VictoriaLogs](../../victorialogs/README.md) — logs destination
- [Grafana](../README.md) — dashboards
- [Root README — Observability](../../../README.md#observability-stack-obsvc)
