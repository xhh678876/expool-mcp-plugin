#!/usr/bin/env bash
# Register the bundled expool MCP server into local agent registries.
#
# Native registries are preferred when a runtime exposes an MCP CLI:
#   - Claude Code: claude mcp add
#   - Codex:       codex mcp add
#
# OpenClaw / Hermes do not have a stable public CLI contract in this repo, so
# this script attempts a Claude-compatible "mcp add" first when the command is
# available, then writes a portable descriptor to ~/.<runtime>/mcp/expool.json.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SERVER="$PLUGIN_ROOT/servers/expool_mcp.py"

NAME="${EXPOOL_MCP_NAME:-expool}"
TARGETS="${EXPOOL_MCP_TARGETS:-claude,codex,openclaw,hermes}"
SCOPE="${EXPOOL_MCP_SCOPE:-user}"
BASE="${EXPOOL_BASE:-}"
MODE="${EXPOOL_MCP_MODE:-copy}"
FORCE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: register-mcp.sh [options]

Register the bundled expool MCP server into local agent registries.

Options:
  --targets LIST   Comma-separated targets. Default: claude,codex,openclaw,hermes
                   Known targets: claude,codex,openclaw,hermes,portable
  --name NAME      MCP server name. Default: expool
  --scope SCOPE    Claude Code scope. Default: user
  --base URL       Override EXPOOL_BASE for the MCP subprocess
  --copy           Copy server+vendor into each agent registry dir first (default)
  --direct         Register the server from the current plugin directory
  --force          Remove an existing server with the same name first
  --dry-run        Print actions without changing registry files
  -h, --help       Show this help

Examples:
  ./scripts/register-mcp.sh --targets claude,codex --force
  EXPOOL_BASE=<gateway-from-portal-/plugins> ./scripts/register-mcp.sh
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --targets|--target)
      TARGETS="${2:?missing value for $1}"
      shift 2
      ;;
    --name)
      NAME="${2:?missing value for --name}"
      shift 2
      ;;
    --scope)
      SCOPE="${2:?missing value for --scope}"
      shift 2
      ;;
    --base)
      BASE="${2:?missing value for --base}"
      shift 2
      ;;
    --copy)
      MODE="copy"
      shift
      ;;
    --direct)
      MODE="direct"
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'register-mcp: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$SERVER" ]; then
  printf 'register-mcp: MCP server not found: %s\n' "$SERVER" >&2
  exit 1
fi
if [ ! -f "$PLUGIN_ROOT/vendor/exp_uploader.py" ]; then
  printf 'register-mcp: vendored uploader not found: %s\n' "$PLUGIN_ROOT/vendor/exp_uploader.py" >&2
  exit 1
fi

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

note() {
  printf '[expool] %s\n' "$*" >&2
}

has_subcommand() {
  local bin="$1"
  shift
  command -v "$bin" >/dev/null 2>&1 || return 1
  "$bin" "$@" --help >/dev/null 2>&1
}

agent_mcp_root() {
  local runtime="$1"
  case "$runtime" in
    claude|claude-code) printf '%s\n' "$HOME/.claude/mcp-servers/$NAME" ;;
    codex) printf '%s\n' "$HOME/.codex/mcp-servers/$NAME" ;;
    openclaw) printf '%s\n' "$HOME/.openclaw/mcp-servers/$NAME" ;;
    hermes) printf '%s\n' "$HOME/.hermes/mcp-servers/$NAME" ;;
    *) printf '%s\n' "$HOME/.$runtime/mcp-servers/$NAME" ;;
  esac
}

prepare_server_for_runtime() {
  local runtime="$1"
  local root
  local server

  if [ "$MODE" = "direct" ]; then
    printf '%s\t%s\n' "$PLUGIN_ROOT" "$SERVER"
    return 0
  fi

  root="$(agent_mcp_root "$runtime")"
  server="$root/servers/expool_mcp.py"

  if [ "$DRY_RUN" = "1" ]; then
    note "would install runtime copy: $root"
  else
    mkdir -p "$root/servers" "$root/vendor" "$root/scripts"
    cp "$PLUGIN_ROOT/servers/expool_mcp.py" "$root/servers/expool_mcp.py"
    cp "$PLUGIN_ROOT/servers/requirements.txt" "$root/servers/requirements.txt" 2>/dev/null || true
    cp "$PLUGIN_ROOT/vendor/exp_uploader.py" "$root/vendor/exp_uploader.py"
    cp "$PLUGIN_ROOT/scripts/auto-upload.sh" "$root/scripts/auto-upload.sh" 2>/dev/null || true
    chmod 700 "$root" "$root/servers" "$root/vendor" "$root/scripts" 2>/dev/null || true
    chmod 600 "$root/servers/expool_mcp.py" "$root/vendor/exp_uploader.py" 2>/dev/null || true
    chmod 700 "$root/scripts/auto-upload.sh" 2>/dev/null || true
    note "installed runtime copy: $root"
  fi

  printf '%s\t%s\n' "$root" "$server"
}

