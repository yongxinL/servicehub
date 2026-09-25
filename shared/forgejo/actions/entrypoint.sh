#!/bin/sh
set -eu

CONFIG_FILE="${FORGEJO_RUNNER_CONFIG:-/etc/forgejo-runner/config.yml}"
RUNNER_FILE="/var/lib/forgejo-runner/.runner"

if [ ! -s "${RUNNER_FILE}" ]; then
    : "${DEPOT_RUNNER_SECRET:?DEPOT_RUNNER_SECRET is required for initial registration}"

    echo "Creating Forgejo Runner registration from shared secret..."

    # Offline registration: the UUID is derived from DEPOT_RUNNER_SECRET, which
    # must also be registered once on the Forgejo side (see shared/forgejo/README.md).
    # Labels come from runner.labels in the config file.
    forgejo-runner \
        --config "${CONFIG_FILE}" \
        create-runner-file \
        --instance "${FORGEJO_INSTANCE_URL:-http://depotservice:3000}" \
        --secret "${DEPOT_RUNNER_SECRET}" \
        --name "${FORGEJO_RUNNER_NAME:-depotrunner}"
else
    echo "Existing Forgejo Runner registration found."
fi

exec forgejo-runner \
    --config "${CONFIG_FILE}" \
    daemon
