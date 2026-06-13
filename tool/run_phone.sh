#!/usr/bin/env bash
set -euo pipefail

device_id="${DEVICE_ID:-00008130-000E08693609001C}"
api_host="${API_HOST:-}"

if [[ -z "${api_host}" ]]; then
  api_host="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi

if [[ -z "${api_host}" ]]; then
  echo "Could not detect your Mac Wi-Fi IP. Set API_HOST, for example:"
  echo "API_HOST=192.168.1.9 ./tool/run_phone.sh"
  exit 1
fi

api_base_url="${API_BASE_URL:-http://${api_host}:8080}"

flutter run \
  -d "${device_id}" \
  --dart-define="API_BASE_URL=${api_base_url}"
