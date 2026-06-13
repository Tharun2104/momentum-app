#!/usr/bin/env bash
set -euo pipefail

device_id="${DEVICE_ID:-F6E99A03-1636-4C79-B644-48D1D481558E}"
api_base_url="${API_BASE_URL:-http://localhost:8080}"

flutter run \
  -d "${device_id}" \
  --dart-define="API_BASE_URL=${api_base_url}"
