# Open WebUI — ServiceHub

> Browser interface for chatting with the LLM stack.

## Overview

[Open WebUI](https://docs.openwebui.com/) is a web-based interface for interacting with Large Language Models. It is defined by the `aiservowui` service in [`compose/aiserv.yml`](../../compose/aiserv.yml) and built from [`shared/openwebui/Dockerfile`](Dockerfile) (`FROM ghcr.io/open-webui/open-webui:main`). It can connect to the [LiteLLM proxy](../litellm/README.md) or directly to a [Hermes Agent](../hermesagent/README.md) gateway as an OpenAI-compatible endpoint. Per [ADR-009](../../docs/adr/ADR-009-rescope-oci-deployment-and-harden-platform-boundaries.md) Open WebUI runs on local infrastructure with the rest of the AI platform and is not deployed to OCI.

## Service details

| Detail | Value |
|---|---|
| Service name | `aiservowui` |
| URL | `https://${CHAT_DOMAIN}` |
| Internal port | 8080 |
| Data persistence | `${APPS_DATA}/aiserv/openwebui` (mounted at `/app/backend/data`) |
| Depends on | `routetraefik` (healthy) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Description |
|---|---|
| `CHAT_DOMAIN` | Open WebUI hostname (e.g. `chats.example.com`) |

## Connecting to the LLM stack

Add a connection in Open WebUI → **Settings → Connections**:

| Target | API base URL | API key |
|---|---|---|
| LiteLLM proxy | `http://aiservlitellm:12380/v1` | `${AIGATE_API_KEY}` |
| Hermes gateway | `http://aiservhermes:12330/v1` | `${AIGATE_API_KEY}` |

When pointed at LiteLLM, requests use the `hermes` virtual model and are routed automatically by [`smartrouter.py`](../litellm/README.md). Pointing at a Hermes gateway talks to that user's agent directly.

## Data & persistence

| Container path | Host path | Purpose |
|---|---|---|
| `/app/backend/data` | `${APPS_DATA}/aiserv/openwebui` | SQLite database, users, chats and model settings |

## Operations

```bash
# Start / restart
docker compose up -d aiservowui

# Follow logs
docker compose logs -f aiservowui
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM ghcr.io/open-webui/open-webui:main`) |

## See also

- [LiteLLM Proxy](../litellm/README.md) — unified LLM endpoint
- [Hermes Agent](../hermesagent/README.md) — agent workspaces and gateway
- [Root README — AI Agent Platform](../../README.md#ai-agent-platform-aiserv)
