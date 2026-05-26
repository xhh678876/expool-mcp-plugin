#!/usr/bin/env bash
# Manage Experience Pool automatic upload scheduling.
#
# This script is intentionally separate from the MCP server. It gives users a
# normal terminal control plane:
#   auto-upload.sh start|stop|status|tick|logs
#
# start installs a user-level scheduler where possible:
#   - Linux: systemd user timer
#   - macOS: launchd user agent
#   - fallback: per-user background loop with a pid file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CLI="$PLUGIN_ROOT/vendor/exp_uploader.py"
SELF="$SCRIPT_DIR/auto-upload.sh"

DEFAULT_BASE="${EXPOOL_BASE:-${EXP_BIND_BASE_URL:-${EXP_PUBLIC_BASE_URL:-}}}"
if [ -z "$DEFAULT_BASE" ] && [ -n "${EXP_UI_PUBLIC_URL:-}" ]; then
  if [[ "${EXP_UI_PUBLIC_URL%/}" =~ ^(.*)/proxy/[0-9]+$ ]]; then
    DEFAULT_BASE="${BASH_REMATCH[1]}/proxy/3080"
  fi
fi
DEFAULT_BASE="${DEFAULT_BASE:-https://expool.clawsii.com}"
COMMAND="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

SOURCES="${EXP_AUTO_SOURCES:-claude-code,codex,hermes}"
INTERVAL="${EXPOOL_AUTO_INTERVAL:-120}"
MAX_PER_SOURCE="${EXPOOL_AUTO_MAX_PER_SOURCE:-10}"
MAX_SESSION_KB="${EXPOOL_AUTO_MAX_SESSION_KB:-4096}"
ACL="${EXP_AUTO_ACL:-private}"
TASK="${EXP_AUTO_TASK:-auto-sync}"
BASE="$DEFAULT_BASE"
CRED_DIR="${EXPOOL_CRED_DIR:-$HOME/.config/expool}"
STATE_ROOT="${EXPOOL_STATE_ROOT:-$HOME/.local/share/expool}"
MODE="${EXPOOL_AUTO_MODE:-auto}"
ALLOW_SHARED_ACL=0
DRY_RUN=0
VERBOSE=0

SERVICE_NAME="expool-auto-upload"
SYSTEMD_SERVICE="$SERVICE_NAME.service"
SYSTEMD_TIMER="$SERVICE_NAME.timer"
LAUNCHD_LABEL="cn.edu.sii.expool.auto-upload"

usage() {
  cat <<'EOF'
Usage: auto-upload.sh <command> [options]

Commands:
  start      Enable automatic upload scheduling.
  stop       Disable automatic upload scheduling.
  status     Show scheduler status and daemon upload state.
  tick       Run one incremental upload pass now.
  logs       Show recent scheduler logs.

Aliases:
  enable/on  -> start
  disable/off -> stop

Options:
  --sources LIST          Comma-separated sources. Default: claude-code,codex,hermes
  --interval SEC          Scheduler interval for start. Default: 120
  --max-per-source N      Max uploads per source per tick. Default: 10
  --max-session-kb KB     Skip sessions larger than this. Default: 4096
  --task TASK             Task classifier for auto uploads. Default: auto-sync
  --acl ACL               Upload ACL. Default: private
  --allow-shared-acl      Required if --acl is public or team:<name>
  --base URL              Experience-pool gateway URL
  --cred-dir DIR          Credential directory. Default: ~/.config/expool
  --state-root DIR        State/log directory. Default: ~/.local/share/expool
  --mode MODE             auto|systemd|launchd|loop. Default: auto
  --dry-run               For start/stop, preview scheduler changes. For tick, upload nothing.
  --verbose               Pass verbose logging to daemon-tick.
  -h, --help              Show this help.

Examples:
  ./scripts/auto-upload.sh start --sources claude-code,codex --interval 180
  ./scripts/auto-upload.sh status
  ./scripts/auto-upload.sh stop
  ./scripts/auto-upload.sh tick --dry-run
EOF
}

