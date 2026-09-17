# Grafana — ServiceHub

> Dashboards for visualizing metrics and logs.

## Overview

[Grafana](https://grafana.com/) is the visualization layer of the observability stack (`obsvc`). It reads metrics from [VictoriaMetrics](../victoriametrics/README.md) and logs from [VictoriaLogs](../victorialogs/README.md). The `obsvcgrafana` service is defined in [`compose/obsvc.yml`](../../compose/obsvc.yml) and built from [`shared/grafana/Dockerfile`](Dockerfile) (`FROM grafana/grafana:latest`). A one-shot `obsvcgrafint` container fixes data-directory ownership before Grafana starts.

## Service details

| Detail | Value |
|---|---|
| Service name | `obsvcgrafana` (+ one-shot `obsvcgrafint`) |
| URL | `https://${OBSVC_DOMAIN}` |
| Internal port | 3000 |
| Database | SQLite (embedded, persisted to `${APPS_DATA}/grafana`) |
| Data sources | VictoriaMetrics (`obsvcvicmtrx:8428`), VictoriaLogs (`obsvcviclogs:9428`) |
| Auth | Authentik forward-auth (`authentik-forwardauth@file`) |
| Plugin | `victoriametrics-logs-datasource` |
| Depends on | `routetraefik`, `obsvcgrafint`, `obsvcgrafaly` |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `OBSVC_DOMAIN` | Grafana hostname (e.g. `stats.example.com`) |
| `OBSVC_ADMUSR` | Grafana admin username |
| `OBSVC_ADMPWD` | Grafana admin password |

Grafana settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `GF_SECURITY_ADMIN_USER` / `GF_SECURITY_ADMIN_PASSWORD` | `${OBSVC_ADMUSR}` / `${OBSVC_ADMPWD}` | Local admin account |
| `GF_SERVER_DOMAIN` / `GF_SERVER_ROOT_URL` | `${OBSVC_DOMAIN}` | Correct URLs behind Traefik |
| `GF_USERS_ALLOW_SIGN_UP` | `false` | No self-registration |
| `GF_INSTALL_PLUGINS` | `victoriametrics-logs-datasource` | Logs datasource |

## Provisioning

Both provisioning files are mounted read-only from [`provisioning/`](provisioning):

| File | Purpose |
|---|---|
| [`provisioning/datasources/datasources.yml`](provisioning/datasources/datasources.yml) | VictoriaMetrics (default) and VictoriaLogs data sources |
| [`provisioning/dashboards/dashboards.yml`](provisioning/dashboards/dashboards.yml) | Loads dashboards from `/var/lib/grafana/dashboards` |

Pre-built dashboards in [`dashboards/`](dashboards) are mounted at `/var/lib/grafana/dashboards/observability` and include:

- Node Exporter Full
- Docker Dashboard / Docker Containers Overview
- cAdvisor Explorer / cAdvisor Dashboard
- Traefik Dashboard / Traefik Observability
- VictoriaMetrics Overview
- LiteLLM Proxy
- VictoriaLogs Explorer / VictoriaLogs Internal State

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/var/lib/grafana` | `${APPS_DATA}/grafana` | SQLite database, users, settings, local dashboard edits |

`obsvcgrafint` runs as root and normalizes ownership to UID/GID `472` (the Grafana user) and permissions to `775` on every boot, so the bind mount stays writable.

## Operations

```bash
# Start / restart
docker compose up -d obsvcgrafana

# Follow logs
docker compose logs -f obsvcgrafana

# Re-run the ownership fix
docker compose up obsvcgrafint
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM grafana/grafana:latest`) |
| [`provisioning/`](provisioning) | Data source and dashboard provisioning |
| [`dashboards/`](dashboards) | Pre-built dashboard JSON |
| [`alloy/`](alloy) | Grafana Alloy collector — see [alloy/README.md](alloy/README.md) |
| [`geoip/`](geoip) | GeoIP database used by Alloy log enrichment |

## See also

- [VictoriaMetrics](../victoriametrics/README.md) — metrics data source
- [VictoriaLogs](../victorialogs/README.md) — logs data source
- [Grafana Alloy](alloy/README.md) — collector
- [Authentik](../authentik/README.md) — forward-auth
- [Root README — Observability](../../README.md#observability-stack-obsvc)
