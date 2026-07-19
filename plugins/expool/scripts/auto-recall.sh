#!/usr/bin/env bash
# Manage Experience Pool automatic recall.
#
# Claude Code supports real UserPromptSubmit hooks. Codex does not expose the
# same hook contract here, so Codex is enabled by installing a managed AGENTS.md
# instruction block that requires platform RAG recall before non-trivial work.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AUTO_SEARCH="$PLUGIN_ROOT/scripts/auto-search.sh"
UPLOADER="$PLUGIN_ROOT/vendor/exp_uploader.py"

COMMAND="${1:-status}"
[ "$#" -gt 0 ] && shift || true

TARGETS="${EXPOOL_RECALL_TARGETS:-claude,codex}"
SCOPE="${EXPOOL_AUTO_SEARCH_SCOPE:-personal}"
TOP_K="${EXPOOL_AUTO_SEARCH_TOP_K:-3}"
MIN_CHARS="${EXPOOL_AUTO_SEARCH_MIN_CHARS:-20}"
TIMEOUT_SECONDS="${EXPOOL_AUTO_SEARCH_TIMEOUT:-8}"
BASE="${EXPOOL_BASE:-}"
DRY_RUN=0

CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CODEX_AGENTS="$HOME/.codex/AGENTS.md"

usage() {
  cat <<'EOF'
Usage: auto-recall.sh <on|off|status|search> [options]

Options:
  --targets LIST      Comma-separated targets: claude,codex. Default: claude,codex
  --scope SCOPE       Search scope for automatic recall. Default: personal
  --top-k N           Number of experiences to recall. Default: 3
  --min-chars N       Skip prompts shorter than N chars. Default: 20
  --timeout N         Search timeout in seconds. Default: 8
  --base URL          Gateway base URL passed to exp_uploader.py
  --q TEXT            Query text for `search`
  --dry-run           Print intended changes without writing config
  -h, --help          Show this help

Examples:
  ./scripts/auto-recall.sh on --targets claude,codex --scope personal --top-k 3
  ./scripts/auto-recall.sh status
  ./scripts/auto-recall.sh search --q "修复 FastAPI HMAC 签名失败"
EOF
}

QUERY=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --targets|--target)
      TARGETS="${2:?missing value for $1}"
      shift 2
      ;;
    --scope)
      SCOPE="${2:?missing value for --scope}"
      shift 2
      ;;
    --top-k)
      TOP_K="${2:?missing value for --top-k}"
      shift 2
      ;;
    --min-chars)
      MIN_CHARS="${2:?missing value for --min-chars}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:?missing value for --timeout}"
      shift 2
      ;;
    --base)
      BASE="${2:?missing value for --base}"
      shift 2
      ;;
    --q)
      QUERY="${2:?missing value for --q}"
      shift 2
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
      if [ "$COMMAND" = "search" ] && [ -z "$QUERY" ]; then
        QUERY="$1"
        shift
      else
        printf 'auto-recall: unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

note() {
  printf '[expool] %s\n' "$*" >&2
}

validate_number() {
  local name="$1"
  local value="$2"
  if ! printf '%s' "$value" | grep -Eq '^[0-9]+$'; then
    printf 'auto-recall: %s must be an integer, got %s\n' "$name" "$value" >&2
    exit 2
  fi
}

has_target() {
  local want="$1"
  IFS=',' read -r -a parts <<< "$TARGETS"
  local part
  for part in "${parts[@]}"; do
    part="$(printf '%s' "$part" | tr '[:upper:]' '[:lower:]' | xargs)"
    case "$want:$part" in
      claude:claude|claude:claude-code|codex:codex) return 0 ;;
    esac
  done
  return 1
}

