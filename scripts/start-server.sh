#!/bin/bash
set -e

SERVER_NAME="${SERVER_NAME:?SERVER_NAME is required}"
LOCATOR_HOST="${LOCATOR_HOST:?LOCATOR_HOST is required}"
LOCATOR_PORT="${LOCATOR_PORT:-10335}"
SITE_ID="${SITE_ID:?SITE_ID is required}"
CACHE_XML="${CACHE_XML:?CACHE_XML is required}"

HTTP_PORT_OPT=""
if [ -n "$HTTP_PORT" ]; then
  HTTP_PORT_OPT="--start-rest-api=true --http-service-port=${HTTP_PORT}"
fi

gfsh start server \
  --name="${SERVER_NAME}" \
  --locators="${LOCATOR_HOST}[${LOCATOR_PORT}]" \
  --J=-Dgemfire.distributed-system-id="${SITE_ID}" \
  --cache-xml-file="${CACHE_XML}" \
  ${HTTP_PORT_OPT}

# Keep the container alive
tail -f "${SERVER_NAME}/${SERVER_NAME}.log"
