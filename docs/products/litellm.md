# LiteLLM Proxy — ServiceHub

> Unified LLM proxy and complexity router between local and cloud models.

## Overview

[LiteLLM](https://github.com/BerriAI/litellm) is the single LLM endpoint for the AI agent platform (`aiserv`). Every Hermes Agent request uses the virtual model `hermes`; [`smartrouter.py`](../../shared/litellm/smartrouter.py) rewrites each request to either `hephaestus` (local Gemma via [llama.cpp](llamacpp.md)) or `prometheus` (MiniMax cloud) before the provider call is made. The `aiservlitellm` service is defined in [`compose/aiserv.yml`](../../compose/aiserv.yml) and built from [`shared/litellm/Dockerfile`](../../shared/litellm/Dockerfile) (`FROM ghcr.io/berriai/litellm-database:main-latest`).

## Service details

| Detail | Value |
|---|---|
| Service name | `aiservlitellm` |
| Admin UI | `http://<host>:12380/ui` |
| Port | 12380 (UI + API + metrics) |
| Database | PostgreSQL (`${AIGATE_DBNAME}`, via `aiservlitellm` → `infrapgsql`) |
| Local tier | `hephaestus` → `aiservllamacpp` (Gemma-4, via `AIGATE_HERMES_*`) |
| Cloud tier | `prometheus` → MiniMax 2.7 (via `AIGATE_PROVIDER_*`) |
| Health check | `GET /health/liveliness` with Bearer token |
| Metrics | Prometheus `/metrics` on the UI port (scraped by VictoriaMetrics) |
| Config override | mount `${APPS_DATA}/aiserv/litellm/config.yaml` → `/opt/litellm/config.yaml` |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Default | Description |
|---|---|---|
| `AIGATE_API_KEY` | Auto-generated | Master API key (Bearer token `sk-...`) used by Hermes, FastCRW and other clients |
| `AIGATE_API_URL` | `http://aiservlitellm:12380/v1` | Base URL clients use to reach the proxy |
| `AIGATE_ADMIN_USER` | `admin` | Admin UI username |
| `AIGATE_ADMIN_PASSWORD` | | Admin UI password |
| `AIGATE_DBNAME` | `litellm` | PostgreSQL database for usage tracking |
| `AIGATE_HERMES_API_URL` | `http://aiservllamacpp:12386/v1` | Local (hephaestus) inference base URL |
| `AIGATE_HERMES_API_KEY` | `none` | Local inference API key |
| `AIGATE_HERMES_HEALTH_URL` | `http://aiservllamacpp:12386/health` | Local inference health-check URL |
| `AIGATE_PROVIDER_API_BASE` | `https://api.minimax.io/anthropic` | MiniMax Anthropic-compatible API base |
| `AIGATE_PROVIDER_API_KEY` | | MiniMax API key |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `LLM_MASTER_KEY` | `${AIGATE_API_KEY}` | Proxy master key |
| `DATABASE_URL` | `postgresql://…/${AIGATE_DBNAME}` | Usage/keys database |
| `UI_PORT` | `12380` | API/UI listen port |
| `UI_USERNAME` / `UI_PASSWORD` | `${AIGATE_ADMIN_USER}` / `${AIGATE_ADMIN_PASSWORD}` | Dashboard login |
| `LITEM_EDGE_*` / `LITEM_CLOUD_*` | from `AIGATE_HERMES_*` / `AIGATE_PROVIDER_*` (container-side LiteLLM names unchanged) | Provider routing targets |

## Routing logic

`smartrouter.py` intercepts `hermes` and rewrites the target model. The full keyword lists live in [`smartrouter.py`](../../shared/litellm/smartrouter.py); the rules are (first match wins):

| Signal | Destination |
|---|---|
| `[cloud]` or `[c]` prefix in message | prometheus — explicit user override |
| `[edge]` or `[e]` prefix in message | hephaestus — explicit user override |
| Local tier unhealthy | prometheus — auto-failover |
| Privacy keywords (`IEP`, `tax return`, `bank statement`, `medical record`, etc.) | hephaestus — data never leaves the host |
| Input > 50K tokens (~200 pages) | prometheus — large-document workload |
| Complexity keywords (root cause, system architecture, academic essay, curriculum map, etc.) | prometheus — formal / logic-heavy task |
| Default | hephaestus |

The explicit tags are stripped from the message before forwarding so the model never sees the routing instruction. [`config.default.yaml`](../../shared/litellm/config.default.yaml) adds safety nets:

- `context_window_fallbacks` — any request that overflows the local model's context window is escalated to prometheus.
- `fallbacks` — provider-failure routing sends each tier to the other on timeout or error.

## Configuration file

The image bakes in [`config.default.yaml`](../../shared/litellm/config.default.yaml). At startup [`entrypoint.sh`](../../shared/litellm/entrypoint.sh) copies it to `/opt/litellm/config.yaml` if no user override exists, so you can edit it in place:

```bash
docker compose exec aiservlitellm cat /app/config.default.yaml
# edit a copy, then place it at ${APPS_DATA}/aiserv/litellm/config.yaml and restart
docker compose restart aiservlitellm
```

## Operations

```bash
# Start / restart
docker compose up -d aiservlitellm

# Follow logs (routing decisions are logged)
docker compose logs -f aiservlitellm | grep route

# Liveness check
curl -sf -H "Authorization: Bearer ${AIGATE_API_KEY}" \
  http://localhost:12380/health/liveliness
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](../../shared/litellm/Dockerfile) | Image build + bakes config and routing callback |
| [`config.default.yaml`](../../shared/litellm/config.default.yaml) | Default model list, router settings, fallbacks |
| [`smartrouter.py`](../../shared/litellm/smartrouter.py) | Content-based routing hook (privacy + complexity) |
| [`entrypoint.sh`](../../shared/litellm/entrypoint.sh) | Seeds the user config and starts LiteLLM |

## See also

- [llama.cpp (hephaestus)](llamacpp.md) — local inference tier
- [Hermes Agent](hermesagent.md) — primary client (`model: hermes`)
- [FastCRW](fastcrw.md) — optional web-search backend for Hermes
- [PostgreSQL](postgresql.md) — usage database
- [Root README — AI Agent Platform](../../README.md#ai-agent-platform-aiserv)
