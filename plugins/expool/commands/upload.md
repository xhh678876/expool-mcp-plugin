---
description: 把当前正在跑的这个 agent session 上传到你的 private 库（runtime/model 自动识别）。
argument-hint: "[task-classifier] 例：debugging / ml-infra / code-review"
allowed-tools: [mcp__expool__exp_push_latest]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

## 工作流

把**本机最新的一条 session** 上传到经验池。runtime（claude-code / codex / ...）
和 model（具体模型 ID）都由 uploader 从本地 trace 元数据自动识别。

调用 `mcp__expool__exp_push_latest`，参数如下：

- `source`：`"auto"`（自动识别 runtime）
- `task`（任务分类，kebab-case）：
  - 若 `$ARGUMENTS` 非空，原样使用（必要时做 kebab-case 转换）
  - 否则从 session 内容里推断一个简短分类，例如：
    `debugging`、`code-review`、`infra-setup`、`data-analysis`、`learning`、
    `api-integration`、`refactor`、`incident-response`
- `sensitivity`（敏感度）：默认 `"medium"`。**仅当**会话内涉及凭据、客户数据、
  安全审计细节、内部基础设施拓扑时，提升为 `"high"`
- `tag`：除非用户已经指定，否则省略
- `no_trace`：`false`（默认）—— 同时上传 trajectory
- `annotate`：`false` —— 不跑 LLM 标注（除非用户明确要求，避免额外开销）

## 渲染要求

等待工具返回后：

- 若 `ok` 为 true：提取 `experience_id` 前 8 位（`<id8>`），以及 `source_model`，
  用**一行**回复用户：

  > 📤 已上传 `<id8>`（任务分类 `<task>`，模型 `<source_model>`） — `/expool:revoke <id8>` 可撤回

  额外字段（若返回里有，补一句中文释义）：
  - `review_status`（`auto_approved` 自动审核通过 / `pending` 待人工审核）
  - `redactions`（脱敏次数，按字段统计；高数值时简要列出哪些字段被处理）

- 若 `ok` 为 false：把 `error` 字段完整告知用户，方便重试。
