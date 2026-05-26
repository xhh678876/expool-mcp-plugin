---
description: 扫描本机所有 agent runtime 的新 session 并一键批量上传到 private 库（自动去重）。
argument-hint: "[--sources claude-code,codex,...] [--full] [--yes]"
allowed-tools: [mcp__expool__exp_detect_runtimes, mcp__expool__exp_upload_all]
---

## 输出规范（全 /expool:* 命令统一）

- **回复语言：全中文。** 表头、字段名以外的解释、提示都用中文。
- **字段释义：** 服务端字段第一次出现时附一句中文释义。常见字段速查：
  - `auto_approved` 自动审核通过 · `pending` 待人工审核 · `revoked` 已撤回
  - `skipped` 本轮看过但已存档，不重复推送
  - `available_now` 本地可见的 session 总数
  - `redactions` 上传前 layer-1 自动脱敏的次数（按字段统计）
  - `community_unlocked` 是否解锁向社区池发布
  - `acl=private/public/team:<name>` 仅自己 / 全社区 / 指定团队
- **不要直接贴原始 JSON**；用紧凑表格或要点列表呈现。

---

## 总览

扫描本机所有可识别 runtime 的 session，把新条目一次性批量上传到 **private** 库。
**强制 `acl=private`**。本命令需用户显式调用，没有自动触发。

## 参数解析

按空白分隔解析 `$ARGUMENTS`：

- `--sources <a,b,c>` → 逗号分隔成数组传给 `sources=[...]`，限定只同步这些 runtime。
  可选值：`claude-code`、`codex`、`hermes`、`cursor`、`aider`、`continue-dev`、
  `open-interpreter`、`agents-chat`、`generic`。
- `--full` → `full=true`，重新扫描所有历史 session。服务端按内容指纹去重，
  通常只是多发 HTTP 请求；默认是增量模式（`daemon-tick`）。
- `--yes` → 跳过下方的确认步骤，直接上传。

## 工作流

1. **预览** — 调用 `mcp__expool__exp_detect_runtimes`，按 `/expool:detect` 的格式
   渲染紧凑表格。如果一个 runtime 都没识别到，停在这一步并提示"暂无可上传的会话"。

2. **确认** — 如果 `$ARGUMENTS` 里**没有** `--yes`，明确询问用户：

   > 即将以 **private** 模式上传 **N 个 session，跨 M 个 runtime**。
   > 模式：**增量**（如果传了 `--full` 则改为 **全量**，服务端会按指纹去重）。
   > 继续吗？（yes / no）

   只有用户明确说 "yes" 才继续。

3. **上传** — 调用 `mcp__expool__exp_upload_all`，参数：
   - `sources`：解析出的列表（用户没传 `--sources` 时省略此参数）
   - `full`：根据 `--full` 标志传 true / false

4. **汇报** — 每个 source 一行：

   > 📤 `<source>`：上传成功 `<n>` 条（跳过 `<dup>` 条重复）

   字段补充：
   - `uploaded` = 本轮实际推送到服务端的 session 数
   - `skipped` = 本轮看过但已存档，**无需重复推送**（不是失败！）
   - `failed` = 真正失败的条数（值 > 0 时要把 `error` 字段展开给用户）

   若 `failed > 0`，把每个失败 source 的 `error` 字段展开给用户，便于针对性重试。

## 安全提醒

- 本命令**不会**在 session 结束时自动触发。插件不附带上传 hook，每次都需手动。
- 这里上传的全部为 `private`。如想将某条放到社区池，走流程：
  `/expool:list` → `/expool:get <id>` → `/expool:publish <id>`（发布需二次确认）。
- 想删除已上传条目，从结果里取 `<id8>`，跑 `/expool:revoke <id8>`。
