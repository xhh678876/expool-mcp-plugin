---
description: 查看自动上传调度器状态与后台守护进程的运行情况。
argument-hint: ""
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Show automatic upload status.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto status $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" status $ARGUMENTS
fi
```

Summarize:

- scheduler backend and whether it is active
- sources and interval
- credential directory and state file path
- daemon-state counters per source

Do not print secrets. Do not paste raw JSON if the daemon-state output is long;
turn it into a compact table.
