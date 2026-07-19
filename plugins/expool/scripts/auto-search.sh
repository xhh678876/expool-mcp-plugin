#!/usr/bin/env bash
# UserPromptSubmit hook：每条用户消息发送时自动从经验池检索 top-N 命中，
# 包成 hookSpecificOutput.additionalContext 注入到模型上下文。
#
# 智能过滤：跳过短消息、slash 命令、单纯的招呼/回应。
# 依赖：本插件自带的 vendor/exp_uploader.py（与 MCP server 共用 ~/.config/expool 凭据）。
# 开启：/expool:recall-on 或 expool-plugin recall on。
# 临时关闭：设 EXPOOL_AUTO_SEARCH=0。
set -u

# 默认关闭；recall-on 会写 EXPOOL_AUTO_SEARCH=1。
if [ "${EXPOOL_AUTO_SEARCH:-0}" != "1" ]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CLI="$PLUGIN_ROOT/vendor/exp_uploader.py"

# 用户可通过环境变量覆盖默认参数
TOP_K="${EXPOOL_AUTO_SEARCH_TOP_K:-3}"
MIN_CHARS="${EXPOOL_AUTO_SEARCH_MIN_CHARS:-20}"
SEARCH_TIMEOUT="${EXPOOL_AUTO_SEARCH_TIMEOUT:-8}"
SCOPE="${EXPOOL_AUTO_SEARCH_SCOPE:-personal}"
MIN_SCORE="${EXPOOL_AUTO_SEARCH_MIN_SCORE:-0.32}"
MAX_CHARS="${EXPOOL_AUTO_SEARCH_MAX_CHARS:-900}"
MAX_ITEM_CHARS="${EXPOOL_AUTO_SEARCH_MAX_ITEM_CHARS:-260}"
CARD_FALLBACK="${EXPOOL_AUTO_SEARCH_CARD_FALLBACK:-0}"

# 凭据目录：与 MCP server 一致，默认 ~/.config/expool（EXPOOL_CRED_DIR 可覆盖）
CRED_DIR="${EXPOOL_CRED_DIR:-$HOME/.config/expool}"
RUNTIME_DIR="${EXPOOL_RUNTIME_DIR:-$CRED_DIR/runtime}"

# Gateway URL：优先用 EXPOOL_BASE 环境变量；否则从凭据文件 plugin.json 里读 .base；
# 都没有就 fallback 到 vendor CLI 自己的默认 (https://expool.clawsii.com)。
BASE_URL="${EXPOOL_BASE:-}"
if [ -z "$BASE_URL" ] && [ -f "$CRED_DIR/plugin.json" ]; then
    BASE_URL=$(python3 -c '
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("base", ""))
except Exception:
    pass
' "$CRED_DIR/plugin.json" 2>/dev/null)
fi

input=$(cat)

# 用 python3 解析 prompt 并做过滤。过滤通过则把清洗后的 prompt 写到 stdout。
prompt=$(MIN_CHARS="$MIN_CHARS" python3 -c '
import json, sys, re, os
try:
    data = json.loads(sys.stdin.read() or "{}")
except Exception:
    sys.exit(0)
p = (data.get("prompt") or "").strip()
if not p:
    sys.exit(0)
# 1) slash 命令（/expool:status、/help 等）
if p.startswith("/"):
    sys.exit(0)
# 2) 字符数（unicode）阈值
min_chars = int(os.environ.get("MIN_CHARS", "20"))
if len(p) < min_chars:
    sys.exit(0)
# 3) 单纯招呼/回应：归一化后整串匹配
trivial = {
    "yes","y","no","n","ok","okay","thanks","thx","thankyou","done",
    "好的","谢谢","多谢","保存","上传","可以","嗯","嗯嗯","收到","明白",
    "了解","没问题","继续","行","好",
}
norm = re.sub(r"[\s\W_]+", "", p, flags=re.UNICODE).lower()
if norm in trivial:
    sys.exit(0)
print(p)
' <<< "$input")

[ -z "$prompt" ] && exit 0

run_with_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
        return
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$seconds" "$@"
        return
    fi
    python3 - "$seconds" "$@" <<'PY'
import subprocess
import sys

try:
    result = subprocess.run(
        sys.argv[2:],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=float(sys.argv[1]),
        check=False,
    )
except subprocess.TimeoutExpired:
    raise SystemExit(124)
sys.stdout.write(result.stdout)
raise SystemExit(result.returncode)
PY
}

