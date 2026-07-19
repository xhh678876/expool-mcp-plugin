#!/usr/bin/env bash
# sync-vendor.sh — keep exp_uploader.py in sync across the two repos.
#
# Single source of truth (可信源): the plugin vendor copy
#   plugins/expool/vendor/exp_uploader.py
# Rationale: 插件 vendor 副本最新、最全（含 cmd_bind_api / cmd_pair 等），
# 它是发布产物里真正被打包进 npm tarball 的那一份，因此把它定为唯一可信源，
# 由这里单向同步到源仓 dist-public，避免三份文件各自漂移。
#
# Target (同步目标): source portal repo dist-public copy
#   ${EXPOOL_PORTAL_ROOT:-<repo>/../experience-pool}/dist-public/exp_uploader.py
# EXPOOL_PORTAL_ROOT 的缺省与 make-release-artifacts.sh 保持一致。
#
# Modes:
#   (no args)    把 vendor 同步覆盖到 portal dist-public（覆盖前打印 sha256/行数对比）。
#   --check      只比对两边 sha256；不一致则非零退出并打印 diff 摘要（供 CI / release-check 调用）；
#                一致则打印 OK。
#   --dry-run    打印将要执行的同步动作与对比，但不写入。
#
# Portal 目录缺失时的行为：
#   * 默认 / --dry-run 模式：友好提示并以非零退出（同步是明确的写操作，目标缺失视为错误）。
#   * --check 模式：打印 warning 后以 0 退出（优雅降级）。因为 release-check 可能在
#     npm-only / 无源仓的环境里跑，此时无从校验，跳过比 fail 更合理；真正有 portal
#     时才严格校验。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
# shellcheck disable=SC1091
. "$ROOT/scripts/load-workspace-env.sh"

VENDOR="$ROOT/plugins/expool/vendor/exp_uploader.py"
PORTAL_ROOT="${EXPOOL_PORTAL_ROOT:-$ROOT/../experience-pool}"
TARGET="$PORTAL_ROOT/dist-public/exp_uploader.py"

usage() {
  cat <<'EOF'
Usage: scripts/sync-vendor.sh [--check | --dry-run]

  (no args)   Sync vendor exp_uploader.py -> portal dist-public (overwrites target).
  --check     Compare sha256 only; non-zero exit on mismatch (for CI/release-check).
              Gracefully skips (exit 0 + warning) when portal repo is absent.
  --dry-run   Preview the sync (sha256/line comparison) without writing.

Env:
  EXPOOL_PORTAL_ROOT   Portal repo root (default: <repo>/../experience-pool)
  EXPOOL_CONFIG_FILE   Optional shared config/env.sh from the portal repo
  EXP_ENV              development (default) or production
EOF
}

log() { printf '[sync-vendor] %s\n' "$*"; }
err() { printf '[sync-vendor] %s\n' "$*" >&2; }

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

lines_of() { wc -l < "$1" | tr -d ' '; }

print_compare() {
  local v_sha t_sha v_lines t_lines
  v_sha="$(sha_of "$VENDOR")"
  v_lines="$(lines_of "$VENDOR")"
  log "source (可信源 vendor): $VENDOR"
  log "  sha256=$v_sha  lines=$v_lines"
  if [ -f "$TARGET" ]; then
    t_sha="$(sha_of "$TARGET")"
    t_lines="$(lines_of "$TARGET")"
    log "target (portal dist-public): $TARGET"
    log "  sha256=$t_sha  lines=$t_lines"
  else
    log "target (portal dist-public): $TARGET  [缺失 / not present]"
  fi
}

MODE="sync"
case "${1:-}" in
  --check)   MODE="check" ;;
  --dry-run) MODE="dry-run" ;;
  -h|--help) usage; exit 0 ;;
  "")        MODE="sync" ;;
  *)         err "unknown argument: $1"; usage; exit 2 ;;
esac

# The source of truth must always exist.
if [ ! -f "$VENDOR" ]; then
  err "可信源不存在 / source of truth missing: $VENDOR"
  exit 1
fi

# Handle missing portal repo per-mode.
if [ ! -d "$PORTAL_ROOT/dist-public" ]; then
  if [ "$MODE" = "check" ]; then
    log "WARNING: portal 源仓不存在，跳过 vendor<->dist-public 一致性校验 (EXPOOL_PORTAL_ROOT=$PORTAL_ROOT)"
    log "         (npm-only 环境下属正常，未做校验)"
    exit 0
  fi
  err "portal 源仓目录不存在: $PORTAL_ROOT/dist-public"
  err "请检查 EXPOOL_PORTAL_ROOT（缺省 <repo>/../experience-pool）后重试。"
  exit 1
fi

case "$MODE" in
  check)
    v_sha="$(sha_of "$VENDOR")"
    if [ ! -f "$TARGET" ]; then
      err "目标文件缺失: $TARGET"
      err "vendor 与 dist-public 不一致：运行 scripts/sync-vendor.sh 同步。"
      exit 1
    fi
    t_sha="$(sha_of "$TARGET")"
    if [ "$v_sha" = "$t_sha" ]; then
      log "OK: vendor 与 portal dist-public 的 exp_uploader.py 内容一致 (sha256=$v_sha)"
      exit 0
    fi
    err "MISMATCH: vendor 与 portal dist-public 的 exp_uploader.py 内容不一致。"
    err "  vendor : sha256=$v_sha  lines=$(lines_of "$VENDOR")"
    err "  portal : sha256=$t_sha  lines=$(lines_of "$TARGET")"
    err "  diff 摘要 (vendor vs portal):"
    diff "$VENDOR" "$TARGET" | head -n 40 >&2 || true
    err "请运行 scripts/sync-vendor.sh 同步（以 vendor 为可信源覆盖 dist-public）。"
    exit 1
    ;;

  dry-run)
    log "DRY-RUN: 将以 vendor 为可信源覆盖 portal dist-public（实际未写入）"
    print_compare
    if [ -f "$TARGET" ] && [ "$(sha_of "$VENDOR")" = "$(sha_of "$TARGET")" ]; then
      log "两边已一致，同步将无变化。"
    else
      log "两边不一致，真实执行时会用 vendor 覆盖 target。"
    fi
    exit 0
    ;;

  sync)
    log "同步：vendor (可信源) -> portal dist-public"
    print_compare
    cp "$VENDOR" "$TARGET"
    log "已覆盖目标: $TARGET"
    log "校验: new target sha256=$(sha_of "$TARGET")"
    exit 0
    ;;
esac
