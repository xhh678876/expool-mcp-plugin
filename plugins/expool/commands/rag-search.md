---
description: 使用平台侧 RAG 池检索经验，并返回可直接注入上下文的 context pack。
argument-hint: "\"<query text>\" [--scope personal|community|project:<slug>] [--top-k 8]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Run a platform-side RAG context search. Prefer this over `/expool:search` when
the goal is recall/context injection rather than browsing individual cards.

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

Summarize the generated context pack and point out whether it came from
personal, project, or community scope.
