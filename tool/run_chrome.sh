#!/usr/bin/env bash
set -euo pipefail

api_base_url="${API_BASE_URL:-http://localhost:8080}"

flutter run \
  -d chrome \
  --dart-define="API_BASE_URL=${api_base_url}"