patch_claude_on() {
  if [ ! -f "$AUTO_SEARCH" ]; then
    printf 'auto-recall: auto-search hook script not found: %s\n' "$AUTO_SEARCH" >&2
    exit 1
  fi
  if [ "$DRY_RUN" = "1" ]; then
    note "would enable Claude Code UserPromptSubmit recall hook in $CLAUDE_SETTINGS"
    return 0
  fi
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  python3 - "$CLAUDE_SETTINGS" "$AUTO_SEARCH" "$SCOPE" "$TOP_K" "$MIN_CHARS" "$TIMEOUT_SECONDS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
command, scope, top_k, min_chars, timeout = sys.argv[2:]
try:
    data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
except Exception:
    data = {}

env = data.setdefault("env", {})
env["EXPOOL_AUTO_SEARCH"] = "1"
env["EXPOOL_AUTO_SEARCH_SCOPE"] = scope
env["EXPOOL_AUTO_SEARCH_TOP_K"] = top_k
env["EXPOOL_AUTO_SEARCH_MIN_CHARS"] = min_chars
env["EXPOOL_AUTO_SEARCH_TIMEOUT"] = timeout

hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("UserPromptSubmit", [])
hook = {"type": "command", "command": command, "timeout": max(15, int(timeout) + 5)}

for entry in entries:
    if not isinstance(entry, dict):
        continue
    if entry.get("matcher", "") != "":
        continue
    item_hooks = entry.setdefault("hooks", [])
    item_hooks[:] = [
        h for h in item_hooks
        if not (isinstance(h, dict) and h.get("type") == "command" and h.get("command") == command)
    ]
    item_hooks.append(hook)
    break
else:
    entries.append({"matcher": "", "hooks": [hook]})

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
path.chmod(0o600)
PY
  note "enabled Claude Code auto recall hook"
}

patch_claude_off() {
  if [ "$DRY_RUN" = "1" ]; then
    note "would set EXPOOL_AUTO_SEARCH=0 in $CLAUDE_SETTINGS"
    return 0
  fi
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  python3 - "$CLAUDE_SETTINGS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
try:
    data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
except Exception:
    data = {}
env = data.setdefault("env", {})
env["EXPOOL_AUTO_SEARCH"] = "0"
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
path.chmod(0o600)
PY
  note "disabled Claude Code auto recall via EXPOOL_AUTO_SEARCH=0"
}

