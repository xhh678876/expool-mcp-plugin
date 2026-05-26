---
description: 查看经验池总览：绑定状态 / 发布配额 / 守护进程 / 全局看板。
argument-hint: ""
allowed-tools: [mcp__expool__expool_status, mcp__expool__exp_quota, mcp__expool__exp_daemon_state, mcp__expool__exp_dashboard]
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

## 工作流

依次调用以下只读工具，组装一份四段式状态总览：

1. `mcp__expool__expool_status` — 取**插件绑定状态**：
   - `configured`：凭据是否已就位
   - `auth_type`：`api_key` 或 `hmac`
   - `agent_name`：本机绑定的代理名
   - `gateway`：连接的 Experience Pool 网关 URL
   - `credential_file`：凭据文件实际位置
   - `vendored_cli_present`：自带的 CLI 是否完整
   - ⚠️ 永远不要回显 `api_key`、`secret` 之类的密钥值

2. `mcp__expool__exp_quota` — 取**发布配额**：
   - `publish_count` / `threshold`：当前已成功发布到社区池的条数 / 解锁阈值
   - `community_unlocked`：是否解锁
   - `last_publish_at`：最近一次发布时间（ISO 8601）

3. `mcp__expool__exp_daemon_state` — 取**自动上传守护进程**：
   - `last_tick_at`：上次扫描时间（null 表示未启动）
   - 对每个 source（claude-code/codex/...）展示 `uploaded_count`、`last_mtime`、`last_tick_uploaded`

4. `mcp__expool__exp_dashboard` — 取**全局经验池看板**：
   - `total_experiences`：池中总条目数
   - `by_review_status`：审核状态分布
   - 列出 `by_task_type` 中条目最多的 **Top 3** task_type

## 渲染要求

- 用 4 个二级标题（## 绑定状态 / ## 发布配额 / ## 守护进程 / ## 全局看板）分段
- 每段用一张紧凑表格或键值对
- 末尾给一句 **小结**：用中文一句话总结当前是否可用（绑定 OK + 守护活跃 + 配额状态）
