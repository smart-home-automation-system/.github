#!/usr/bin/env bash
# The Jira Cloud REST API of magikabdul.atlassian.net with the credentials of <workspace>/.env
# (JIRA_EMAIL, JIRA_API_TOKEN); the credentials are never printed. Called by the Jira skills of
# the smart-home plugin from the workspace root - see claude/SETUP.md, section 4a.
# Usage: jira-api.sh <path below /rest/> [curl args]
#   jira-api.sh 'api/3/issue/HAS-288?fields=summary,status'
#   jira-api.sh api/3/issue/HAS-288 -X PUT -H 'Content-Type: application/json' -d @body.json
set -euo pipefail
cd "$(dirname "$0")/../../.."
#a .env written on Windows ends its lines with CR, which would stay in every value
set -a; . <(tr -d '\r' < ./.env); set +a
path="$1"; shift
curl -sS --fail-with-body -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H 'Accept: application/json' "$@" \
  "https://magikabdul.atlassian.net/rest/$path"
