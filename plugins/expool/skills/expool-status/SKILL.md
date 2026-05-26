---
name: "expool-status"
description: "查看 expool 经验池的本机绑定状态、社区池发布配额、自动上传守护进程、全局看板。当用户说 '看 expool 状态 / 绑了没 / 配额还剩多少 / 自动上传开了吗' 时启动。"
---

# Expool Status —— 状态总览

四段式状态总览：绑定状态 + 发布配额 + 守护进程 + 全局看板。

## 何时启动

- 用户问"expool 状态"、"我绑了没"、"配额还剩多少"、"自动上传开着吗"
- 用户报错 "no credential found / 401" → 先用 status 排查绑定
- 排查上传 / 检索失败前的第一步

## 工作流（4 个并行只读调用）

依次调以下 4 个 MCP 工具，合并成一份报告：

1. `mcp__expool__expool_status` —— 绑定状态
   - `configured`：是否已绑
   - `auth_type`：`api_key` / `hmac`
   - `agent_name`：本机绑的代理名
   - `gateway`：连接的网关 URL
   - `credential_file`：凭据文件位置
   - `vendored_cli_present`：是否自带 CLI
   - ⚠️ **永远不要**回显 `api_key`、`secret` 值

2. `mcp__expool__exp_quota` —— 发布配额
   - `publish_count` / `threshold`：已发布数 / 解锁阈值
   - `community_unlocked`：是否解锁社区池
   - `last_publish_at`：最近发布时间

3. `mcp__expool__exp_daemon_state` —— 自动上传守护进程
   - `last_tick_at`：上次扫描时间（null 表示未启动）
   - 每个 source 的 `uploaded_count`、`last_mtime`

4. `mcp__expool__exp_dashboard` —— 全局看板
   - `total_experiences`：池中总条目数
   - `by_review_status`：审核状态分布
   - Top 3 `by_task_type`

## 渲染要求

四个二级标题分段（## 绑定状态 / ## 发布配额 / ## 守护进程 / ## 全局看板），每段用紧凑表格。末尾给一句**中文小结**：例如

> ✅ 当前已绑定为 `user-xxx`，配额 3/3 已解锁社区池，守护进程未启动。

## 字段中文释义（首次出现给一句）

- `auto_approved` 自动审核通过 · `pending` 待人工审核 · `revoked` 已撤回
- `community_unlocked` 是否解锁社区池（达到 threshold 后）
- `last_tick_at: null` 守护进程从未跑过（需要 `expool-plugin auto on` 启动）
