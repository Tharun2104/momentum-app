#!/usr/bin/env bash
set -euo pipefail

phone="${1:-tharun}"

THARUN_DEVICE_ID="00008130-000E08693609001C"
PRATHIBHA_DEVICE_ID="00008130-000564910A12001C"

api_host="${API_HOST:-}"

if [[ -z "${api_host}" ]]; then
  api_host="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi

if [[ -z "${api_host}" ]]; then
  api_host="$(ifconfig en0 2>/dev/null | awk '/inet / {print $2; exit}')"
fi

if [[ -z "${api_host}" ]]; then
  echo "Could not detect your Mac Wi-Fi IP. Set API_HOST, for example:"
  echo "API_HOST=192.168.1.9 ./tool/run_phone.sh tharun"
  exit 1
fi

api_base_url="${API_BASE_URL:-http://${api_host}:8080}"

run_device() {
  local device_id="$1"
  local label="$2"

  echo "Running Momentum on ${label}"
  echo "Device ID: ${device_id}"
  echo "API_BASE_URL: ${api_base_url}"

  flutter run \
    --release \
    -d "${device_id}" \
    --dart-define="API_BASE_URL=${api_base_url}"
}

case "${phone}" in
  tharun)
    run_device "${THARUN_DEVICE_ID}" "Tharun iPhone"
    ;;
  prathibha)
    run_device "${PRATHIBHA_DEVICE_ID}" "Prathibha iPhone"
    ;;
  all)
    echo "Starting both phones..."
    echo "Open two terminal windows if this blocks after first launch."

    run_device "${PRATHIBHA_DEVICE_ID}" "Prathibha iPhone" &
    sleep 5
    run_device "${THARUN_DEVICE_ID}" "Tharun iPhone"

    wait
    ;;
  *)
    echo "Usage:"
    echo "./tool/run_phone.sh tharun"
    echo "./tool/run_phone.sh prathibha"
    echo "./tool/run_phone.sh all"
    exit 1
    ;;
esac