# 检索（带超时，401/网络错误等情况静默退出，不打扰用户）
if [ ! -f "$CLI" ]; then
    exit 0
fi

CMD=(python3 "$CLI")
if [ -n "$BASE_URL" ]; then
    CMD+=(--base "$BASE_URL")
fi
CMD+=(rag-context --q "$prompt" --top-k "$TOP_K" --scope "$SCOPE" --json)

results=$(EXP_CRED_DIR="$CRED_DIR" run_with_timeout "$SEARCH_TIMEOUT" "${CMD[@]}" 2>/dev/null || true)
if [ -z "$results" ] && [ "$CARD_FALLBACK" = "1" ]; then
    # Older gateways do not have /v1/rag/context yet. Fall back to the
    # card-level MVP search only when explicitly enabled. It is noisier and
    # can inject long, low-relevance cards into the model context.
    CMD=(python3 "$CLI")
    if [ -n "$BASE_URL" ]; then
        CMD+=(--base "$BASE_URL")
    fi
    CMD+=(search --q "$prompt" --top-k "$TOP_K" --scope "$SCOPE")
    results=$(EXP_CRED_DIR="$CRED_DIR" run_with_timeout "$SEARCH_TIMEOUT" "${CMD[@]}" 2>/dev/null || true)
fi
[ -z "$results" ] && exit 0

compact=$(EXP_MIN_SCORE="$MIN_SCORE" EXP_MAX_CHARS="$MAX_CHARS" EXP_MAX_ITEM_CHARS="$MAX_ITEM_CHARS" EXP_SCOPE="$SCOPE" python3 -c '
import json, os, re, sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

def env_float(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, str(default)))
    except ValueError:
        return default

def env_int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default

def clean_text(text: str) -> str:
    text = " ".join((text or "").split())
    text = re.sub(r"# AGENTS\.md instructions.*?</INSTRUCTIONS>", "", text)
    text = re.sub(r"📥 connected to experience pool.*?(?:opt out\.|`/me` to revoke)", "", text)
    text = re.sub(r"experience-pool agent contract.*?(?:<!-- end experience-pool -->)?", "", text)
    text = text.replace("Not logged in · Please run /login", "")
    text = re.sub(r"\s+", " ", text).strip(" -")
    return text

def is_noise(text: str) -> bool:
    low = text.lower()
    noise = (
        "experience-pool agent contract",
        "# agents.md instructions",
        "auto-upload to your private repo",
        "not logged in",
        "mcp tools",
    )
    return any(item in low for item in noise)

min_score = env_float("EXP_MIN_SCORE", 0.32)
max_chars = env_int("EXP_MAX_CHARS", 900)
max_item = env_int("EXP_MAX_ITEM_CHARS", 260)
scope = os.environ.get("EXP_SCOPE", "personal")
chunks = data.get("chunks") or []
kept = []
seen_exp = set()
header = f"【经验池精准召回 scope={scope}】只注入相关度达标片段；无强命中则不注入。"
footer = "要求：仅在明显相关时复用；若与当前代码或用户要求冲突，以当前任务为准。"
for c in chunks:
    try:
        score = float(c.get("score") or 0.0)
    except Exception:
        score = 0.0
    if score < min_score:
        continue
    text = clean_text(str(c.get("text") or ""))
    if len(text) < 24 or is_noise(text):
        continue
    if len(text) > max_item:
        text = text[: max_item - 1].rstrip() + "…"
    eid = str(c.get("experience_id") or "")[:8]
    if not eid or eid in seen_exp:
        continue
    typ = c.get("chunk_type") or "chunk"
    meta = c.get("meta") if isinstance(c.get("meta"), dict) else {}
    parent = str(c.get("parent_session_id") or meta.get("parent_session_id") or "")
    parent_label = f" parent={parent[:8]}" if parent else ""
    line = f"{len(kept)+1}. exp={eid}{parent_label} score={score:.2f} {typ}: {text}"
    prospective = header + "\n" + "\n".join(kept + [line]) + "\n" + footer
    if len(prospective) > max_chars:
        break
    seen_exp.add(eid)
    kept.append(line)

if not kept:
    sys.exit(0)
out = header + "\n" + "\n".join(kept) + "\n" + footer
print(out)
' <<< "$results")
[ -z "$compact" ] && exit 0

