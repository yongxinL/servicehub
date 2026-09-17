# LiteLLM Proxy — ServiceHub

> Unified LLM proxy and complexity router between local and cloud models.

## Overview

[LiteLLM](https://github.com/BerriAI/litellm) is the single LLM endpoint for the AI agent platform (`aiagn`). Every Hermes Agent request uses the virtual model `hermes`; [`smartrouter.py`](smartrouter.py) rewrites each request to either `hephaestus` (local Gemma via [llama.cpp](../llamacpp/README.md)) or `prometheus` (MiniMax cloud) before the provider call is made. The `aiagnlitellm` service is defined in [`compose/aiagn.yml`](../../compose/aiagn.yml) and built from [`shared/litellm/Dockerfile`](Dockerfile) (`FROM ghcr.io/berriai/litellm-database:main-latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `aiagnlitellm` |
| Admin UI | `http://<host>:12380/ui` |
| Port | 12380 (UI + API + metrics) |
| Database | PostgreSQL (`${LITEM_DBNAME}`, via `aiagnlitellm` → `dbsvcpgsqldb`) |
| Local tier | `hephaestus` → `aiagnchatllm` (Gemma-4, via `LITEM_HPH_*`) |
| Cloud tier | `prometheus` → MiniMax 2.7 (via `LITEM_PRM_*`) |
| Health check | `GET /health/liveliness` with Bearer token |
| Metrics | Prometheus `/metrics` on the UI port (scraped by VictoriaMetrics) |
| Config override | mount `${APPS_DATA}/litellm/config.yaml` → `/opt/litellm/config.yaml` |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Default | Description |
|---|---|---|
| `LITEM_API_KEY` | Auto-generated | Master API key (Bearer token `sk-...`) used by Hermes, FastCRW and other clients |
| `LITEM_API_URL` | `http://aiagnlitellm:12380/v1` | Base URL clients use to reach the proxy |
| `LITEM_ADMUSR` | `admin` | Admin UI username |
| `LITEM_ADMPWD` | | Admin UI password |
| `LITEM_DBNAME` | `litellm` | PostgreSQL database for usage tracking |
| `LITEM_HPH_APIURL` | `http://aiagnchatllm:12386/v1` | Local (hephaestus) inference base URL |
| `LITEM_HPH_APIKEY` | `none` | Local inference API key |
| `LITEM_HPH_HLTURL` | `http://aiagnchatllm:12386/health` | Local inference health-check URL |
| `LITEM_PRM_APIBASE` | `https://api.minimax.io/anthropic` | MiniMax Anthropic-compatible API base |
| `LITEM_PRM_APIKEY` | | MiniMax API key |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `LLM_MASTER_KEY` | `${LITEM_API_KEY}` | Proxy master key |
| `DATABASE_URL` | `postgresql://…/${LITEM_DBNAME}` | Usage/keys database |
| `UI_PORT` | `12380` | API/UI listen port |
| `UI_USERNAME` / `UI_PASSWORD` | `${LITEM_ADMUSR}` / `${LITEM_ADMPWD}` | Dashboard login |
| `LITEM_EDGE_*` / `LITEM_CLOUD_*` | from `LITEM_HPH_*` / `LITEM_PRM_*` | Provider routing targets |

## Routing logic

`smartrouter.py` intercepts `hermes` and rewrites the target model. The full keyword lists live in [`smartrouter.py`](smartrouter.py); the rules are (first match wins):

| Signal | Destination |
|---|---|
| `[cloud]` or `[c]` prefix in message | prometheus — explicit user override |
| `[edge]` or `[e]` prefix in message | hephaestus — explicit user override |
| Local tier unhealthy | prometheus — auto-failover |
| Privacy keywords (`IEP`, `tax return`, `bank statement`, `medical record`, etc.) | hephaestus — data never leaves the host |
| Input > 50K tokens (~200 pages) | prometheus — large-document workload |
| Complexity keywords (root cause, system architecture, academic essay, curriculum map, etc.) | prometheus — formal / logic-heavy task |
| Default | hephaestus |

The explicit tags are stripped from the message before forwarding so the model never sees the routing instruction. [`config.default.yaml`](config.default.yaml) adds safety nets:

- `context_window_fallbacks` — any request that overflows the local model's context window is escalated to prometheus.
- `fallbacks` — provider-failure routing sends each tier to the other on timeout or error.

## Configuration file

The image bakes in [`config.default.yaml`](config.default.yaml). At startup [`entrypoint.sh`](entrypoint.sh) copies it to `/opt/litellm/config.yaml` if no user override exists, so you can edit it in place:

```bash
docker compose exec aiagnlitellm cat /app/config.default.yaml
# edit a copy, then place it at ${APPS_DATA}/litellm/config.yaml and restart
docker compose restart aiagnlitellm
```

## Operations

```bash
# Start / restart
docker compose up -d aiagnlitellm

# Follow logs (routing decisions are logged)
docker compose logs -f aiagnlitellm | grep route

# Liveness check
curl -sf -H "Authorization: Bearer ${LITEM_API_KEY}" \
  http://localhost:12380/health/liveliness
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build + bakes config and routing callback |
| [`config.default.yaml`](config.default.yaml) | Default model list, router settings, fallbacks |
| [`smartrouter.py`](smartrouter.py) | Content-based routing hook (privacy + complexity) |
| [`entrypoint.sh`](entrypoint.sh) | Seeds the user config and starts LiteLLM |

## See also

- [llama.cpp (hephaestus)](../llamacpp/README.md) — local inference tier
- [Hermes Agent](../hermesagent/README.md) — primary client (`model: hermes`)
- [FastCRW](../fastcrw/README.md) — optional web-search backend for Hermes
- [PostgreSQL](../postgresql/README.md) — usage database
- [Root README — AI Agent Platform](../../README.md#ai-agent-platform-aiagn)
