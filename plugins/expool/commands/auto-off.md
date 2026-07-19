---
description: 关闭本机 session 的自动上传。
argument-hint: ""
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Disable the local automatic upload scheduler.

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto off $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" stop $ARGUMENTS
fi
```

Render the result compactly. If no scheduler is active, say that auto upload is
already off.