case "$COMMAND" in
  enable|on) COMMAND="start" ;;
  disable|off) COMMAND="stop" ;;
  ""|-h|--help)
    usage
    exit 0
    ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    --sources)
      SOURCES="${2:?missing value for --sources}"
      shift 2
      ;;
    --interval)
      INTERVAL="${2:?missing value for --interval}"
      shift 2
      ;;
    --max-per-source)
      MAX_PER_SOURCE="${2:?missing value for --max-per-source}"
      shift 2
      ;;
    --max-session-kb)
      MAX_SESSION_KB="${2:?missing value for --max-session-kb}"
      shift 2
      ;;
    --task)
      TASK="${2:?missing value for --task}"
      shift 2
      ;;
    --acl)
      ACL="${2:?missing value for --acl}"
      shift 2
      ;;
    --allow-shared-acl)
      ALLOW_SHARED_ACL=1
      shift
      ;;
    --base)
      BASE="${2:?missing value for --base}"
      shift 2
      ;;
    --cred-dir)
      CRED_DIR="${2:?missing value for --cred-dir}"
      shift 2
      ;;
    --state-root)
      STATE_ROOT="${2:?missing value for --state-root}"
      shift 2
      ;;
    --mode)
      MODE="${2:?missing value for --mode}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'auto-upload: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

abs_path() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path

print(Path(sys.argv[1]).expanduser().resolve(strict=False))
PY
}

STATE_ROOT="$(abs_path "$STATE_ROOT")"
CRED_DIR="$(abs_path "$CRED_DIR")"
STATE_PATH="$STATE_ROOT/state.json"
LOG_DIR="$STATE_ROOT/logs"
LOG_FILE="$LOG_DIR/auto-upload.log"
PID_FILE="$STATE_ROOT/auto-upload.pid"
TICK_WRAPPER="$STATE_ROOT/auto-upload-tick.sh"
LOOP_WRAPPER="$STATE_ROOT/auto-upload-loop.sh"

note() {
  printf '[expool] %s\n' "$*" >&2
}

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

ensure_cli() {
  if [ ! -f "$CLI" ]; then
    printf 'auto-upload: vendored uploader not found: %s\n' "$CLI" >&2
    exit 1
  fi
}

credential_present() {
  if [ -n "${EXP_AGENT_NAME:-}" ] && [ -n "${EXP_AGENT_SECRET:-}" ]; then
    return 0
  fi
  compgen -G "$CRED_DIR/*.json" >/dev/null 2>&1
}

validate_shared_acl() {
  case "$ACL" in
    private|"")
      ACL="private"
      ;;
    public|team:*)
      if [ "$ALLOW_SHARED_ACL" != "1" ]; then
        printf 'auto-upload: refusing acl=%s without --allow-shared-acl\n' "$ACL" >&2
        printf 'auto-upload: default automatic uploads should stay private.\n' >&2
        exit 2
      fi
      ;;
    *)
      printf 'auto-upload: unsupported acl: %s\n' "$ACL" >&2
      exit 2
      ;;
  esac
}

validate_number() {
  local name="$1"
  local value="$2"
  if ! printf '%s' "$value" | grep -Eq '^[0-9]+$'; then
    printf 'auto-upload: %s must be an integer, got %s\n' "$name" "$value" >&2
    exit 2
  fi
}

tick_cmd() {
  local args=(
    python3 "$CLI"
    --base "$BASE"
    daemon-tick
    --sources "$SOURCES"
    --max-per-source "$MAX_PER_SOURCE"
    --max-session-kb "$MAX_SESSION_KB"
    --acl "$ACL"
    --task "$TASK"
  )
  if [ "$COMMAND" = "tick" ] && [ "$DRY_RUN" = "1" ]; then
    args+=(--dry-run)
  fi
  if [ "$VERBOSE" = "1" ]; then
    args+=(--verbose)
  fi
  env \
    "EXP_CRED_DIR=$CRED_DIR" \
    "EXP_STATE_PATH=$STATE_PATH" \
    "EXP_AUTO_SOURCES=$SOURCES" \
    "EXP_AUTO_ACL=$ACL" \
    "EXP_AUTO_TASK=$TASK" \
    "${args[@]}"
}

state_cmd() {
  env \
    "EXP_CRED_DIR=$CRED_DIR" \
    "EXP_STATE_PATH=$STATE_PATH" \
    python3 "$CLI" --base "$BASE" daemon-state
}

write_tick_wrapper() {
  if [ "$DRY_RUN" = "1" ]; then
    note "would write tick wrapper: $TICK_WRAPPER"
    return 0
  fi
  mkdir -p "$STATE_ROOT" "$LOG_DIR"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'export EXP_CRED_DIR=%q\n' "$CRED_DIR"
    printf 'export EXP_STATE_PATH=%q\n' "$STATE_PATH"
    printf 'export EXP_AUTO_SOURCES=%q\n' "$SOURCES"
    printf 'export EXP_AUTO_ACL=%q\n' "$ACL"
    printf 'export EXP_AUTO_TASK=%q\n' "$TASK"
    printf 'exec python3 %q --base %q daemon-tick --sources %q --max-per-source %q --max-session-kb %q --acl %q --task %q\n' \
      "$CLI" "$BASE" "$SOURCES" "$MAX_PER_SOURCE" "$MAX_SESSION_KB" "$ACL" "$TASK"
  } > "$TICK_WRAPPER"
  chmod 700 "$TICK_WRAPPER"
}

