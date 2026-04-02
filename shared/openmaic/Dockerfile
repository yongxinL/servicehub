# https://github.com/THU-MAIC/OpenMAIC

# --- Stage 0: source fetch (download/unzip only once) ---
FROM node:22-alpine AS src
LABEL org.opencontainers.image.authors="yongxinL@outlook.com"

# build-time argument
ARG OPENMAIC_ZIP_URL="https://github.com/THU-MAIC/OpenMAIC/archive/refs/heads/main.zip"

RUN apk add --no-cache curl unzip

WORKDIR /tmp

RUN set -eux; \
    curl -fsSL -o repo.zip "${OPENMAIC_ZIP_URL}"; \
    unzip -q repo.zip -d /tmp; \
    REPO_DIR="$(find /tmp -maxdepth 1 -type d -name 'OpenMAIC-*' | head -n 1)"; \
    mv "${REPO_DIR}" /src; \
    rm -f repo.zip

# --- Stage 1: Base ---
FROM node:22-alpine AS base

RUN apk add --no-cache libc6-compat
RUN corepack enable && corepack prepare pnpm@10.28.0 --activate

WORKDIR /app

# --- Stage 2: Dependencies ---
FROM base AS deps

# Native build tools for sharp, @napi-rs/canvas
RUN apk add --no-cache python3 build-base g++ cairo-dev pango-dev jpeg-dev giflib-dev librsvg-dev

# Copy ONLY the dependency-relevant files from the fetched source
COPY --from=src /src/package.json /app/package.json
COPY --from=src /src/pnpm-lock.yaml /app/pnpm-lock.yaml
COPY --from=src /src/pnpm-workspace.yaml /app/pnpm-workspace.yaml
COPY --from=src /src/packages /app/packages

RUN pnpm install --frozen-lockfile

# --- Stage 3: Builder (build entirely from GitHub repo) ---
FROM base AS builder

# Build deps available
COPY --from=deps /app/node_modules /app/node_modules
COPY --from=deps /app/packages /app/packages

# Copy full source tree from GitHub zip
COPY --from=src /src /app

# If your build expects writable dirs, you can ensure they exist:
# RUN mkdir -p /app/.next

RUN pnpm build

# --- Stage 4: Runner ---
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=PASSWORD
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

RUN apk add --no-cache libc6-compat cairo pango jpeg giflib librsvg

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
