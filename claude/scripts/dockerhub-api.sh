#!/usr/bin/env bash
# The Docker Hub REST API (hub.docker.com/v2) with the credentials of <workspace>/.env
# (DOCKERHUB_USERNAME, DOCKERHUB_TOKEN); the credentials and the JWT are never printed. Called by
# the cleanup-dockerhub skill of the smart-home plugin from the workspace root - see claude/SETUP.md.
# Usage: dockerhub-api.sh <path below /v2/> [curl args]      - one call, the body on stdout
#        dockerhub-api.sh - [curl args] < paths.txt           - one login, one call per line of stdin,
#                                                               each body on its own line
#   dockerhub-api.sh 'repositories/magikabdul/?page_size=100'
#   dockerhub-api.sh repositories/magikabdul/water-service/tags/0.1.0/ -X DELETE -o /dev/null -w '%{http_code}\n'
# The user name is read from .env too: write <user> in a path and it is replaced.
set -euo pipefail
cd "$(dirname "$0")/../../.."
# a .env written on Windows ends its lines with CR, which would stay in every value
set -a; . <(tr -d '\r' < ./.env); set +a
: "${DOCKERHUB_USERNAME:?DOCKERHUB_USERNAME missing in .env}"
: "${DOCKERHUB_TOKEN:?DOCKERHUB_TOKEN missing in .env}"
path="$1"; shift

login=$(curl -sS --fail-with-body -X POST https://hub.docker.com/v2/users/login \
  -H 'Content-Type: application/json' \
  -d "{\"username\": \"$DOCKERHUB_USERNAME\", \"password\": \"$DOCKERHUB_TOKEN\"}")
# no jq on this machine: the token is the only string field of the answer
jwt=$(sed -nE 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"$login")
[ -n "$jwt" ] || { echo "Docker Hub login failed" >&2; exit 1; }

call() {
  local p="${1//<user>/$DOCKERHUB_USERNAME}"; shift
  curl -sS -H "Authorization: Bearer $jwt" -H 'Accept: application/json' "$@" "https://hub.docker.com/v2/$p" \
    || echo "FAILED $p" >&2
  echo
}

if [ "$path" = "-" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && call "$line" "$@"
  done
else
  call "$path" "$@"
fi
