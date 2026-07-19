---
description: 开启自动上传：新 session 结束后自动归档到 private 库。
argument-hint: "[--sources claude-code,codex,hermes] [--interval 120] [--run-now --verbose]"
allowed-tools: [Bash, Read]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Enable the local automatic upload scheduler.

Run the bundled control script:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto on $ARGUMENTS
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" start $ARGUMENTS
fi
```

If `$ARGUMENTS` is empty, use the safe defaults:

```bash
if command -v expool-plugin >/dev/null 2>&1; then
  expool-plugin auto on
else
  bash "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set and expool-plugin not on PATH}/scripts/auto-upload.sh" start
fi
```

Default behavior:

- sources: `claude-code,codex,hermes`
- interval: `120` seconds
- task: `auto-sync`
- acl: `private`
- `auto-on` 只负责开启后台 scheduler。后台定时上传不会在当前 slash 命令里持续显示进度；进度写到日志里。
- 想马上看一次扫描/上传进度，用：

```bash
/expool:auto-on --sources claude-code,codex,hermes --run-now --verbose
```

- 已经开启后，想前台跑一次并看进度，用：

```bash
/expool:auto-tick --sources claude-code,codex,hermes --verbose
```

- 想看后台定时器日志，用 `/expool:auto-logs` 或 `expool-plugin auto logs`。

Do not print secrets. If the command reports that no credential is configured,
tell the user to run `/expool:bind` before enabling auto upload.
