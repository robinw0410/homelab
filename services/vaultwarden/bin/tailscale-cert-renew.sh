#!/bin/bash
set -euo pipefail

DOMAIN="${TS_CERT_DOMAIN:?TS_CERT_DOMAIN not set (see .env.example)}"
CERT_DIR="/vw-data"

tailscale cert \
  --cert-file "${CERT_DIR}/tailscale.crt" \
  --key-file "${CERT_DIR}/tailscale.key" \
  "$DOMAIN"

docker restart vaultwarden
