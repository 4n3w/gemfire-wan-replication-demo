#!/bin/bash
set -e

LOCATOR_NAME="${LOCATOR_NAME:?LOCATOR_NAME is required}"
LOCATOR_PORT="${LOCATOR_PORT:-10335}"
SITE_ID="${SITE_ID:?SITE_ID is required}"

REMOTE_LOCATORS_OPT=""
if [ -n "$REMOTE_LOCATORS" ]; then
  REMOTE_LOCATORS_OPT="--J=-Dgemfire.remote-locators=${REMOTE_LOCATORS}"
fi

HOSTNAME_FOR_CLIENTS_OPT=""
if [ -n "$HOSTNAME_FOR_CLIENTS" ]; then
  HOSTNAME_FOR_CLIENTS_OPT="--hostname-for-clients=${HOSTNAME_FOR_CLIENTS}"
fi

gfsh start locator \
  --name="${LOCATOR_NAME}" \
  --port="${LOCATOR_PORT}" \
  --J=-Dgemfire.distributed-system-id="${SITE_ID}" \
  --J=-Dgemfire.jmx-manager-start=true \
  --J=-Dgemfire.enable-cluster-configuration=true \
  ${REMOTE_LOCATORS_OPT} \
  ${HOSTNAME_FOR_CLIENTS_OPT}

# Keep the container alive
tail -f "${LOCATOR_NAME}/${LOCATOR_NAME}.log"
