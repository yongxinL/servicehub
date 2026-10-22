# VictoriaMetrics — ServiceHub

> Fast, cost-effective time-series database for Prometheus-format metrics.

## Overview

[VictoriaMetrics](https://victoriametrics.com/products/open-source/) is the metrics store for the observability stack (`obsvce`). It receives metrics remote-written by [Grafana Alloy](../../../shared/grafana/alloy/README.md) and serves them to [Grafana](grafana.md). It is defined by the `obsvcevm` service in [`compose/obsvce.yml`](../../../compose/obsvce.yml) and built from [`shared/victoriametrics/Dockerfile`](../../../shared/victoriametrics/Dockerfile) (`FROM victoriametrics/victoria-metrics:latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcevm` |
| HTTP API port | 8428 (published to the host for remote Alloy/metrics push) |
| Data persistence | `${APPS_DATA}/obsvce/victoriametrics` (mounted at `/storage`) |
| Scrape config | None; Alloy is the single metrics ingestion path |
| Health check | `curl -fsS http://localhost:8428/health` every 30 s |
| Depended on by | `obsvcealloy` (healthy), `obsvcegrafana` (via Alloy) |

## Server flags

The service runs `victoria-metrics` with:

| Flag | Purpose |
|---|---|
| `--storageDataPath=/storage` | Persist time-series data on the host bind mount |
| `--httpListenAddr=:8428` | HTTP API / ingestion endpoint |
| `--enableTCP6=true` | Enable IPv6 |

## Ingestion topology

VictoriaMetrics does not directly scrape targets. Alloy pushes host, container, Traefik, and self metrics through `/api/v1/write` (see [`../grafana/alloy/config.alloy`](../../../shared/grafana/alloy/config.alloy)).

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/storage` | `${APPS_DATA}/obsvce/victoriametrics` | Time-series data and index |

## Operations

```bash
# Start / restart
docker compose up -d obsvcevm

# Follow logs
docker compose logs -f obsvcevm

# Query the API directly (host)
curl -s 'http://localhost:8428/api/v1/query?query=up' | jq .
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../../shared/victoriametrics/Dockerfile) | Image build (`FROM victoriametrics/victoria-metrics:latest`) + curl for health checks |
| [`config.alloy`](../../../shared/grafana/alloy/config.alloy) | Single authoritative metrics ingestion path |

## See also

- [VictoriaLogs](victorialogs.md) — log aggregation
- [Grafana Alloy](../../../shared/grafana/alloy/README.md) — collector pushing metrics here
- [Grafana](grafana.md) — dashboards
- [Root README — Observability](../../../README.md#observability-stack-obsvce)
