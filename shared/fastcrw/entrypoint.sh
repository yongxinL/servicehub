#!/bin/sh
set -e

# Substitute env vars into the config template and write to a writable path.
# This works around config-rs's inability to override TOML arrays via env vars
# (CRW_AUTH__API_KEYS is parsed as a string, not a sequence).
envsubst '$FIRECRAWL_API_KEY' < /app/config.docker.toml > /app/config.active.toml
export CRW_CONFIG=config.active

exec "$@"
