#!/usr/bin/env bash
# Build local release artifacts for environments where npm/GitHub publishing
# must be performed from another machine.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
# shellcheck disable=SC1091
. "$ROOT/scripts/load-workspace-env.sh"

mkdir -p dist
rm -f dist/*.tgz dist/*.bundle

bash scripts/release-check.sh

tgz="$(npm pack --pack-destination dist --silent)"
printf '[release-artifacts] npm tarball: dist/%s\n' "$tgz"

portal_root="$EXPOOL_PORTAL_ROOT"
if [ -d "$portal_root/dist-public" ]; then
  # 把 vendor 的 exp_uploader.py（可信源）也一起同步进源仓 dist-public，
  # 不只是 .tgz，避免源仓里的 .py 本体漂移落后。
  EXPOOL_PORTAL_ROOT="$portal_root" bash scripts/sync-vendor.sh
  mkdir -p "$portal_root/dist-public/plugins"
  cp "dist/$tgz" "$portal_root/dist-public/plugins/$tgz"
  cp "dist/$tgz" "$portal_root/dist-public/plugins/expool.tgz"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$portal_root/dist-public/plugins/$tgz" \
      > "$portal_root/dist-public/plugins/$tgz.sha256"
    sha256sum "$portal_root/dist-public/plugins/expool.tgz" \
      > "$portal_root/dist-public/plugins/expool.tgz.sha256"
  fi
  printf '[release-artifacts] portal copy: %s\n' "$portal_root/dist-public/plugins/$tgz"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    git bundle create dist/expool-mcp-plugin.bundle --all >/dev/null
    printf '[release-artifacts] git bundle: dist/expool-mcp-plugin.bundle\n'
  else
    printf '[release-artifacts] skip git bundle: no commits yet\n'
  fi
else
  printf '[release-artifacts] skip git bundle: not a git repository\n'
fi
