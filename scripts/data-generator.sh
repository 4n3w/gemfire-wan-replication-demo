#!/bin/bash
set -e

LOCATOR_HOST="${LOCATOR_HOST:-site-a-locator}"
LOCATOR_PORT="${LOCATOR_PORT:-10335}"
COUNTER=1

echo "Data generator starting. Target: ${LOCATOR_HOST}[${LOCATOR_PORT}]"

while true; do
  ORDER_ID="order-${COUNTER}"
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  WIDGET_NUM=$(( (COUNTER % 5) + 1 ))

  VALUE="{\"id\":\"${ORDER_ID}\",\"product\":\"Widget-${WIDGET_NUM}\",\"quantity\":${COUNTER},\"timestamp\":\"${TIMESTAMP}\"}"

  OUTPUT=$(gfsh -e "connect --locator=${LOCATOR_HOST}[${LOCATOR_PORT}] --jmx-manager=${LOCATOR_HOST}[1099]" \
               -e "put --region=/Orders --key=${ORDER_ID} --value='${VALUE}'" 2>&1)

  if echo "$OUTPUT" | grep -q "Result.*true"; then
    echo "[$(date -u +%H:%M:%S)] PUT ${ORDER_ID} -> OK"
  else
    echo "[$(date -u +%H:%M:%S)] PUT ${ORDER_ID} -> FAILED"
    echo "$OUTPUT" | tail -5
  fi

  COUNTER=$((COUNTER + 1))
  sleep 1
done