write_loop_wrapper() {
  if [ "$DRY_RUN" = "1" ]; then
    note "would write loop wrapper: $LOOP_WRAPPER"
    return 0
  fi
  mkdir -p "$STATE_ROOT" "$LOG_DIR"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf 'while :; do\n'
    printf '  bash %q tick --sources %q --max-per-source %q --max-session-kb %q --acl %q --task %q --base %q --cred-dir %q --state-root %q' \
      "$SELF" "$SOURCES" "$MAX_PER_SOURCE" "$MAX_SESSION_KB" "$ACL" "$TASK" "$BASE" "$CRED_DIR" "$STATE_ROOT"
    if [ "$ALLOW_SHARED_ACL" = "1" ]; then
      printf ' --allow-shared-acl'
    fi
    printf ' >> %q 2>&1 || true\n' "$LOG_FILE"
    printf '  sleep %q\n' "$INTERVAL"
    printf 'done\n'
  } > "$LOOP_WRAPPER"
  chmod 700 "$LOOP_WRAPPER"
}

systemd_available() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user show-environment >/dev/null 2>&1
}

launchd_available() {
  [ "$(uname -s)" = "Darwin" ] && command -v launchctl >/dev/null 2>&1
}

selected_mode() {
  case "$MODE" in
    systemd|launchd|loop) printf '%s\n' "$MODE" ;;
    auto)
      if systemd_available; then
        printf 'systemd\n'
      elif launchd_available; then
        printf 'launchd\n'
      else
        printf 'loop\n'
      fi
      ;;
    *)
      printf 'auto-upload: unknown mode: %s\n' "$MODE" >&2
      exit 2
      ;;
  esac
}

start_systemd() {
  local unit_dir="$HOME/.config/systemd/user"
  local service="$unit_dir/$SYSTEMD_SERVICE"
  local timer="$unit_dir/$SYSTEMD_TIMER"

  write_tick_wrapper
  if [ "$DRY_RUN" = "1" ]; then
    note "would write systemd service: $service"
    note "would write systemd timer: $timer"
    run systemctl --user daemon-reload
    run systemctl --user enable --now "$SYSTEMD_TIMER"
    return 0
  fi

  mkdir -p "$unit_dir"
  cat > "$service" <<EOF
[Unit]
Description=Experience Pool automatic upload tick

[Service]
Type=oneshot
ExecStart=$TICK_WRAPPER
EOF

  cat > "$timer" <<EOF
[Unit]
Description=Run Experience Pool automatic upload every $INTERVAL seconds

[Timer]
OnBootSec=30
OnUnitActiveSec=$INTERVAL
Unit=$SYSTEMD_SERVICE

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now "$SYSTEMD_TIMER"
  note "enabled systemd user timer: $SYSTEMD_TIMER"
}

stop_systemd() {
  local unit_dir="$HOME/.config/systemd/user"
  if [ "$DRY_RUN" = "1" ]; then
    run systemctl --user disable --now "$SYSTEMD_TIMER"
  else
    systemctl --user disable --now "$SYSTEMD_TIMER" >/dev/null 2>&1 || true
  fi
  run rm -f "$unit_dir/$SYSTEMD_TIMER" "$unit_dir/$SYSTEMD_SERVICE"
  if [ "$DRY_RUN" = "1" ]; then
    run systemctl --user daemon-reload
  else
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  note "disabled systemd user timer: $SYSTEMD_TIMER"
}

start_launchd() {
  local agent_dir="$HOME/Library/LaunchAgents"
  local plist="$agent_dir/$LAUNCHD_LABEL.plist"

  write_tick_wrapper
  if [ "$DRY_RUN" = "1" ]; then
    note "would write launchd plist: $plist"
    run launchctl bootstrap "gui/$(id -u)" "$plist"
    return 0
  fi

  mkdir -p "$agent_dir" "$LOG_DIR"
  python3 - "$plist" "$LAUNCHD_LABEL" "$TICK_WRAPPER" "$INTERVAL" "$LOG_FILE" <<'PY'
import plistlib
import sys
from pathlib import Path

path, label, tick, interval, log_file = sys.argv[1:]
payload = {
    "Label": label,
    "ProgramArguments": [tick],
    "StartInterval": int(interval),
    "RunAtLoad": True,
    "StandardOutPath": log_file,
    "StandardErrorPath": log_file,
}
p = Path(path)
p.write_bytes(plistlib.dumps(payload, sort_keys=False))
PY
  launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
  launchctl enable "gui/$(id -u)/$LAUNCHD_LABEL" >/dev/null 2>&1 || true
  note "enabled launchd agent: $LAUNCHD_LABEL"
}

