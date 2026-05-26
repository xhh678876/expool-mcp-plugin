#!/usr/bin/env bash
# Verify that a gateway is new enough for this plugin. This is read-only except
# for intentionally sending an invalid pairing code, which must return 400.

set -euo pipefail

gateway_from_ui() {
  local ui="${EXP_UI_PUBLIC_URL:-}"
  ui="${ui%/}"
  if [[ "$ui" =~ ^(.*)/proxy/[0-9]+$ ]]; then
    printf '%s/proxy/3080\n' "${BASH_REMATCH[1]}"
  fi
}

BASE="${1:-${EXPOOL_RELEASE_BASE:-${EXPOOL_BASE:-${EXP_BIND_BASE_URL:-$(gateway_from_ui)}}}}"
BASE="${BASE:-http://127.0.0.1:3080}"
BASE="${BASE%/}"

log() {
  printf '[gateway-check] %s\n' "$*"
}

log "base=$BASE"

curl --noproxy '*' -fsS --max-time 5 "$BASE/healthz" >/dev/null

code="$(
  curl --noproxy '*' -sS -o /tmp/expool-gateway-pair.json \
    -w '%{http_code}' --max-time 5 \
    -X POST "$BASE/v1/plugin/pair" \
    -H 'Content-Type: application/json' \
    -d '{"code":"expair_invalid"}' || true
)"

if [ "$code" != "400" ]; then
  log "expected /v1/plugin/pair invalid-code response 400, got $code"
  sed -n '1,20p' /tmp/expool-gateway-pair.json >&2 2>/dev/null || true
  exit 1
fi

log "pairing endpoint ok"
