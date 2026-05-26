#!/usr/bin/env bash
# Preflight for npm/GitHub releases. It intentionally does not publish or push.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

log() {
  printf '[release-check] %s\n' "$*"
}

gateway_from_ui() {
  local ui="${EXP_UI_PUBLIC_URL:-}"
  ui="${ui%/}"
  if [[ "$ui" =~ ^(.*)/proxy/[0-9]+$ ]]; then
    printf '%s/proxy/3080\n' "${BASH_REMATCH[1]}"
  fi
}

RELEASE_BASE="${EXPOOL_RELEASE_BASE:-${EXPOOL_BASE:-${EXP_BIND_BASE_URL:-$(gateway_from_ui)}}}"
RELEASE_BASE="${RELEASE_BASE:-http://127.0.0.1:3080}"

log "syntax checks"
node --check bin/expool-plugin.js
bash -n plugins/expool/scripts/register-mcp.sh
bash -n plugins/expool/scripts/auto-upload.sh
bash -n scripts/release-check.sh
bash -n scripts/publish-npm.sh
bash -n scripts/check-gateway.sh
bash -n scripts/make-release-artifacts.sh
python3 -m py_compile \
  plugins/expool/servers/expool_mcp.py \
  plugins/expool/vendor/exp_uploader.py

log "remove generated Python bytecode"
find plugins -type d -name __pycache__ -prune -exec rm -rf {} +
find plugins -name '*.pyc' -delete

VALIDATOR="${CODEX_PLUGIN_VALIDATOR:-/root/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py}"
if [ -f "$VALIDATOR" ]; then
  log "codex plugin manifest validation"
  python3 "$VALIDATOR" "$ROOT/plugins/expool"
else
  log "skip codex manifest validation; validator not found"
fi

log "CLI smoke checks"
node bin/expool-plugin.js help >/dev/null
node bin/expool-plugin.js path >/dev/null
node bin/expool-plugin.js install --agents codex --dry-run --base "$RELEASE_BASE" >/dev/null

if [ "${EXPOOL_CHECK_GATEWAY:-0}" = "1" ]; then
  log "gateway compatibility"
  bash scripts/check-gateway.sh "$RELEASE_BASE"
fi

log "npm package dry-run"
npm pack --dry-run >/tmp/expool-plugin-npm-pack.txt 2>&1
grep -q 'plugins/expool/.codex-plugin/plugin.json' /tmp/expool-plugin-npm-pack.txt
grep -q '.agents/plugins/marketplace.json' /tmp/expool-plugin-npm-pack.txt
grep -q 'plugins/expool/vendor/exp_uploader.py' /tmp/expool-plugin-npm-pack.txt
if grep -Eq '__pycache__|\\.pyc' /tmp/expool-plugin-npm-pack.txt; then
  cat /tmp/expool-plugin-npm-pack.txt >&2
  printf 'release-check: package contains Python bytecode\n' >&2
  exit 1
fi

log "ok"
