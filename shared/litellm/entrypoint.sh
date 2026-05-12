#!/usr/bin/env bash
# =============================================================================
# on first run and LiteLLM starts with the bundled settings.
#
# User override path (mount in agent.yml):
#   /opt/litellm/config.yaml  →  /opt/litellm/config.yaml
#
# To customise: copy the default from the container, edit, and restart:
#   docker cp agsvclmrtr:/app/config.default.yaml ~/config.yaml
#   # edit ~/config.yaml, then place it at /opt/litellm/config.yaml
# =============================================================================
set -euo pipefail

USER_CONFIG="/opt/litellm/config.yaml"
DEFT_CONFIG="/app/config.default.yaml"
RUNT_CONFIG="/app/litellm-config.yaml"
RUNT_UIPORT="${UI_PORT:-12380}"

if [[ -f "${USER_CONFIG}" ]]; then
    echo "[litellm] Using user configuration: ${USER_CONFIG}"
    cp "${USER_CONFIG}" "${RUNT_CONFIG}"
else
    echo "[litellm] No user configuration — using built-in default configuration ${DEFT_CONFIG}"
    cp "${DEFT_CONFIG}" "${RUNT_CONFIG}"
    echo "[litellm] copy default configuration to user configuration ..."
    cp "${DEFT_CONFIG}" "${USER_CONFIG}"
fi

exec litellm --config "${RUNT_CONFIG}" --port "${RUNT_UIPORT}" --host 0.0.0.0
