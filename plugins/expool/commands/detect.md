---
description: 检测本机有哪些 agent runtime 的 session 数据可被识别。只读，不上传。
argument-hint: ""
allowed-tools: [mcp__expool__exp_detect_runtimes]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

## 工作流

扫描本机有哪些 agent runtime 的 session 数据可被识别。**只读，不上传**。

支持的 runtime：`claude-code` · `codex` · `hermes` · `cursor` · `aider` ·
`continue-dev` · `open-interpreter` · `agents-chat` · `generic`。

调用 `mcp__expool__exp_detect_runtimes`（无参数）。

## 渲染要求

把结果渲染为紧凑表格，**只显示 `available=true` 的 source**：

| source 运行时 | sessions 数 | newest 最新 session 时间 | model 主模型 |
|---|---|---|---|

字段释义：
- `sessions` = 本机可被识别到的 session 文件数
- `newest` = 最新一条 session 的修改时间（YYYY-MM-DD HH:MM）
- `model` = 该 runtime 最近使用的模型 ID；若无法识别则显示 `unknown`

末尾给一条引导：

- 若识别到 ≥1 个 source：
  > 💡 用 `/expool:upload-all` 把所有 runtime 的新 session 一次性批量上传到你的 private 库。
- 若识别到 0 个 source：
  > 还没有可上传的会话——先用任意 agent 跑一段对话，然后再次运行 `/expool:detect`。
