#!/usr/bin/env bash
# The SolaX Developer Platform API (openapi-eu.solaxcloud.com) with the application credentials
# of <workspace>/.env (SOLAX_CLIENT_ID, SOLAX_CLIENT_SECRET); the credentials and the access
# token are never printed. Called from the workspace root - see claude/SETUP.md, section 4a.
# Usage: solax-api.sh <path below /openapi/> [curl args]
#   solax-api.sh 'v2/device/data/realtime?snList=10U080021B0X0S&deviceType=1&businessType=1'
#   solax-api.sh v2/device/inverter_work_mode/batch_set_spontaneity_self_use -X POST \
#     -H 'Content-Type: application/json' -d @body.json
set -euo pipefail
cd "$(dirname "$0")/../../.."
# a .env written on Windows ends its lines with CR, which would stay in every value
set -a; . <(tr -d '\r' < ./.env); set +a
path="$1"; shift
base="https://openapi-eu.solaxcloud.com/openapi"
token=$(curl -sS --fail-with-body -X POST "$base/auth/oauth/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "client_id=$SOLAX_CLIENT_ID" \
  --data-urlencode "client_secret=$SOLAX_CLIENT_SECRET" \
  --data-urlencode "grant_type=client_credentials" \
  | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
if [ -z "$token" ]; then
  echo "solax-api: no access token (check SOLAX_CLIENT_ID / SOLAX_CLIENT_SECRET in .env)" >&2
  exit 1
fi
curl -sS --fail-with-body -H "Authorization: bearer $token" -H 'Accept: application/json' "$@" \
  "$base/$path"
