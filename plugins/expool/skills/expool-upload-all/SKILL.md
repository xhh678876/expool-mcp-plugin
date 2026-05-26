---
name: "expool-upload-all"
description: "扫描本机所有 agent runtime（Claude Code / Codex / OpenClaw / Hermes）的会话文件，一次性批量上传到 private 库。当用户说 '上传所有 trace / 同步全部 session / 归档我的对话历史' 时启动。"
---

# Expool Upload-All —— 扫描+批量上传

把本机各 agent runtime 的 session 一把扫了同步到经验池 private 库。强制 `acl=private`，绝不会自动公开。

## 何时启动

- 用户说"扫一下本机所有会话上传"、"同步所有 trace"、"归档历史对话"
- 用户在 expool **首次绑定后**问"现在怎么把已有的对话上传"
- 用户说"上传"且没指定具体 session（默认是全量批量）

## 工作流（两步）

### 第 1 步：预览

调 `mcp__expool__exp_detect_runtimes`（无参数），列出本机可识别到的 runtime。

渲染为紧凑表格（**只显示 `available=true` 的**）：

| source 运行时 | sessions 数 | newest 最新时间 | model 主模型 |
|---|---|---|---|

如果一个 source 都没识别到，停在这一步，提示"暂无可上传的会话——先用任意 agent 跑一段对话再回来"。

### 第 2 步：确认 + 上传

明确询问用户：

> 即将以 **private** 模式上传 **N 个 session，跨 M 个 runtime**。继续吗？（yes / no）

只在用户明确说"yes"后，调用 `mcp__expool__exp_upload_all`：

- `sources`：默认所有检测到的（不传此参数让 daemon 自决）
- `full`：默认 `false`（增量模式，靠指纹去重）

## 汇报

每个 source 一行：

> 📤 `<source>`：上传 `<n>` 条（跳过 `<dup>` 条重复）

字段释义（**第一次出现给中文**）：

- `uploaded` 本轮真正推到服务端的数量
- `skipped` 本轮看过但已存档，**不是失败**！服务端按内容指纹去重
- `failed` 真正失败的数量（> 0 时展开 `error` 字段给用户）
- `available_now` 本地可识别的 session 总数

若任一 source 的 `failed > 0`，把 `error` 内容完整告诉用户。

## 安全边界

- 强制 `acl=private`，**绝不**自动发布到社区
- 想公开某条要走单独的 `mcp__expool__exp_publish` 流程，且需要二次确认
