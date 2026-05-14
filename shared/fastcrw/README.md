# FastCRW

FastCRW is a self-hosted, Firecrawl-compatible web scraping and search service written in Rust. It is a drop-in replacement for the Firecrawl cloud API, designed for low-latency, high-throughput content extraction with a three-tier renderer pipeline and a built-in web search endpoint backed by SearXNG.

Upstream: [github.com/us/crw](https://github.com/us/crw)

---

## Services

This deployment runs four containers together:

| Container | Role | Internal address |
|---|---|---|
| `agsvcfastcrw` | FastCRW API server | `http://agsvcfastcrw:12360` |
| `agsvclighpda` | LightPanda JS renderer (lightweight) | `ws://agsvclighpda:9222` |
| `agsvcchromum` | Browserless/Chromium renderer (stealth) | `ws://agsvcchromum:12363` |
| `agsvcsearxng` | SearXNG search engine sidecar | `http://agsvcsearxng:12361` |

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — no auth required |
| `POST` | `/v1/scrape` | Scrape a single URL to markdown, HTML, or JSON |
| `POST` | `/v1/crawl` | Start an async BFS crawl (returns a job ID) |
| `GET` | `/v1/crawl/:id` | Poll crawl status and retrieve results |
| `DELETE` | `/v1/crawl/:id` | Cancel a running crawl job |
| `POST` | `/v1/map` | Discover all URLs on a site |
| `POST` | `/v1/search` | Web search via SearXNG with optional content scraping |
| `POST` | `/mcp` | Streamable HTTP MCP transport |

### Renderer tiers

FastCRW selects a renderer automatically per request and escalates on failure:

```
HTTP (4 s) → LightPanda (2.5 s) → Chrome (30 s)
```

- **HTTP** — plain fetch; fastest, no JS execution.
- **LightPanda** — lightweight JS renderer (~64 MB). Handles most SPAs. Can segfault on heavy pages; the container auto-restarts.
- **Chrome** — browserless/Chromium with anti-fingerprint stealth plugin. Used for Cloudflare Turnstile, DataDome, and other bot-detection pages. Resource interception (images, fonts, media, ads) is enabled to cut per-render latency.

A per-request `renderer` field overrides auto-selection: `"auto"` | `"http"` | `"lightpanda"` | `"chrome"`.

---

## Changes from upstream defaults

### 1. Dynamic API key via environment variable

**Problem:** config-rs cannot override a TOML array (`api_keys = [...]`) via a flat environment variable — it parses the value as a string instead of a sequence, so `CRW_AUTH__API_KEYS=sk-...` silently fails.

**Solution:** An `entrypoint.sh` wrapper runs `envsubst` on `config.docker.toml` before starting `crw-server`, writing the result to `/app/config.active.toml`. The app is then pointed at the generated file via `CRW_CONFIG=config.active`.

Files changed:
- `entrypoint.sh` — new; performs substitution and execs `crw-server`
- `Dockerfile` — installs `gettext-base` (for `envsubst`), sets `ENTRYPOINT` + `CMD`
- `config.docker.toml` — `api_keys` now holds `["${FIRECRAWL_API_KEY}"]` placeholder

### 2. Shared API key — no separate credential needed

`FIRECRAWL_API_KEY` in `compose/agent.yml` defaults to `${LITEM_APIKEY}` via shell fallback (`:-`). This means you do not need to set a separate key in `.env`; FastCRW and the Hermes agent share the same master key automatically. Set `FIRECRAWL_API_KEY` in `.env` explicitly only if you need a distinct credential.

### 3. Port

FastCRW is exposed on **12360** (upstream default is 3000).

### 4. Rate limiting

Global RPS cap is disabled (`rate_limit_rps = 0`) to avoid throttling under benchmark and production load. Per-host rate limiting (`CRW_CRAWLER__REQUESTS_PER_SECOND=5.0`) is still enforced at the crawler level.

### 5. Renderer timeouts (tuned from bench analysis)

| Tier | Timeout | Reason |
|---|---|---|
| HTTP | 4 s | Fail fast into JS escalation |
| LightPanda | 2.5 s | Give Chrome ≥3 s residual under the 8 s deadline |
| Chrome nav budget | 12 s | Partial-DOM snapshot returned on hit |
| End-to-end deadline | 15 s | Recovers slow gov/legal SPAs without ballooning p50 |

---

## Testing

All commands below run against the published port on the host. Replace `$KEY` with your `LITEM_APIKEY` value, or export it first:

```bash
KEY=$(grep LITEM_APIKEY .env | cut -d= -f2 | tr -d '"')
```

### Health check

```bash
curl -sf http://localhost:12360/health | jq .
```

### Verify API key auth

```bash
# Correct key — should return 200 with scraped content
curl -s http://localhost:12360/v1/scrape \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}' | jq '.data.markdown | .[0:200]'

# Wrong key — should return 401
curl -si http://localhost:12360/v1/scrape \
  -H "Authorization: Bearer wrong-key" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}' | head -1
```

Confirm the entrypoint substituted the key correctly (should show the real key, not the placeholder):

```bash
docker compose exec agsvcfastcrw \
  grep api_keys /app/config.active.toml
```

### Scrape — auto renderer

```bash
curl -s http://localhost:12360/v1/scrape \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","formats":["markdown"]}' \
  | jq '{renderer: .data.renderDecision, preview: .data.markdown[0:300]}'
```

The `renderDecision.chain` field shows which tier(s) were tried.

### Scrape — force LightPanda (agsvclighpda)

```bash
curl -s http://localhost:12360/v1/scrape \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","renderer":"lightpanda"}' \
  | jq '{renderer: .data.renderDecision, bytes: (.data.markdown | length)}'
```

Check LightPanda logs if this fails:

```bash
docker compose logs agsvclighpda --tail 30
```

### Scrape — force Chrome (agsvcchromum)

```bash
curl -s http://localhost:12360/v1/scrape \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","renderer":"chrome"}' \
  | jq '{renderer: .data.renderDecision, bytes: (.data.markdown | length)}'
```

Chrome communicates with `agsvcchromum` on the internal Docker network using `LITEM_APIKEY` as the browserless `TOKEN`. If Chrome fails, check:

```bash
docker compose logs agsvcchromum --tail 30
```

### Search (via SearXNG)

```bash
# Returns result links only
curl -s http://localhost:12360/v1/search \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"rust web scraper 2026","limit":5}' \
  | jq '.data[] | .url'

# Search and scrape each result to markdown
curl -s http://localhost:12360/v1/search \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "rust async runtime",
    "limit": 3,
    "scrapeOptions": {"formats": ["markdown"]}
  }' | jq '.data[] | {url, preview: .markdown[0:150]}'
```

### Crawl

```bash
# Start crawl, get job ID
JOB=$(curl -s http://localhost:12360/v1/crawl \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","limit":10}' | jq -r '.id')

# Poll for results
curl -s http://localhost:12360/v1/crawl/$JOB \
  -H "Authorization: Bearer $KEY" | jq '{status: .status, pages: (.data | length)}'
```

### URL discovery (map)

```bash
curl -s http://localhost:12360/v1/map \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://firecrawl.dev"}' | jq '.links[0:10]'
```
