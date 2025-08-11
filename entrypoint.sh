#!/usr/bin/env bash
set -euo pipefail

: "${UUID?Need UUID (client id)}"
: "${DOMAIN?Need DOMAIN (for reference only)}"
: "${PORT:=443}"
: "${GRPC_SERVICE_NAME:=grpc}"

TEMPLATE=/etc/xray/config.json
OUT=/etc/xray/config.json

cat "$TEMPLATE" \
  | sed "s#__UUID__#${UUID}#g" \
  | sed "s#__PORT__#${PORT}#g" \
  | sed "s#__GRPC_SERVICE_NAME__#${GRPC_SERVICE_NAME}#g" \
  > "$OUT"

exec /opt/xray/xray -config "$OUT"
