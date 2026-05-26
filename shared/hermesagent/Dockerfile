# syntax=docker/dockerfile:1.6
# =============================================================================
# Hermes Agent — custom image with bundled Hermes Workspace & Dashboard
#
# Build stage: clones hermes-workspace from GitHub, builds with Node 22.
# Runtime stage: uses nousresearch/hermes-agent base, copies only built artifacts.
# Workspace runs on Node 20 (compatible with pre-built server-entry.js).
#
# Dashboard: runs hermes dashboard for the Enhancement API + web interface.
#
# Build arg:
#   HERMES_WORKSPACE_REF  git ref to build (default: main)
#                         Use tags/v2.3.0 for pinned releases.
# =============================================================================

# ─── build stage ─────────────────────────────────────────────────────────────
FROM node:22-slim AS build

ARG HERMES_WORKSPACE_REF=main
WORKDIR /tmp/hermes-workspace

# Install pnpm + bun + build deps + CA certs for git HTTPS
RUN corepack enable \
 && apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL https://bun.sh/install | bash

ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Git HTTPS config
RUN git config --global http.sslCAinfo /etc/ssl/certs/ca-certificates.crt

# Clone hermes-workspace at specified ref
RUN git clone --depth 1 --branch "${HERMES_WORKSPACE_REF}" \
    https://github.com/outsourc-e/hermes-workspace.git .

# Install deps (skip postinstall scripts — electron/playwright binaries not needed
# in container; we only run the server-entry.js web UI).
RUN pnpm install --frozen-lockfile --ignore-scripts

# Build
RUN pnpm build

# Prune dev deps and pnpm cache to shrink layer size
RUN pnpm store prune \
 && rm -rf node_modules/.cache

# ─── runtime stage ───────────────────────────────────────────────────────────
# https://github.com/nousresearch/hermes-agent
FROM nousresearch/hermes-agent:latest
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# Add tools needed for our startup scripts
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini nano patch rsync \
 && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/opt/hermes/.venv/bin"
ENV HOME="/opt/data"

# Hermes workspace built artifacts (installed to /opt/lib/workspace)
COPY --from=build /tmp/hermes-workspace/dist /opt/lib/workspace/dist
COPY --from=build /tmp/hermes-workspace/node_modules /opt/lib/workspace/node_modules
COPY --from=build /tmp/hermes-workspace/package.json /opt/lib/workspace/package.json
COPY --from=build /tmp/hermes-workspace/server-entry.js /opt/lib/workspace/server-entry.js
COPY --from=build /tmp/hermes-workspace/skills /opt/lib/workspace/skills

# Hermes defaults + overlay helpers
COPY default/ /opt/hermes/defaults/
COPY start-gateways.sh /usr/local/bin/start-gateways.sh
COPY init-profile.sh   /usr/local/bin/init-profile.sh
COPY apply-overlay.sh  /usr/local/bin/apply-overlay.sh
COPY overlay-track     /usr/local/bin/overlay-track
COPY overlay-save      /usr/local/bin/overlay-save
COPY overlay-patch     /usr/local/bin/overlay-patch

RUN chmod +x /usr/local/bin/start-gateways.sh \
             /usr/local/bin/init-profile.sh \
             /usr/local/bin/apply-overlay.sh \
             /usr/local/bin/overlay-track \
             /usr/local/bin/overlay-save \
             /usr/local/bin/overlay-patch

# Ports:
#   12320  Hermes Workspace (web UI)
#   12330  Hermes Gateway API server (internal; not exposed)
#   9119   Hermes Dashboard (Enhancement API, internal)
EXPOSE 12320 12330 9119

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/start-gateways.sh"]