# Record the latest injected recall event locally so a later task-boundary hook
# or manual command can send reward feedback without asking the model to track
# opaque event ids in conversation context.
mkdir -p "$RUNTIME_DIR" 2>/dev/null || true
EXP_RAW_RESULTS="$results" EXP_RUNTIME_DIR="$RUNTIME_DIR" EXP_PROMPT="$prompt" EXP_MIN_SCORE="$MIN_SCORE" EXP_MAX_CHARS="$MAX_CHARS" EXP_MAX_ITEM_CHARS="$MAX_ITEM_CHARS" EXP_SCOPE="$SCOPE" python3 -c '
import json, os, re, time
from pathlib import Path

raw = os.environ.get("EXP_RAW_RESULTS", "")
try:
    data = json.loads(raw)
except Exception:
    raise SystemExit(0)

event_id = data.get("event_id")
if not event_id:
    raise SystemExit(0)

try:
    min_score = float(os.environ.get("EXP_MIN_SCORE", "0.32"))
except ValueError:
    min_score = 0.32
try:
    max_chars = int(os.environ.get("EXP_MAX_CHARS", "900"))
except ValueError:
    max_chars = 900
try:
    max_item = int(os.environ.get("EXP_MAX_ITEM_CHARS", "260"))
except ValueError:
    max_item = 260

def clean_text(text: str) -> str:
    text = " ".join((text or "").split())
    text = re.sub(r"# AGENTS\.md instructions.*?</INSTRUCTIONS>", "", text)
    text = re.sub(r"📥 connected to experience pool.*?(?:opt out\.|`/me` to revoke)", "", text)
    text = re.sub(r"experience-pool agent contract.*?(?:<!-- end experience-pool -->)?", "", text)
    text = text.replace("Not logged in · Please run /login", "")
    text = re.sub(r"\s+", " ", text).strip()
    return text

def is_noise(text: str) -> bool:
    low = text.lower()
    noise = (
        "experience-pool agent contract",
        "# agents.md instructions",
        "auto-upload to your private repo",
        "not logged in",
        "mcp tools",
    )
    return any(item in low for item in noise)

chunks = []
seen_exp = set()
scope = data.get("scope") or os.environ.get("EXP_SCOPE", "personal")
header = f"【经验池精准召回 scope={scope}】只注入相关度达标片段；无强命中则不注入。"
footer = "要求：仅在明显相关时复用；若与当前代码或用户要求冲突，以当前任务为准。"
lines = []
for c in data.get("chunks") or []:
    try:
        score = float(c.get("score") or 0.0)
    except Exception:
        score = 0.0
    if score < min_score:
        continue
    text = clean_text(str(c.get("text") or ""))
    if len(text) < 24 or is_noise(text):
        continue
    if len(text) > max_item:
        text = text[: max_item - 1].rstrip() + "…"
    eid = str(c.get("experience_id") or "")
    if not eid or eid in seen_exp:
        continue
    short_eid = eid[:8]
    typ = c.get("chunk_type") or "chunk"
    meta = c.get("meta") if isinstance(c.get("meta"), dict) else {}
    parent = str(c.get("parent_session_id") or meta.get("parent_session_id") or "")
    parent_label = f" parent={parent[:8]}" if parent else ""
    line = f"{len(lines)+1}. exp={short_eid}{parent_label} score={score:.2f} {typ}: {text}"
    prospective = header + "\n" + "\n".join(lines + [line]) + "\n" + footer
    if len(prospective) > max_chars:
        break
    seen_exp.add(eid)
    lines.append(line)
    chunks.append({
        "experience_id": eid,
        "chunk_id": c.get("chunk_id"),
        "chunk_type": c.get("chunk_type"),
        "score": score,
        "similarity": c.get("similarity"),
        "source": c.get("source"),
        "parent_session_id": parent or None,
        "text_preview": text[:180],
    })

if not chunks:
    raise SystemExit(0)

payload = {
    "event_id": event_id,
    "query": os.environ.get("EXP_PROMPT", ""),
    "scope": scope,
    "created_at": int(time.time()),
    "chunks": chunks,
}
root = Path(os.environ.get("EXP_RUNTIME_DIR", "")).expanduser()
path = root / "last-recall.json"
tmp = root / "last-recall.json.tmp"
tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
tmp.replace(path)
' 2>/dev/null || true

# 注入到上下文
EXP_RESULTS="$compact" python3 -c '
import json, os
results = os.environ.get("EXP_RESULTS", "")
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": results
    }
}, ensure_ascii=False))
'
