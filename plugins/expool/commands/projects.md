---
description: 列出当前账号可用的项目池，用于 project:<slug> 作用域召回。
argument-hint: "[--json]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Run:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin projects $ARGUMENTS
else
  python3 "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/vendor/exp_uploader.py" projects $ARGUMENTS
fi
```

Explain which project slug can be used with:

```bash
expool-plugin recall on --scope project:<slug>
```
