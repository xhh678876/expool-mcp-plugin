#!/usr/bin/env bash
# Optional bridge to the portal repo's shared development/production config.
# This script is safe in npm-only checkouts where the portal repo is absent.

PLUGIN_REPO_ROOT="${PLUGIN_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
DEFAULT_PORTAL_ROOT="${EXPOOL_PORTAL_ROOT:-$PLUGIN_REPO_ROOT/../experience-pool}"
WORKSPACE_CONFIG="${EXPOOL_CONFIG_FILE:-$DEFAULT_PORTAL_ROOT/config/env.sh}"

if [ -n "${EXPOOL_CONFIG_FILE:-}" ] && [ ! -f "$WORKSPACE_CONFIG" ]; then
  printf '[workspace-env] configured file does not exist: %s\n' "$WORKSPACE_CONFIG" >&2
  return 2 2>/dev/null || exit 2
fi

if [ -f "$WORKSPACE_CONFIG" ]; then
  # shellcheck disable=SC1090
  . "$WORKSPACE_CONFIG"
fi

export EXPOOL_PORTAL_ROOT="${EXPOOL_PORTAL_ROOT:-$DEFAULT_PORTAL_ROOT}"
