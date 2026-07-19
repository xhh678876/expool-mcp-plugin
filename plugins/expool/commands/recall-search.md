---
description: 手动跑一次自动召回同款 RAG 检索，用来调试 hook 会注入什么上下文。
argument-hint: "<query text> [--top-k 3] [--scope personal|project:<slug>]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Run one platform RAG recall using the same defaults as automatic recall.

If `$ARGUMENTS` contains `--q`, pass it through unchanged. Otherwise treat the
whole `$ARGUMENTS` string as the query text.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  if printf '%s' "$ARGUMENTS" | grep -q -- '--q'; then
    expool-plugin recall search $ARGUMENTS
  else
    expool-plugin recall search --q "$ARGUMENTS"
  fi
else
  if printf '%s' "$ARGUMENTS" | grep -q -- '--q'; then
    bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-recall.sh" search $ARGUMENTS
  else
    bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-recall.sh" search --q "$ARGUMENTS"
  fi
fi
```

Summarize the generated context compactly. If there is a strong context chunk,
state which historical approach should be reused.
