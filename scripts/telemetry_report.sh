#!/bin/bash
set -euo pipefail

TOKEN="$(security find-generic-password -a Marklucif -s CoveTypeTelemetryAdminToken -w 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
    printf 'CoveType telemetry administrator token is not available in this Mac keychain.\n' >&2
    exit 1
fi

curl --fail --silent --show-error \
    --header "Authorization: Bearer $TOKEN" \
    --header 'Accept: application/json' \
    'https://telemetry.covetype.com/v1/stats' \
    | jq .
