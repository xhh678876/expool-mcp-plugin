#!/usr/bin/env bash
# Preflight for npm/GitHub releases. It intentionally does not publish or push.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
# shellcheck disable=SC1091
. "$ROOT/scripts/load-workspace-env.sh"

log() {
  printf '[release-check] %s\n' "$*"
}

gateway_from_ui() {
  local ui="${EXP_UI_PUBLIC_URL:-}"
  ui="${ui%/}"
  if [[ "$ui" =~ ^(.*)/proxy/[0-9]+$ ]]; then
    printf '%s/proxy/%s\n' "${BASH_REMATCH[1]}" "${EXP_GATEWAY_PORT:-3080}"
  fi
}

RELEASE_BASE="${EXPOOL_RELEASE_BASE:-${EXPOOL_BASE:-${EXP_BIND_BASE_URL:-$(gateway_from_ui)}}}"
RELEASE_BASE="${RELEASE_BASE:-http://127.0.0.1:3080}"

log "syntax checks"
node --check bin/expool-plugin.js
bash -n plugins/expool/scripts/register-mcp.sh
bash -n plugins/expool/scripts/auto-upload.sh
bash -n plugins/expool/scripts/auto-search.sh
bash -n plugins/expool/scripts/auto-recall.sh
bash -n scripts/release-check.sh
bash -n scripts/publish-npm.sh
bash -n scripts/check-gateway.sh
bash -n scripts/make-release-artifacts.sh
bash -n scripts/load-workspace-env.sh
python3 -m py_compile \
  plugins/expool/servers/expool_mcp.py \
  plugins/expool/vendor/exp_uploader.py

log "vendor <-> portal dist-public exp_uploader.py consistency"
# 以 vendor 为可信源校验源仓 dist-public 是否同步。portal 源仓不存在时 sync-vendor.sh
# 会优雅降级（打印 warning + exit 0），保证 npm-only 环境仍能通过；portal 存在时严格校验。
if ! bash scripts/sync-vendor.sh --check; then
  printf 'release-check: exp_uploader.py 在 vendor 与源仓 dist-public 之间不一致。\n' >&2
  printf 'release-check: 运行 scripts/sync-vendor.sh 同步后重试。\n' >&2
  exit 1
fi

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
grep -q 'plugins/expool/commands/rag-search.md' /tmp/expool-plugin-npm-pack.txt
grep -q 'plugins/expool/commands/projects.md' /tmp/expool-plugin-npm-pack.txt
grep -q 'plugins/expool/scripts/auto-recall.sh' /tmp/expool-plugin-npm-pack.txt
if grep -Eq '__pycache__|\\.pyc' /tmp/expool-plugin-npm-pack.txt; then
  cat /tmp/expool-plugin-npm-pack.txt >&2
  printf 'release-check: package contains Python bytecode\n' >&2
  exit 1
fi

log "ok"
