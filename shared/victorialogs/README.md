# VictoriaLogs — ServiceHub

> Lightweight log aggregation with a simple query interface.

## Overview

[VictoriaLogs](https://victoriametrics.com/products/victorialogs/) is the log store for the observability stack (`obsvce`). It receives container and Traefik access logs from [Grafana Alloy](../grafana/alloy/README.md) and is queried from [Grafana](../grafana/README.md) through the `victoriametrics-logs-datasource` plugin. It is defined by the `obsvcevlogs` service in [`compose/obsvce.yml`](../../compose/obsvce.yml) and built from [`shared/victorialogs/Dockerfile`](Dockerfile) (`FROM victoriametrics/victoria-logs:latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcevlogs` |
| HTTP API port | 9428 (published to the host for remote Alloy/log push) |
| Data persistence | `${APPS_DATA}/obsvce/victorialogs` (mounted at `/vlogs`) |
| Log source | Grafana Alloy — Docker logs, container stats, Traefik access logs |
| Health check | `curl -fsS http://localhost:9428/health` every 30 s |
| Depended on by | `obsvcealloy` (healthy), `obsvcegrafana` (via Alloy) |

## Server flags

| Flag | Purpose |
|---|---|
| `--storageDataPath=/vlogs` | Persist log data on the host bind mount |
| `--httpListenAddr=:9428` | HTTP API / ingestion endpoint |

## Ingestion

Alloy pushes logs to the Loki-compatible endpoint:

```
http://obsvcevlogs:9428/insert/loki/api/v1/push
```

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/vlogs` | `${APPS_DATA}/obsvce/victorialogs` | Log data and index |

## Operations

```bash
# Start / restart
docker compose up -d obsvcevlogs

# Follow logs
docker compose logs -f obsvcevlogs

# Query recent logs (host)
curl -s 'http://localhost:9428/select/logsql/query' \
  -d 'query=*' -d 'limit=5'
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM victoriametrics/victoria-logs:latest`) + curl for health checks |

## See also

- [VictoriaMetrics](../victoriametrics/README.md) — metrics store
- [Grafana Alloy](../grafana/alloy/README.md) — collector shipping logs here
- [Grafana](../grafana/README.md) — dashboards and log exploration
- [Root README — Observability](../../README.md#observability-stack-obsvce)
