#!/bin/sh
set -eu

export OCIS_CONFIG_DIR="${OCIS_CONFIG_DIR:-/etc/ocis}"
CONFIG_FILE="${OCIS_CONFIG_DIR}/ocis.yaml"

if [ -s "${CONFIG_FILE}" ]; then
    echo "Existing oCIS configuration found at ${CONFIG_FILE}."
else
    echo "Initialising oCIS configuration at ${CONFIG_FILE}..."
    ocis init --config-path "${OCIS_CONFIG_DIR}"
fi

exec ocis server
