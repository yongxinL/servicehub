# VictoriaMetrics — ServiceHub

> Fast, cost-effective time-series database for Prometheus-format metrics.

## Overview

[VictoriaMetrics](https://victoriametrics.com/products/open-source/) is the metrics store for the observability stack (`obsvc`). It receives metrics pushed by [Grafana Alloy](../grafana/alloy/README.md) and stored by Prometheus scrape jobs, and serves them to [Grafana](../grafana/README.md). It is defined by the `obsvcvicmtrx` service in [`compose/obsvc.yml`](../../compose/obsvc.yml) and built from [`shared/victoriametrics/Dockerfile`](Dockerfile) (`FROM victoriametrics/victoria-metrics:latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcvicmtrx` |
| HTTP API port | 8428 (published to the host for remote Alloy/metrics push) |
| Data persistence | `${APPS_DATA}/victoriametrics` (mounted at `/storage`) |
| Scrape config | [`scrape.yaml`](scrape.yaml) (mounted read-only at `/etc/vm/scrape.yaml`) |
| Health check | `curl -fsS http://localhost:8428/health` every 30 s |
| Depended on by | `obsvcgrafaly` (healthy), `obsvcgrafana` (via Alloy) |

## Server flags

The service runs `victoria-metrics` with:

| Flag | Purpose |
|---|---|
| `--storageDataPath=/storage` | Persist time-series data on the host bind mount |
| `--httpListenAddr=:8428` | HTTP API / ingestion endpoint |
| `--promscrape.config=/etc/vm/scrape.yaml` | Scrape targets from [`scrape.yaml`](scrape.yaml) |
| `--promscrape.config.strictParse=false` | Tolerate fields newer than the binary |
| `--enableTCP6=true` | Enable IPv6 |

## Scrape targets

VictoriaMetrics scrapes two endpoints itself (in addition to metrics pushed by Alloy):

| Job | Target | Path |
|---|---|---|
| `alloy` | `obsvcgrafaly:9080` | `/metrics` |
| `litellm` | `aiagnlitellm:12380` | `/metrics` |

Alloy pushes host, container and Traefik metrics through `/api/v1/write` (see [`../grafana/alloy/config.alloy`](../grafana/alloy/config.alloy)), so most metrics arrive by remote write rather than scrape.

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/storage` | `${APPS_DATA}/victoriametrics` | Time-series data and index |

## Operations

```bash
# Start / restart
docker compose up -d obsvcvicmtrx

# Follow logs
docker compose logs -f obsvcvicmtrx

# Query the API directly (host)
curl -s 'http://localhost:8428/api/v1/query?query=up' | jq .
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM victoriametrics/victoria-metrics:latest`) + curl for health checks |
| [`scrape.yaml`](scrape.yaml) | Prometheus scrape configuration for Alloy and LiteLLM |

## See also

- [VictoriaLogs](../victorialogs/README.md) — log aggregation
- [Grafana Alloy](../grafana/alloy/README.md) — collector pushing metrics here
- [Grafana](../grafana/README.md) — dashboards
- [Root README — Observability](../../README.md#observability-stack-obsvc)
