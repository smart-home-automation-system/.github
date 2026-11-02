#!/usr/bin/env bash
# The Solarman Open API (globalapi.solarmanpv.com, the international data centre) with the
# credentials of <workspace>/.env (SOLARMAN_APP_ID, SOLARMAN_APP_SECRET, SOLARMAN_EMAIL and
# SOLARMAN_PASSWORD_SHA256 - the lowercase SHA-256 of the account password); the credentials and
# the access token are never printed. Called from the workspace root - see claude/SETUP.md, 4a.
# Usage: solarman-api.sh <path below the host> [curl args]
#   solarman-api.sh 'station/v1.0/list?language=en' -X POST -H 'Content-Type: application/json' -d '{}'
#   solarman-api.sh 'device/v1.0/currentData?language=en' -X POST \
#     -H 'Content-Type: application/json' -d '{"deviceSn":"..."}'
set -euo pipefail
cd "$(dirname "$0")/../../.."
# a .env written on Windows ends its lines with CR, which would stay in every value
set -a; . <(tr -d '\r' < ./.env); set +a
missing=""
for v in SOLARMAN_APP_ID SOLARMAN_APP_SECRET SOLARMAN_EMAIL SOLARMAN_PASSWORD_SHA256; do
  [ -n "${!v:-}" ] || missing="$missing $v"
done
if [ -n "$missing" ]; then
  echo "solarman-api: missing in .env:$missing" >&2
  exit 1
fi
path="$1"; shift
base="https://globalapi.solarmanpv.com"
body=$(printf '{"appSecret":"%s","email":"%s","password":"%s"}' \
  "$SOLARMAN_APP_SECRET" "$SOLARMAN_EMAIL" "$SOLARMAN_PASSWORD_SHA256")
answer=$(curl -sS -X POST "$base/account/v1.0/token?appId=$SOLARMAN_APP_ID&language=en" \
  -H 'Content-Type: application/json' -d "$body")
token=$(printf '%s' "$answer" | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
if [ -z "$token" ]; then
  # the answer of a refused token carries no secret: code and msg only
  echo "solarman-api: no access token - $(printf '%s' "$answer" | sed 's/"access_token" *: *"[^"]*"//')" >&2
  exit 1
fi
curl -sS --fail-with-body -H "Authorization: bearer $token" -H 'Accept: application/json' "$@" \
  "$base/$path"
