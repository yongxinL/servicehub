# Hermes Agent — ServiceHub image

Build context for the `aiagnherm00` hermesagent container. Wraps the upstream
[`nousresearch/hermes-agent`](https://hermes-agent.nousresearch.com) image with
ServiceHub-specific seeding, placeholder substitution, and an **overlay
system** for persisting source-code edits to `/opt/hermes` across container
recreation.

The full setup guide lives in [README.html](README.html) (open in a browser).
This file documents the overlay system, environment variables, and how to scale
the platform to more users.

---

## Architecture

A single Hermes Agent container. It has:
- Its own data directory (configurable via `HERMES_DATA_00` in `.env`)
- Hermes Gateway on port 12330 (container-internal)
- Hermes Workspace on host port 12320
- Internal user profiles (code, research, etc.) via `hermes profile create`
- No dashboard (Hermes CLI and Workspace cover all dashboard functionality)

| Container | Workspace Port | Data Directory |
|-----------|---------------|----------------|
| `aiagnherm00` | 12320 | `${HERMES_DATA_00:-${APPS_DATA}/hermesagent/00}` |

> Hermes is **single-user / single-tenant**. Anyone who logs into the workspace
> shares the same agent memory, sessions and skills. See
> [Multi-user support](#multi-user-support) for how to serve more people.

---

## Volumes

| Container path | Host path | Purpose |
|---|---|---|
| `/opt/data` | `${HERMES_DATA_00}` | Hermes data (`$HOME`: profiles, sessions, memory, `.env`, `config.yaml`) |
| `/opt/data/overlay` | `${HERMES_DATA_00}/overlay` | Persisted edits to `/opt/hermes` (see below) |
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
${HERMES_DATA_00}/overlay/
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
docker compose exec aiagnherm00 overlay-track /opt/hermes/agent/router.py

# 2. Edit the file (you, or hand the task to the agent)
docker compose exec -it aiagnherm00 nano /opt/hermes/agent/router.py

# 3. After editing — persist the change
docker compose exec aiagnherm00 overlay-save /opt/hermes/agent/router.py

# 4. Recreate the container — your edit comes back automatically
docker compose up -d --force-recreate aiagnherm00
docker compose logs aiagnherm00 | grep '\[overlay\]'
```

### Disabling the overlay

The overlay folder is auto-created empty on first start. To disable
entirely, leave it empty — `apply-overlay.sh` no-ops when both `files/`
and `patches/` are empty.

---

## Hermes Workspace

The image bundles [Hermes Workspace](https://github.com/outsourc-e/hermes-workspace)
(a web UI for Hermes Agent) alongside the gateway.

**Access:** `http://<host-ip>:12320`

**Login:** Use `HERMES_WORKSPACE_PASSWD_00` from the root `.env`.

**Environment variables (per container):**

| Variable | Default | Description |
|---|---|---|
| `HERMES_WORKSPACE_PORT` | `12320` | Workspace listen port (container-internal) |
| `HERMES_WORKSPACE_PASSWORD` | (from `HERMES_WORKSPACE_PASSWD_00`) | Login password |
| `HERMES_DATA_00` | `${APPS_DATA}/hermesagent/00` | Data directory path |
| `HERMES_WORKSPACE_DOMAIN_00` | (empty) | Traefik domain for HTTPS access |

**Internal user profiles:** Each container supports internal profiles
(code, research, etc.) via `hermes profile create`. These are separate
from messaging platform setup — no Discord/WhatsApp config needed.

---

## Configuration in .env

```bash
# Workspace password (required for login)
HERMES_WORKSPACE_PASSWD_00=<password>

# Data directory (optional — default shown)
HERMES_DATA_00=${APPS_DATA}/hermesagent/00

# Optional: Traefik domain for HTTPS
HERMES_WORKSPACE_DOMAIN_00=space0.${DOMAIN_NAME}
```

---

## Multi-user support

**Hermes Agent is single-user / single-tenant — one container, one login, one
shared agent identity.** This is confirmed by upstream design:

- There is **no account system and no per-end-user isolation**. Everyone who
  logs into a container shares its `MEMORY.md`, `USER.md`, sessions, skills and
  `state.db`. Upstream states plainly: *"Multiplexing isolates profiles; it does
  not authenticate or authorize end users. A profile is a configuration, not a
  person."*
- The **Hermes Gateway** is OpenAI-compatible and authenticated by a **single
  per-profile `API_SERVER_KEY`** (here `${LITEM_API_KEY}`). Session continuity
  uses the `X-Hermes-Session-Id` header. There are no accounts.
- **Profiles** (`hermes profile create`) create a separate `HERMES_HOME` with
  its own `config.yaml`, `.env`, `SOUL.md`, memories and sessions. They are
  per-persona/config separation for a **single operator**, not per-user
  authentication — profiles do not sandbox the filesystem.
- The **Hermes Workspace** web UI has one instance-wide password
  (`HERMES_WORKSPACE_PASSWORD`) and one login. There are no per-user accounts.
- Upstream's recommended way to serve multiple people is **one instance per
  user / per data volume**, isolated at the OS/container boundary.

> Do **not** treat profile multiplexing as multi-tenancy. Multiple people
> sharing one Hermes container will overwrite or leak each other's memory and
> session state.

### When to add another agent

| Need | Recommendation |
|---|---|
| A shared team assistant | Use the single `aiagnherm00` as-is (shared memory is intentional). |
| A few people who each want a private agent | Add one `aiagnherm0X` container + data volume per person. |
| Many users (dozens+) | Add per-user containers fronted by Authentik, or run Hermes per-user on the user's own machine / Portal account. |
| Separate personas for one person (code, research, …) | Use internal `hermes profile create` profiles inside `aiagnherm00`. |

### Scaling to more users

The platform ships one agent because Hermes is single-user. To extend it, copy
the `aiagnherm00` pattern in [`compose/aiagn.yml`](../../compose/aiagn.yml):

1. **Add the data directory** to `aiagnhermint` (or add a sibling init
   container) — e.g. `${HERMES_DATA_01:-${APPS_DATA}/hermesagent/01}:/data01`
   with `chown -R 10000:10000 /data01`.
2. **Duplicate the `aiagnherm00` service** as `aiagnherm01` with:
   - its own volume `${HERMES_DATA_01:-${APPS_DATA}/hermesagent/01}:/opt/data`,
   - its own `HERMES_WORKSPACE_PASSWORD=${HERMES_WORKSPACE_PASSWD_01}`,
   - a unique host port, e.g. `12321:12320`,
   - optional Traefik labels using `HERMES_WORKSPACE_DOMAIN_01`.
3. **Add matching variables** to `.env`:
   ```bash
   HERMES_WORKSPACE_PASSWD_01=<password>
   HERMES_DATA_01=${APPS_DATA}/hermesagent/01
   HERMES_WORKSPACE_DOMAIN_01=space1.${DOMAIN_NAME}
   ```
4. **Recreate only the new service:**
   ```bash
   docker compose up -d --build aiagnherm01
   ```

All agents share the same `aiagnlitellm` router and `aiagnchatllm` model, so
model capacity is scaled centrally, not per agent. Isolate user data strictly at
the volume boundary; never point two people at the same `HERMES_DATA_0X`.

Sources: [Hermes multiplexing gateway](https://hermes-agent.nousresearch.com/docs/developer-guide/multiplexing-gateway),
[profiles](https://hermes-agent.nousresearch.com/docs/user-guide/profiles),
[multi-profile gateways](https://hermes-agent.nousresearch.com/docs/user-guide/multi-profile-gateways),
[memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory),
[Docker guide](https://hermes-agent.nousresearch.com/docs/user-guide/docker).
