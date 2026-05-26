#!/usr/bin/env bash
# UserPromptSubmit hook：每条用户消息发送时自动从经验池检索 top-N 命中，
# 包成 hookSpecificOutput.additionalContext 注入到模型上下文。
#
# 智能过滤：跳过短消息、slash 命令、单纯的招呼/回应。
# 依赖：本插件自带的 vendor/exp_uploader.py（与 MCP server 共用 ~/.config/expool 凭据）。
# 临时关闭：在 settings.json 中删 UserPromptSubmit hook，或设 EXPOOL_AUTO_SEARCH=0。
set -u

# 一键关闭开关
if [ "${EXPOOL_AUTO_SEARCH:-1}" = "0" ]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CLI="$PLUGIN_ROOT/vendor/exp_uploader.py"

# 用户可通过环境变量覆盖默认参数
TOP_K="${EXPOOL_AUTO_SEARCH_TOP_K:-3}"
MIN_CHARS="${EXPOOL_AUTO_SEARCH_MIN_CHARS:-20}"
SEARCH_TIMEOUT="${EXPOOL_AUTO_SEARCH_TIMEOUT:-8}"

# 凭据目录：与 MCP server 一致，默认 ~/.config/expool（EXPOOL_CRED_DIR 可覆盖）
CRED_DIR="${EXPOOL_CRED_DIR:-$HOME/.config/expool}"

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

# 检索（带超时，401/网络错误等情况静默退出，不打扰用户）
if [ ! -f "$CLI" ]; then
    exit 0
fi

CMD=(python3 "$CLI")
if [ -n "$BASE_URL" ]; then
    CMD+=(--base "$BASE_URL")
fi
CMD+=(search --q "$prompt" --top-k "$TOP_K")

results=$(EXP_CRED_DIR="$CRED_DIR" timeout "$SEARCH_TIMEOUT" "${CMD[@]}" 2>/dev/null)
[ -z "$results" ] && exit 0

# 注入到上下文
EXP_RESULTS="$results" EXP_TOPK="$TOP_K" python3 -c '
import json, os
results = os.environ.get("EXP_RESULTS", "")
topk = os.environ.get("EXP_TOPK", "3")
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": (
            f"【经验池自动检索 top-{topk}】\n"
            + results
            + "\n\n（以上是历史经验，仅供参考；若与当前任务无关请忽略。"
            + "临时关闭：设环境变量 EXPOOL_AUTO_SEARCH=0；"
            + "永久关闭：在 settings.json 中删除 UserPromptSubmit hook。）"
        )
    }
}, ensure_ascii=False))
'
