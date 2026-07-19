---
description: 给最近一次或指定 RAG 召回事件打奖励反馈，并让服务端更新经验 Q 值。
argument-hint: "--last --reward 1|0|-1 [--reason \"why\"] [--confidence 0.35] 或 --event-id <id> --chunk-id <id> --reward 0.8"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Send feedback for a RAG recall event. Positive reward means the recalled
experience helped; negative reward means it was misleading or harmful.

If `$ARGUMENTS` is empty, use `--last --reward 1 --reason "helped"` as the
default. Otherwise pass `$ARGUMENTS` through unchanged.

Run:

```bash
ARGS="$ARGUMENTS"
if [ -z "$ARGS" ]; then
  ARGS='--last --reward 1 --reason helped'
fi

if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin reuse-feedback $ARGS
else
  python3 "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/vendor/exp_uploader.py" reuse-feedback $ARGS
fi
```

Summarize which event was updated, how many experiences received Q updates,
and whether the reward was positive, neutral, or negative.