codex_block() {
  cat <<EOF
<!-- expool-auto-recall — managed by expool-plugin -->
# expool auto-recall contract

Before starting any non-trivial user task, perform an Experience Pool recall
pass and read the generated RAG context before planning or editing.

Preferred path:
- Call `mcp__expool__exp_rag_context` with `scope=$SCOPE`,
  `top_k=$TOP_K`, and a one-line summary of the current local task.
- Keep the returned `event_id` for task-boundary feedback.

CLI fallback when the MCP tool is unavailable:

\`\`\`bash
expool-plugin recall search --scope $SCOPE --top-k $TOP_K --q "<one-line task summary>"
\`\`\`

Use the generated context only when it is relevant. Summarize reusable steps
and pitfalls in your own words; never paste raw JSON. If there is no relevant
context, say so briefly and continue from first principles.

After the task finishes, if an MCP recall event was returned, call
`mcp__expool__exp_reuse_feedback` once: reward `+1` when a recalled item was
used and helped, `0` when it was not used/irrelevant, and `-1` when it
misled the task. Use confidence `0.35` and a short factual reason.

<!-- end expool-auto-recall -->
EOF
}

patch_codex_on() {
  if [ "$DRY_RUN" = "1" ]; then
    note "would install Codex auto-recall AGENTS block in $CODEX_AGENTS"
    return 0
  fi
  mkdir -p "$(dirname "$CODEX_AGENTS")"
  local tmp
  tmp="$(mktemp)"
  if [ -f "$CODEX_AGENTS" ]; then
    python3 - "$CODEX_AGENTS" "$tmp" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
text = re.sub(
    r"\n?<!-- expool-auto-recall — managed by expool-plugin -->.*?<!-- end expool-auto-recall -->\n?",
    "\n",
    text,
    flags=re.S,
)
dst.write_text(text.rstrip() + "\n\n", encoding="utf-8")
PY
  else
    : > "$tmp"
  fi
  codex_block >> "$tmp"
  mv "$tmp" "$CODEX_AGENTS"
  chmod 600 "$CODEX_AGENTS" 2>/dev/null || true
  note "enabled Codex auto recall contract"
}

patch_codex_off() {
  if [ "$DRY_RUN" = "1" ]; then
    note "would remove Codex auto-recall AGENTS block from $CODEX_AGENTS"
    return 0
  fi
  [ -f "$CODEX_AGENTS" ] || return 0
  local tmp
  tmp="$(mktemp)"
  python3 - "$CODEX_AGENTS" "$tmp" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
text = src.read_text(encoding="utf-8")
text = re.sub(
    r"\n?<!-- expool-auto-recall — managed by expool-plugin -->.*?<!-- end expool-auto-recall -->\n?",
    "\n",
    text,
    flags=re.S,
)
dst.write_text(text.rstrip() + "\n", encoding="utf-8")
PY
  mv "$tmp" "$CODEX_AGENTS"
  chmod 600 "$CODEX_AGENTS" 2>/dev/null || true
  note "disabled Codex auto recall contract"
}

status_cmd() {
  printf 'auto_recall=expool\n'
  printf 'targets=%s\n' "$TARGETS"
  printf 'scope=%s\n' "$SCOPE"
  printf 'top_k=%s\n' "$TOP_K"
  printf 'min_chars=%s\n' "$MIN_CHARS"
  printf 'timeout_seconds=%s\n' "$TIMEOUT_SECONDS"
  printf 'claude_settings=%s\n' "$CLAUDE_SETTINGS"
  printf 'codex_agents=%s\n' "$CODEX_AGENTS"
  python3 - "$CLAUDE_SETTINGS" "$CODEX_AGENTS" "$AUTO_SEARCH" <<'PY'
import json
import sys
from pathlib import Path

claude = Path(sys.argv[1]).expanduser()
codex = Path(sys.argv[2]).expanduser()
hook = sys.argv[3]

try:
    data = json.loads(claude.read_text(encoding="utf-8")) if claude.exists() else {}
except Exception:
    data = {}
env = data.get("env") or {}
hooks = data.get("hooks") or {}
user_hooks = hooks.get("UserPromptSubmit") or []
hook_present = any(
    isinstance(entry, dict)
    and any(isinstance(h, dict) and h.get("command") == hook for h in entry.get("hooks", []))
    for entry in user_hooks
)
print(f"claude_enabled={env.get('EXPOOL_AUTO_SEARCH', '0') == '1' and hook_present}")
print(f"claude_hook_present={hook_present}")
print(f"claude_scope={env.get('EXPOOL_AUTO_SEARCH_SCOPE', 'personal')}")
print(f"claude_top_k={env.get('EXPOOL_AUTO_SEARCH_TOP_K', '3')}")

codex_text = codex.read_text(encoding="utf-8") if codex.exists() else ""
codex_enabled = "<!-- expool-auto-recall — managed by expool-plugin -->" in codex_text
print(f"codex_enabled={codex_enabled}")
PY
}

search_cmd() {
  if [ -z "$QUERY" ]; then
    printf 'auto-recall: --q is required for search\n' >&2
    exit 2
  fi
  if [ ! -f "$UPLOADER" ]; then
    printf 'auto-recall: uploader not found: %s\n' "$UPLOADER" >&2
    exit 1
  fi
  args=(python3 "$UPLOADER")
  if [ -n "$BASE" ]; then
    args+=(--base "$BASE")
  fi
  args+=(rag-context --q "$QUERY" --scope "$SCOPE" --top-k "$TOP_K")
  if ! "${args[@]}"; then
    args=(python3 "$UPLOADER")
    if [ -n "$BASE" ]; then
      args+=(--base "$BASE")
    fi
    args+=(search --q "$QUERY" --scope "$SCOPE" --top-k "$TOP_K")
    "${args[@]}"
  fi
}

validate_number "--top-k" "$TOP_K"
validate_number "--min-chars" "$MIN_CHARS"
validate_number "--timeout" "$TIMEOUT_SECONDS"

case "$COMMAND" in
  on|enable|start)
    has_target claude && patch_claude_on
    has_target codex && patch_codex_on
    ;;
  off|disable|stop)
    has_target claude && patch_claude_off
    has_target codex && patch_codex_off
    ;;
  status)
    status_cmd
    ;;
  search)
    search_cmd
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    printf 'auto-recall: unknown command: %s\n' "$COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
