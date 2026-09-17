# Open WebUI — ServiceHub

> Browser interface for chatting with the LLM stack.

## Overview

[Open WebUI](https://docs.openwebui.com/) is a web-based interface for interacting with Large Language Models. It is defined by the `wbappwebchat` service in [`compose/wbapp.yml`](../../compose/wbapp.yml) and built from [`shared/openwebui/Dockerfile`](Dockerfile) (`FROM ghcr.io/open-webui/open-webui:main`). It can connect to the [LiteLLM proxy](../litellm/README.md) or directly to a [Hermes Agent](../hermesagent/README.md) gateway as an OpenAI-compatible endpoint.

## Service details

| Detail | Value |
|---|---|
| Service name | `wbappwebchat` |
| URL | `https://${OWEBUI_DOMAIN}` |
| Internal port | 8080 |
| Data persistence | `${APPS_DATA}/openwebui` (mounted at `/app/backend/data`) |
| Depends on | `routetraefik` (healthy) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `OWEBUI_DOMAIN` | Open WebUI hostname (e.g. `chats.example.com`) |

## Connecting to the LLM stack

Add a connection in Open WebUI → **Settings → Connections**:

| Target | API base URL | API key |
|---|---|---|
| LiteLLM proxy | `http://aiagnlitellm:12380/v1` | `${LITEM_API_KEY}` |
| Hermes gateway | `http://aiagnherm00:12330/v1` | `${LITEM_API_KEY}` |

When pointed at LiteLLM, requests use the `hermes` virtual model and are routed automatically by [`smartrouter.py`](../litellm/README.md). Pointing at a Hermes gateway talks to that user's agent directly.

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/app/backend/data` | `${APPS_DATA}/openwebui` | SQLite database, users, chats and model settings |

## Operations

```bash
# Start / restart
docker compose up -d wbappwebchat

# Follow logs
docker compose logs -f wbappwebchat
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM ghcr.io/open-webui/open-webui:main`) |

## See also

- [LiteLLM Proxy](../litellm/README.md) — unified LLM endpoint
- [Hermes Agent](../hermesagent/README.md) — agent workspaces and gateway
- [Confluence](../confluence/README.md) — the other service in `compose/wbapp.yml`
- [Root README — Web Applications](../../README.md#web-applications)
