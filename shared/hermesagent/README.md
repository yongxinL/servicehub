# Hermes Agent — ServiceHub image

Build context for the `agsvchermagt` container. Wraps the upstream
[`nousresearch/hermes-agent`](https://hermes-agent.nousresearch.com) image with
ServiceHub-specific seeding, placeholder substitution, and an **overlay
system** for persisting source-code edits to `/opt/hermes` across container
recreation.

The full setup guide lives in [README.html](README.html) (open in a browser).
This file documents the overlay system and environment variables.

---

## Volumes

| Container path | Host path | Purpose |
|---|---|---|
| `/opt/data` | `${APPS_DATA}/hermesagent/data` | Hermes data + `$HOME` (profiles, sessions, memory, `.env`, `config.yaml`) |
| `/opt/data/overlay` | `${APPS_DATA}/hermesagent/data/overlay` | Persisted edits to `/opt/hermes` (see below) |
| `/var/run/docker.sock` | host docker socket (ro) | Terminal sandbox spawning |

**Services & Ports:**

| Service | Port | Purpose |
|---|---|---|
| Hermes Workspace | 12328 | Web UI (login with `HERMES_SPACE_PASSWD`) |
| Hermes Dashboard | 12329 | Gateway dashboard |
| Hermes Gateway | 12330 | API server for HTTP clients |

`/opt/hermes` (~1.4 GB) is **not** mounted — it ships with the image as a
read-only baseline. The overlay system replays your changes onto it at start.

### Migrating from a flat mount

Older versions mounted `${APPS_DATA}/hermesagent:/opt/data` directly. The new
layout nests data one level deeper so the overlay can live alongside it.
If you have an existing install, move the contents before first start:

```bash
docker compose stop agsvchermagt
mkdir -p ${APPS_DATA}/hermesagent/data
( cd ${APPS_DATA}/hermesagent && \
  shopt -s dotglob && \
  mv !(data) data/ )
docker compose up -d --force-recreate agsvchermagt
```

---

## Overlay system

Hermes (or you) can modify files under `/opt/hermes` inside the container —
but those edits live in the container's writable layer and disappear on
`docker compose down` / `up` / `--build`. The overlay system fixes that by
storing the edits on the host and replaying them at startup.

### Layout

```
${APPS_DATA}/hermesagent/data/overlay/
├── files/      # sparse mirror of /opt/hermes — saved files replayed at start
├── originals/  # pristine "before" copies for diff generation
└── patches/    # *.patch files applied after files/, in lexical order
```

No 1.4 GB pristine snapshot is duplicated anywhere. Only the files you
actually touch end up under `originals/`.

### Apply flow (at container start)

`start-gateways.sh` calls `apply-overlay.sh` before launching any hermes
process:

1. `rsync overlay/files/ → /opt/hermes/` — bulk file overlays first
2. `patch -p1` each `overlay/patches/*.patch` in lexical order

Skips `__pycache__/`, `*.pyc`, `.venv/`. Already-applied patches are
detected and skipped silently (idempotent). Conflicting patches **abort
startup** — half-patched state would be worse than no state.

### Tools (available inside the container, on `PATH`)

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
docker compose exec agsvchermagt overlay-track /opt/hermes/agent/router.py

# 2. Edit the file (you, or hand the task to the agent)
docker compose exec -it agsvchermagt nano /opt/hermes/agent/router.py

# 3. After editing — persist the change
docker compose exec agsvchermagt overlay-save /opt/hermes/agent/router.py

# 4. Recreate the container — your edit comes back automatically
docker compose up -d --force-recreate agsvchermagt
docker compose logs agsvchermagt | grep '\[overlay\]'
# [overlay] Applying 1 file overlay(s) from /opt/data/overlay/files/
# [overlay] Overlay applied.
```

### Generating a portable patch

When you want a reviewable diff (to share, version-control, or hand to the
AI):

```bash
docker compose exec agsvchermagt overlay-patch fix-router-timeout
# → ${APPS_DATA}/hermesagent/data/overlay/patches/fix-router-timeout.patch
```

The patch has `a/<relpath>` / `b/<relpath>` headers and applies cleanly to
`/opt/hermes` with `patch -p1`. Once the patch is captured, you can delete
the corresponding `files/<relpath>` and `originals/<relpath>` entries — the
patch alone will reproduce the change.

### Recovering a baseline you forgot to track

If you edited a file without running `overlay-track` first, `overlay-save`
captured the edited version as the baseline — diffing it against itself
produces an empty patch. To recover the true upstream baseline:

```bash
# Pull the original file from the upstream image without touching anything
docker run --rm nousresearch/hermes-agent:latest \
    cat /opt/hermes/path/to/file.py \
    > ${APPS_DATA}/hermesagent/data/overlay/originals/path/to/file.py
```

Then re-run `overlay-patch <name>` and you'll get the real diff.

### Upstream updates

When the base image is rebuilt (`docker compose build agsvchermagt`):

- **`files/` overlays** silently shadow whatever the new upstream version
  contains for those paths. If upstream made a security fix to a file you've
  overridden, your override hides it. Audit periodically with
  `overlay-patch` and diff against the new upstream.
- **`patches/` overlays** apply cleanly when upstream is unchanged and
  **fail loud** when upstream conflicts. Aborting startup is the intended
  behavior — it forces you to rebase the patch.

For long-lived modifications, prefer `patches/` over `files/`. For
quick experiments, `files/` is faster.

### Excludes

Both apply and capture skip:

- `__pycache__/` directories
- `*.pyc` files
- `.venv/` (huge, machine-specific, almost never a patch target — change
  Python deps via the [Dockerfile](Dockerfile) instead)

### Disabling the overlay

The overlay folder is auto-created empty on first start. To disable
entirely, leave it empty — `apply-overlay.sh` no-ops when both `files/`
and `patches/` are empty. To remove the overlay step, comment out the
`/usr/local/bin/apply-overlay.sh` line in [start-gateways.sh](start-gateways.sh).

---

## Hermes Workspace

The image bundles [Hermes Workspace](https://github.com/outsourc-e/hermes-workspace)
(a web UI for Hermes Agent) alongside the gateway and dashboard.

**Access:** `http://<host-ip>:12328`

**Login:** Use `HERMES_SPACE_PASSWD` (generated by `scripts/setup.sh`).

**Environment variables:**

| Variable | Default | Description |
|---|---|---|
| `HERMES_AGENT_PROFILES` | `""` | Space-separated profile names to auto-start. Leave empty for default profile only. |
| `HERMES_DASHBOARD_PORT` | `12329` | Dashboard listen port |
| `HERMES_WORKSPACE_PORT` | `12328` | Workspace listen port |
| `HERMES_WORKSPACE_PASSWORD` | (from `HERMES_SPACE_PASSWD`) | Login password |
| `HERMES_SPACE_PASSWD` | — | Root `.env` variable that feeds `HERMES_WORKSPACE_PASSWORD` into the container |

**To add profiles**, set in root `.env`:
```
HERMES_AGENT_PROFILES="alice bob"
```
Then initialize with `./shared/hermesagent/init-profile.sh alice --port 8643`.
