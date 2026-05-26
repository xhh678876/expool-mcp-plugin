---
name: "expool-pair"
description: "把本机绑定到用户的经验池账号。用户提供 expair_... 一次性配对码或 expk_... 长期 API Key 时启动。一次性配对码更安全（推荐）。"
---

# Expool Pair / Bind —— 绑定本机

把本机和用户的经验池账号关联起来。两种凭据：

- `expair_...` 一次性配对码（**推荐**）：用一次自动换长期 key 后失效，泄露也无害
- `expk_...` 长期 API Key：直接的长期凭据，要小心保管

## 何时启动

- 用户贴出 `expair_...` 或 `expk_...`
- 用户说"绑定 expool"、"装好了去哪绑"、"配对码怎么用"
- 用户跑 status 报 "no credential found / 401" 后跟你说"那帮我绑一下"

## 怎么拿凭据

如果用户还没有凭据，告诉他：

1. 打开经验池门户 `/me` 页面（地址在 plugin README 顶部，或问用户）
2. 启智平台 SSO 登录
3. 点 **"Generate pairing code"** 拿 `expair_...`（推荐）
4. 或点 **"Show API key"** 拿 `expk_...`（长期）
5. 回来贴给你

## 调用方式

| 凭据形式 | MCP 工具 | 参数 |
|---|---|---|
| `expair_XXXXX` | `mcp__expool__expool_pair` | `code` |
| `expk_XXXXX` | `mcp__expool__expool_bind_api` | `api_key` |

绑定时**不要在回复里回显完整凭据**，最多显示前 8 位 + `***`。

## 验证

绑定后立刻跑 `mcp__expool__expool_status`，确认：

- `configured: true`
- `agent_name` 显示你的代理名（比如 `user-xhh666`）
- `gateway` 是预期的 URL

## 错误处理

- 401 → 凭据错或过期；让用户回门户重新生成
- network error → 网关 URL 不通，检查 `~/.config/expool/plugin.json` 里的 `base` 字段
- "code already used" → 一次性配对码已被用过，回门户再生成一个

## 安全提示

绑完提醒用户：

> ⚠️ `expk_...` 是长期凭据，已存到本机 `~/.config/expool/`，永远**不会**上传到服务端。
> 想撤销：去门户 `/me` 删除该 API key 即可。
