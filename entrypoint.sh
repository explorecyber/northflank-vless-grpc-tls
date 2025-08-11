#!/usr/bin/env bash
set -euo pipefail

: "${UUID?Need UUID (client id)}"
: "${DOMAIN?Need DOMAIN (server name for TLS/SNI)}"
: "${CERT_PATH:-/etc/xray/certs/fullchain.pem}"
: "${KEY_PATH:-/etc/xray/certs/privkey.pem}"
: "${PORT:-443}"
: "${GRPC_SERVICE_NAME:-grpc}"

TEMPLATE=/etc/xray/config.template.json
OUT=/etc/xray/config.json

cat "$TEMPLATE" \
  | sed "s#__UUID__#${UUID}#g" \
  | sed "s#__DOMAIN__#${DOMAIN}#g" \
  | sed "s#__PORT__#${PORT}#g" \
  | sed "s#__GRPC_SERVICE_NAME__#${GRPC_SERVICE_NAME}#g" \
  > "$OUT"

if [ ! -f "${CERT_PATH}" ] || [ ! -f "${KEY_PATH}" ]; then
  echo "[WARNING] certificate or key not found at ${CERT_PATH} / ${KEY_PATH}."
  echo "If you use Cloudflare origin certs, mount them to /etc/xray/certs or set CERT_PATH/KEY_PATH env."
fi

exec /opt/xray/xray -config "$OUT"
