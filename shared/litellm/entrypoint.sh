#!/usr/bin/env bash
# =============================================================================
# on first run and LiteLLM starts with the bundled settings.
#
# User override path (mount in agent.yml):
#   ${APPS_DATA}/litellm/config.yaml  →  /opt/litellm/config.yaml
#
# To customise: copy the default from the container, edit, and restart:
#   docker cp agsvclmrtr:/app/config.default.yaml ~/config.yaml
#   # edit ~/config.yaml, then place it at ${APPS_DATA}/litellm/config.yaml
# =============================================================================
set -euo pipefail

RUNTIME_CFG="/opt/litellm/config.yaml"
DEFAULT_CFG="/app/config.default.yaml"
ACTIVE_CFG="/tmp/litellm-config.yaml"
LITELLM_UIPORT="${UI_PORT:-12321}"

if [[ -f "${RUNTIME_CFG}" ]]; then
    echo "[litellm] Using runtime config: ${RUNTIME_CFG}"
    cp "${RUNTIME_CFG}" "${ACTIVE_CFG}"
else
    echo "[litellm] No runtime config — using built-in default"
    cp "${DEFAULT_CFG}" "${ACTIVE_CFG}"
fi

exec litellm --config "${ACTIVE_CFG}" --port "${LITELLM_UIPORT}" --host 0.0.0.0
