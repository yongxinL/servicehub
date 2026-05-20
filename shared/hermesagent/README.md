# Hermes Agent — ServiceHub image

Build context for 4 hermesagent containers (`agsvcherme00`, `agsvcherme01`,
`agsvcherme02`, `agsvcherme03`). Wraps the upstream
[`nousresearch/hermes-agent`](https://hermes-agent.nousresearch.com) image with
ServiceHub-specific seeding, placeholder substitution, and an **overlay
system** for persisting source-code edits to `/opt/hermes` across container
recreation.

The full setup guide lives in [README.html](README.html) (open in a browser).
This file documents the overlay system and environment variables.

---

## Architecture

4 isolated hermesagent containers, one per user. Each container has:
- Own data directory (configurable via `HERMES_DATA_0X` in `.env`)
- Hermes Gateway on port 12330 (container-internal)
- Hermes Workspace on unique host port (12320-12323)
- Internal user profiles (code, research, etc.) via `hermes profile create`
- No dashboard (Hermes CLI and Workspace cover all dashboard functionality)

| Container | Workspace Port | Data Directory |
|-----------|---------------|----------------|
| `agsvcherme00` | 12320 | `${HERMES_DATA_00:-${APPS_DATA}/hermesagent/data/00}` |
| `agsvcherme01` | 12321 | `${HERMES_DATA_01:-${APPS_DATA}/hermesagent/data/01}` |
| `agsvcherme02` | 12322 | `${HERMES_DATA_02:-${APPS_DATA}/hermesagent/data/02}` |
| `agsvcherme03` | 12323 | `${HERMES_DATA_03:-${APPS_DATA}/hermesagent/data/03}` |

---

## Volumes

| Container path | Host path | Purpose |
|---|---|---|
| `/opt/data` | `${HERMES_DATA_0X}` | Hermes data (`$HOME`: profiles, sessions, memory, `.env`, `config.yaml`) |
| `/opt/data/overlay` | `${HERMES_DATA_0X}/overlay` | Persisted edits to `/opt/hermes` (see below) |
| `/var/run/docker.sock` | host docker socket (ro) | Terminal sandbox spawning |

`/opt/hermes` (~1.4 GB) is **not** mounted — it ships with the image as a
read-only baseline. The overlay system replays your changes onto it at start.

---

## Overlay system

Hermes (or you) can modify files under `/opt/hermes` inside the container —
but those edits live in the container's writable layer and disappear on
`docker compose down` / `up` / `--build`. The overlay system fixes that by
storing the edits on the host and replaying them at startup.

### Layout

```
${HERMES_DATA_0X}/overlay/
├── files/      # sparse mirror of /opt/hermes — saved files replayed at start
├── originals/  # pristine "before" copies for diff generation
└── patches/    # *.patch files applied after files/, in lexical order
```

### Apply flow (at container start)

`start-gateways.sh` calls `apply-overlay.sh` before launching any hermes
process:

1. `rsync overlay/files/ → /opt/hermes/` — bulk file overlays first
2. `patch -p1` each `overlay/patches/*.patch` in lexical order

### Tools (available inside each container, on `PATH`)

| Command | When | Effect |
|---|---|---|
| `overlay-track <path>` | **Before** editing | Snapshots current `/opt/hermes/<path>` into `overlay/originals/<path>` (idempotent — never overwrites an existing baseline). |
| `overlay-save <path>` | **After** editing | Copies current `/opt/hermes/<path>` into `overlay/files/<path>` so it's replayed at next start. Auto-tracks a baseline if none exists. |
| `overlay-patch <name>` | Anytime | Diffs `originals/` vs `files/` and writes `overlay/patches/<name>.patch`. Use to export changes as a portable diff. |
| `apply-overlay.sh` | Auto at start | Replays `files/` then `patches/` onto `/opt/hermes`. |

All accept paths absolute (`/opt/hermes/foo/bar.py`) or relative (`foo/bar.py`).

### Typical workflow

```bash
# 1. Before editing — snapshot the baseline
docker compose exec agsvcherme00 overlay-track /opt/hermes/agent/router.py

# 2. Edit the file (you, or hand the task to the agent)
docker compose exec -it agsvcherme00 nano /opt/hermes/agent/router.py

# 3. After editing — persist the change
docker compose exec agsvcherme00 overlay-save /opt/hermes/agent/router.py

# 4. Recreate the container — your edit comes back automatically
docker compose up -d --force-recreate agsvcherme00
docker compose logs agsvcherme00 | grep '\[overlay\]'
```

### Disabling the overlay

The overlay folder is auto-created empty on first start. To disable
entirely, leave it empty — `apply-overlay.sh` no-ops when both `files/`
and `patches/` are empty.

---

## Hermes Workspace

The image bundles [Hermes Workspace](https://github.com/outsourc-e/hermes-workspace)
(a web UI for Hermes Agent) alongside the gateway.

**Access:** `http://<host-ip>:12320` (agsvcherme00), `12321` (agsvcherme01), etc.

**Login:** Use `HERMES_WORKSPACE_PASSWD_00`, `_01`, `_02`, `_03` from root `.env`.

**Environment variables (per container):**

| Variable | Default | Description |
|---|---|---|
| `HERMES_WORKSPACE_PORT` | `12320` | Workspace listen port (container-internal) |
| `HERMES_WORKSPACE_PASSWORD` | (from `HERMES_WORKSPACE_PASSWD_0X`) | Login password |
| `HERMES_DATA_0X` | `${APPS_DATA}/hermesagent/data/0X` | Data directory path |
| `HERMES_WORKSPACE_DOMAIN_0X` | (empty) | Traefik domain for HTTPS access |

**Internal user profiles:** Each container supports internal profiles
(code, research, etc.) via `hermes profile create`. These are separate
from messaging platform setup — no Discord/WhatsApp config needed.

---

## Configuration in .env

```bash
# Workspace passwords (required for login)
HERMES_WORKSPACE_PASSWD_00=<password>
HERMES_WORKSPACE_PASSWD_01=<password>
HERMES_WORKSPACE_PASSWD_02=<password>
HERMES_WORKSPACE_PASSWD_03=<password>

# Data directories (optional — defaults shown)
HERMES_DATA_00=${APPS_DATA}/hermesagent/data/00
HERMES_DATA_01=${APPS_DATA}/hermesagent/data/01
HERMES_DATA_02=${APPS_DATA}/hermesagent/data/02
HERMES_DATA_03=${APPS_DATA}/hermesagent/data/03

# Optional: Traefik domains for HTTPS
HERMES_WORKSPACE_DOMAIN_00=hermes00.local
HERMES_WORKSPACE_DOMAIN_01=hermes01.local
HERMES_WORKSPACE_DOMAIN_02=hermes02.local
HERMES_WORKSPACE_DOMAIN_03=hermes03.local
```