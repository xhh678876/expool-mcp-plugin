---
name: "expool"
description: "经验池总入口。当用户提到 expool、经验池、检索历史经验、上传会话、绑定凭据、配额 / 发布到社区池、自动上传开关等任意 expool 相关需求时使用本技能；它会路由到具体的子技能或直接调用 mcp__expool__* MCP 工具。"
---

# Expool —— 创智 SII 经验池总入口

本技能是 expool 经验池插件在 Codex 中的统一入口。它的作用是：根据用户请求，决定调用哪一组 `mcp__expool__*` MCP 工具，或者把请求路由到下方更具体的子技能（如 `expool-search`、`expool-upload-all` 等）。

## 路由判定

按以下优先级判断用户意图，然后调对应的 MCP 工具：

| 用户意图（关键词） | 调用的 MCP 工具 | 备注 |
|---|---|---|
| "搜一下经验"、"做过没"、"历史怎么解决的" | `mcp__expool__exp_rag_context` | 推荐的 chunk RAG 召回；必填 `q`；可选 `top_k`、`scope=personal/community/project:<slug>/auto` |
| "浏览经验卡片"、"按卡片搜" | `mcp__expool__exp_search` | 兼容旧卡片搜索；需要完整卡片时再 `exp_get` |
| "把当前 session 上传"、"归档这次对话" | `mcp__expool__exp_push_latest` | 默认 `source=auto`、`acl=private` |
| "扫一下本机所有 agent 的会话"、"批量上传" | `mcp__expool__exp_detect_runtimes` + `mcp__expool__exp_upload_all` | 先 detect 预览，再 upload_all |
| "看绑定状态 / 配额 / 守护进程" | `mcp__expool__expool_status` + `mcp__expool__exp_quota` + `mcp__expool__exp_daemon_state` + `mcp__expool__exp_dashboard` | 组合呈现 |
| "用配对码绑定本机" | `mcp__expool__expool_pair` | 参数 `code`（expair_...） |
| "用 API Key 绑定" | `mcp__expool__expool_bind_api` | 参数 `api_key`（expk_...） |
| "列出我的经验" | `mcp__expool__exp_list` | 默认 limit=50 |
| "拉一条经验的完整卡片" | `mcp__expool__exp_get` | 参数 `eid` 完整或前 8 位 |
| "撤回某条经验" | `mcp__expool__exp_revoke` | 参数 `eid` |
| "发布到社区池" | `mcp__expool__exp_publish` | 需用户二次确认（不可逆） |
| "查可用的 skills" | `mcp__expool__exp_search_skills` + `mcp__expool__exp_install_skill` | skill 库蒸馏后的可复用片段 |
| "开 / 关后台自动上传" | 走 `expool-plugin auto on/off` 终端命令 | MCP 不直接控制调度器 |

## 输出规范

回复用户时必须遵守：

1. **全中文**。表头、字段释义、提示都用中文。
2. **服务端字段第一次出现时附中文释义**：
   - `auto_approved` 自动审核通过 · `pending` 待人工审核 · `revoked` 已撤回
   - `skipped` 本轮看过但已存档，**不是失败**
   - `available_now` 本地可见的 session 总数
   - `redactions` 上传前 layer-1 自动脱敏次数
   - `community_unlocked` 是否解锁向社区池发布
   - `acl=private/public/team:<name>` 仅自己 / 全社区 / 指定团队
3. **不要直接贴原始 JSON**；用紧凑表格或要点列表。

## 默认安全边界

- 所有上传默认 `acl=private`，不会自动进社区池。
- `publish` 是不可逆操作，**必须**在用户明确说"发布"之后再执行。
- API key 存在本机 `~/.config/expool/`，不要在回复里回显完整密钥。

## 何时不要触发本技能

- 用户只是闲聊、问候、问当前时间等 —— 不要主动启动 expool。
- 用户请求与本地会话归档 / 检索历史经验完全无关时。