write_runner() {
  local root="$1"
  local server_path="$2"
  local runner="$root/scripts/expool-mcp-runner.sh"

  if [ "$DRY_RUN" = "1" ]; then
    note "would write MCP runner: $runner"
    printf '%s\n' "$runner"
    return 0
  fi

  mkdir -p "$root/scripts"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'export EXPOOL_PLUGIN_ROOT=%q\n' "$root"
    printf 'export PYTHONUNBUFFERED=1\n'
    if [ -n "$BASE" ]; then
      printf 'export EXPOOL_BASE=%q\n' "$BASE"
    fi
    printf 'exec python3 %q\n' "$server_path"
  } > "$runner"
  chmod 700 "$runner"
  printf '%s\n' "$runner"
}

write_portable_descriptor() {
  local runtime="$1"
  local root
  local file
  local plugin_root_for_descriptor="$PLUGIN_ROOT"
  local server_for_descriptor="$SERVER"

  if [ "$runtime" = "portable" ]; then
    root="$PLUGIN_ROOT/registry"
  else
    root="$HOME/.$runtime/mcp"
  fi
  file="$root/$NAME.json"

  if [ "$DRY_RUN" = "1" ]; then
    note "would write portable descriptor: $file"
    return 0
  fi

  mkdir -p "$root"
  if [ "$runtime" != "portable" ]; then
    local prepared
    prepared="$(prepare_server_for_runtime "$runtime")"
    plugin_root_for_descriptor="${prepared%%	*}"
    server_for_descriptor="${prepared#*	}"
  fi

  python3 - "$file" "$NAME" "$server_for_descriptor" "$plugin_root_for_descriptor" "$BASE" <<'PY'
import json
import sys
from pathlib import Path

path, name, server, plugin_root, base = sys.argv[1:]
env = {
    "EXPOOL_PLUGIN_ROOT": plugin_root,
    "PYTHONUNBUFFERED": "1",
}
if base:
    env["EXPOOL_BASE"] = base

payload = {
    "mcpServers": {
        name: {
            "type": "stdio",
            "command": "python3",
            "args": [server],
            "env": env,
        }
    }
}

p = Path(path)
p.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
p.chmod(0o600)
PY
  note "wrote portable descriptor: $file"
}

register_claude() {
  local prepared plugin_root server_path runner
  if ! command -v claude >/dev/null 2>&1; then
    note "claude not found; skipped"
    return 0
  fi
  prepared="$(prepare_server_for_runtime claude)"
  plugin_root="${prepared%%	*}"
  server_path="${prepared#*	}"
  runner="$(write_runner "$plugin_root" "$server_path")"
  if [ "$FORCE" = "1" ]; then
    run claude mcp remove --scope "$SCOPE" "$NAME" >/dev/null 2>&1 || true
  fi
  run claude mcp add \
    --scope "$SCOPE" \
    --transport stdio \
    "$NAME" -- "$runner"
  note "registered $NAME in Claude Code MCP registry"
}

register_codex() {
  local prepared plugin_root server_path runner
  if ! command -v codex >/dev/null 2>&1; then
    note "codex not found; skipped"
    return 0
  fi
  prepared="$(prepare_server_for_runtime codex)"
  plugin_root="${prepared%%	*}"
  server_path="${prepared#*	}"
  runner="$(write_runner "$plugin_root" "$server_path")"
  if [ "$FORCE" = "1" ]; then
    run codex mcp remove "$NAME" >/dev/null 2>&1 || true
  fi
  run codex mcp add \
    "$NAME" -- "$runner"
  note "registered $NAME in Codex MCP registry"
}

register_claude_compatible_or_descriptor() {
  local runtime="$1"
  local prepared plugin_root server_path runner
  if has_subcommand "$runtime" mcp add; then
    prepared="$(prepare_server_for_runtime "$runtime")"
    plugin_root="${prepared%%	*}"
    server_path="${prepared#*	}"
    runner="$(write_runner "$plugin_root" "$server_path")"
    if [ "$FORCE" = "1" ]; then
      run "$runtime" mcp remove "$NAME" >/dev/null 2>&1 || true
    fi
    run "$runtime" mcp add \
      --transport stdio \
      "$NAME" -- "$runner"
    note "registered $NAME in $runtime MCP registry"
  else
    note "$runtime native MCP CLI not found; writing portable descriptor"
    write_portable_descriptor "$runtime"
  fi
}

IFS=',' read -r -a target_array <<< "$TARGETS"
for raw_target in "${target_array[@]}"; do
  target="$(printf '%s' "$raw_target" | tr '[:upper:]' '[:lower:]' | xargs)"
  [ -n "$target" ] || continue
  case "$target" in
    claude|claude-code)
      register_claude
      ;;
    codex)
      register_codex
      ;;
    openclaw|hermes)
      register_claude_compatible_or_descriptor "$target"
      ;;
    portable)
      write_portable_descriptor portable
      ;;
    *)
      printf 'register-mcp: unknown target: %s\n' "$target" >&2
      exit 2
      ;;
  esac
done

note "done"
