---
description: 查看经验池总览：绑定状态 / 发布配额 / 守护进程 / 全局看板。
argument-hint: ""
allowed-tools: [mcp__expool__expool_status, mcp__expool__exp_quota, mcp__expool__exp_daemon_state, mcp__expool__exp_dashboard]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

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
