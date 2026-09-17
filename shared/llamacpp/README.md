# llama.cpp Chat Inference — ServiceHub

> Fast, private, on-device Gemma chat model.

## Overview

[llama.cpp server](https://github.com/ggerganov/llama.cpp) with a Gemma 4 GGUF model provides the local inference tier (`hephaestus`) of the AI agent platform (`aiagn`). It is used for quick tasks, creative writing, translation, local RAG on private documents, and anything that must not leave the host. The `aiagnchatllm` service is defined in [`compose/aiagn.yml`](../../compose/aiagn.yml) and built from [`shared/llamacpp/Dockerfile`](Dockerfile) (`FROM ghcr.io/ggml-org/llama.cpp:server`).

## Service details

| Detail | Value |
|---|---|
| Service name | `aiagnchatllm` |
| Port | 12386 |
| Model | `unsloth/gemma-4-E4B-it-GGUF:Q4_K_M` (default, via `LLAMA_CHTMDL`) |
| Context | Configurable via `LLAMA_CHTARG` (default `--ctx-size 65536`, 64K) |
| Concurrent slots | `--parallel 4` (default) |
| Memory | `--mlock` + `IPC_LOCK` / unlimited memlock so the model stays in RAM |
| LiteLLM alias | `hephaestus` (env prefix `LITEM_HPH_*`) |
| Health check | `curl -f http://localhost:12386/health` (120 s start period) |

## Configuration

Set in `.env` (see [`env.example`](../../env.example)):

| Variable | Default | Description |
|---|---|---|
| `LLAMA_CHTMDL` | `unsloth/gemma-4-E4B-it-GGUF:Q4_K_M` | Chat inference model (hephaestus tier) |
| `LLAMA_CHTARG` | *(see env.example)* | Additional llama.cpp server flags |
| `HF_TOKEN` | *(empty)* | HuggingFace token — required for gated models |

Container settings applied by the compose file:

| Setting | Value | Purpose |
|---|---|---|
| `LLAMA_CACHE` | `/models` | Model cache directory |
| `LLAMA_MODEL` | `${LLAMA_CHTMDL}` | Model repo:quant passed to `--hf-repo` |
| `LLAMA_PORT` | `12386` | Listen port |
| `LLAMA_ARGS` | `${LLAMA_CHTARG}` | Extra server flags |
| `cap_add: IPC_LOCK` + `ulimits.memlock: -1` | | Required for `--mlock` inside Docker |

## Model download & caching

Models are auto-downloaded on first start via llama.cpp's `--hf-repo` flag and cached in `${APPS_DATA}/llamacpp` (mounted at `/models`). [`entrypoint.sh`](entrypoint.sh) first looks for `/models/<quant>.gguf` and loads it directly; if it is missing, it starts `llama-server --hf-repo <model>` to download and run.

## Operations

```bash
# Start / restart
docker compose up -d aiagnchatllm

# Follow logs (model download can take a while on first boot)
docker compose logs -f aiagnchatllm

# Health
curl -sf http://localhost:12386/health
```

## Files

| Path | Purpose |
|---|---|
| [`Dockerfile`](Dockerfile) | Image build (`FROM ghcr.io/ggml-org/llama.cpp:server`) |
| [`entrypoint.sh`](entrypoint.sh) | Reads `LLAMA_*` env vars, loads the cached model or downloads it |

## See also

- [LiteLLM Proxy](../litellm/README.md) — routes `hephaestus` to this service
- [Hermes Agent](../hermesagent/README.md) — consumes the `hermes` virtual model
- [Root README — AI Agent Platform](../../README.md#ai-agent-platform-aiagn)