stop_launchd() {
  local plist="$HOME/Library/LaunchAgents/$LAUNCHD_LABEL.plist"
  if [ "$DRY_RUN" = "1" ]; then
    run launchctl bootout "gui/$(id -u)" "$plist"
  else
    launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
  fi
  run rm -f "$plist"
  note "disabled launchd agent: $LAUNCHD_LABEL"
}

start_loop() {
  write_loop_wrapper
  if [ "$DRY_RUN" = "1" ]; then
    note "would start background loop and write pid file: $PID_FILE"
    return 0
  fi
  if [ -f "$PID_FILE" ]; then
    local old_pid
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$old_pid" ] && kill -0 "$old_pid" >/dev/null 2>&1; then
      note "background loop already running: pid=$old_pid"
      return 0
    fi
  fi
  nohup "$LOOP_WRAPPER" >/dev/null 2>&1 &
  printf '%s\n' "$!" > "$PID_FILE"
  chmod 600 "$PID_FILE"
  note "started background loop: pid=$!"
}

stop_loop() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        run kill "$pid"
      else
        kill "$pid" >/dev/null 2>&1 || true
      fi
    fi
  fi
  run rm -f "$PID_FILE" "$LOOP_WRAPPER"
  note "stopped background loop"
}

cmd_start() {
  ensure_cli
  validate_shared_acl
  validate_number "--interval" "$INTERVAL"
  validate_number "--max-per-source" "$MAX_PER_SOURCE"
  validate_number "--max-session-kb" "$MAX_SESSION_KB"
  if ! credential_present; then
    note "warning: no credential found in $CRED_DIR; run /expool:bind before uploads can succeed"
  fi
  local mode
  mode="$(selected_mode)"
  case "$mode" in
    systemd) start_systemd ;;
    launchd) start_launchd ;;
    loop) start_loop ;;
  esac
}

cmd_stop() {
  if [ "$MODE" = "auto" ]; then
    if command -v systemctl >/dev/null 2>&1; then
      stop_systemd
    fi
    if launchd_available; then
      stop_launchd
    fi
    stop_loop
    return 0
  fi
  local mode
  mode="$(selected_mode)"
  case "$mode" in
    systemd) stop_systemd ;;
    launchd) stop_launchd ;;
    loop) stop_loop ;;
  esac
}

cmd_status() {
  ensure_cli
  printf 'auto_upload=%s\n' "$SERVICE_NAME"
  printf 'plugin_root=%s\n' "$PLUGIN_ROOT"
  printf 'sources=%s\n' "$SOURCES"
  printf 'interval_seconds=%s\n' "$INTERVAL"
  printf 'credential_dir=%s\n' "$CRED_DIR"
  printf 'state_path=%s\n' "$STATE_PATH"
  printf 'gateway=%s\n' "$BASE"

  if systemd_available && systemctl --user list-unit-files "$SYSTEMD_TIMER" >/dev/null 2>&1; then
    printf 'systemd_timer=%s\n' "$(systemctl --user is-active "$SYSTEMD_TIMER" 2>/dev/null || true)"
  fi
  if launchd_available; then
    if launchctl print "gui/$(id -u)/$LAUNCHD_LABEL" >/dev/null 2>&1; then
      printf 'launchd_agent=active\n'
    else
      printf 'launchd_agent=inactive\n'
    fi
  fi
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
      printf 'loop_pid=%s\n' "$pid"
    else
      printf 'loop_pid=stale\n'
    fi
  fi

  printf '\n[daemon-state]\n'
  state_cmd || true
}

cmd_logs() {
  if systemd_available; then
    journalctl --user -u "$SYSTEMD_SERVICE" -n 80 --no-pager 2>/dev/null || true
  fi
  if [ -f "$LOG_FILE" ]; then
    printf '\n[loop/launchd log: %s]\n' "$LOG_FILE"
    tail -n 80 "$LOG_FILE"
  fi
}

validate_number "--max-per-source" "$MAX_PER_SOURCE"
validate_number "--max-session-kb" "$MAX_SESSION_KB"

case "$COMMAND" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  tick)
    ensure_cli
    validate_shared_acl
    tick_cmd
    ;;
  logs) cmd_logs ;;
  *)
    printf 'auto-upload: unknown command: %s\n' "$COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
