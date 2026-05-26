# 🧠 expool-mcp-plugin —— 让你的 AI Agent 有"长期记忆"

> **创智 SII 经验池**的官方插件。一行命令装好，
> Claude Code / Codex 每次对话前自动检索你的历史经验，做过的题不用再 debug 第二遍。

## 🔗 经验池门户入口

🏢 **创智 SII 经验池主页**：<https://nat2-notebook-inspire.sii.edu.cn/ws-0349f1f3-e433-45b7-a935-1dd1bfaf8f6b/project-969649d6-31b8-45af-b6ff-ffb85bbfb3c9/user-ef4936dd-0231-4485-ba30-34e92bf3ea53/vscode/6bf937f8-4826-43cd-b0f6-54f30c688f96/a5119654-19ab-4e0d-9527-bb73a246b9a8/proxy/3002>

- 首页：经验池总览
- `/me`：拿 API key / 一次性配对码
- `/plugins`：插件安装命令

---

- 🔍 **自动检索** —— 你每发一条消息，插件会从经验池里捞出最相关的 3 条历史经验注入到上下文
- 📤 **一键上传** —— 跑过的 session 自动归档到 private 库；想分享时再 `/expool:publish` 到社区池
- 🛠️ **多 runtime 通吃** —— Claude Code、Codex、OpenClaw、Hermes 一次配置，全平台生效

---

## ⚡ 30 秒上手

**第 1 步：装插件**

```bash
npx @haohui666/expool-plugin install
```

**第 2 步：拿配对码**

打开门户 `/me` 页面（地址见上方表格），启智平台 SSO 登录后点
**"Generate pairing code"**，复制一串 `expair_...`。

**第 3 步：绑定本机**

```bash
npx @haohui666/expool-plugin pair expair_XXXXXXXX
```

✅ 完成。下次进 Claude Code 直接用 `/expool:search "你的问题"` 试试。

---

## 🎯 命令速查

按你想干什么直接选：

| 想干什么 | 命令 |
|---|---|
| 让 AI 找历史经验 | `/expool:search "<你的问题>"` |
| 把所有本机会话扫描+上传 | `/expool:upload-all` |
| 只上传当前这次对话 | `/expool:upload` |
| 看本机有哪些 runtime 的会话可识别 | `/expool:detect` |
| 看一条经验的完整内容 | `/expool:get <id8>` |
| 列出我自己的全部经验 | `/expool:list` |
| 删掉一条经验 | `/expool:revoke <id8>` |
| 把经验发布到社区池（分享给别人） | `/expool:publish <id8>` |
| 看绑定 / 配额 / 守护进程状态 | `/expool:status` |
| 后台自动上传开 / 关 | `/expool:auto-on` / `/expool:auto-off` |

---

## 🧰 其他装法（按需）

<details>
<summary><b>Claude Code 官方 marketplace（不走 npm）</b></summary>

```bash
claude plugin marketplace add https://github.com/xhh678876/expool-mcp-plugin
claude plugin install expool
```
</details>

<details>
<summary><b>SII 内网一键脚本（适合没有 npx 的机器）</b></summary>

```bash
curl --noproxy '*' -fsSL <你的内网 gateway>/plugins/install.sh | bash
```

不让管道？拆成两步：

```bash
tmp="${TMPDIR:-/tmp}/expool-plugin.tgz"
curl --noproxy '*' -fsSL <你的内网 gateway>/plugins/expool.tgz -o "$tmp"
npm install -g "$tmp"
expool-plugin install --agents claude,codex --base <你的内网 gateway> --force
```
</details>

<details>
<summary><b>从 GitHub 源码直接装（不发 npm 时备用）</b></summary>

```bash
npx --yes git+https://github.com/xhh678876/expool-mcp-plugin.git install \
  --agents claude,codex,openclaw,hermes
```
</details>

<details>
<summary><b>离线 / 内部分发：打 tarball</b></summary>

```bash
npm run release:artifact
npm install -g ./dist/*.tgz
expool-plugin install --agents claude,codex
```
</details>

## 🔑 绑定的另一种选择：长期 API Key

不想每次都生成一次性配对码？门户 `/me` 页面点 **"Show API key"** 拿一串
`expk_...`，然后：

```bash
npx @haohui666/expool-plugin bind-api expk_XXXXXXXX
# 或者进了 Claude Code 后：/expool:bind-api expk_XXXXXXXX
```

⚠️ `expk_...` 是长期凭据 —— 不要贴到聊天记录 / 截图 / 公开 issue 里。
搞丢了去门户撤销重发即可。

绑完跑 `/expool:status` 验证：能看到 `configured: ✅`、你的 `agent_name`，就齐活了。

---

## 🤖 它怎么"自动检索"的？（v0.2.12+）

插件自带一个 UserPromptSubmit hook，**每条消息发送前**自动跑 `exp search`
拉 top-3 历史命中注入上下文。

智能过滤（避免无谓检索 + token 浪费）：

- ⏭️ 长度 < 20 字符的消息
- ⏭️ 以 `/` 开头的 slash 命令
- ⏭️ 单纯的 `yes / 好的 / 谢谢 / 收到` 等回应

调参（环境变量）：

| 变量 | 默认 | 干啥 |
|---|---|---|
| `EXPOOL_AUTO_SEARCH` | `1` | 设 `0` 临时关闭 |
| `EXPOOL_AUTO_SEARCH_TOP_K` | `3` | 注入几条 |
| `EXPOOL_AUTO_SEARCH_MIN_CHARS` | `20` | 过滤阈值 |
| `EXPOOL_AUTO_SEARCH_TIMEOUT` | `8` | 最长等待秒数 |

检索失败（401 / 网络 / 超时）静默退出，**不打断对话**。

详细每个命令的参考、MCP server 设计、ACL 安全模型见 `plugins/expool/README.md`。

---

<details>
<summary>📁 <b>仓库结构 / 技术细节 / 发版流程</b>（点开看）</summary>

### 仓库结构

```
expool-mcp-plugin/
├── .claude-plugin/marketplace.json       ← marketplace 清单
├── package.json                          ← npm/npx 安装器
├── PUBLISHING.md                         ← 发版 runbook
├── bin/expool-plugin.js                  ← npm CLI 入口
├── scripts/                              ← release-check / publish helpers
└── plugins/expool/
    ├── .claude-plugin/plugin.json        ← Claude Code 插件清单
    ├── .codex-plugin/plugin.json         ← Codex 插件清单
    ├── .mcp.json                         ← stdio MCP server 注册声明
    ├── servers/expool_mcp.py             ← MCP server 主体（FastMCP）
    ├── vendor/exp_uploader.py            ← 自带的上传 CLI
    ├── scripts/register-mcp.sh           ← 把 MCP server 写进 agent 注册表
    ├── scripts/auto-upload.sh            ← 启停后台自动上传
    ├── scripts/auto-search.sh            ← UserPromptSubmit hook 脚本
    ├── hooks/hooks.json                  ← 插件随包声明的 hook
    ├── commands/                         ← /expool:* slash 命令
    └── README.md
```

### 手动注册 MCP server

```bash
plugins/expool/scripts/register-mcp.sh --targets claude,codex,openclaw,hermes
```

注册时会把 `servers/` + `vendor/` + `scripts/auto-upload.sh` 拷一份到
agent 自己的目录（`~/.codex/mcp-servers/expool/` 等），避免注册表指向临时 checkout。
`--force` 覆盖、`--dry-run` 预览、`--direct` 指向当前 plugin 目录。

### 后台自动上传（命令行）

```bash
plugins/expool/scripts/auto-upload.sh start --sources claude-code,codex --interval 120
plugins/expool/scripts/auto-upload.sh status
plugins/expool/scripts/auto-upload.sh tick --dry-run
plugins/expool/scripts/auto-upload.sh stop
```

Slash 命令版：`/expool:auto-on`、`/expool:auto-off`、`/expool:auto-status`、`/expool:auto-tick`。
底层走 `daemon-tick`，本地 + 服务端双层去重，ACL 默认 `private`。

### 发版流程

```bash
npm run release:check              # 预检（语法 / 清理 / pack dry-run）
npm run release:artifact           # 打 tarball 到 dist/
npm publish --access public        # 发到 npmjs（要带 2FA bypass 的 token）
```

详细见 [`PUBLISHING.md`](./PUBLISHING.md)。Claude Code 把 marketplace 当 git remote 看，
`git push` 之后所有装过这个 marketplace 的机器下次刷新自动拿新版。

### Roadmap

- **v0.1** — stdio MCP server，subprocess 本地 `exp` CLI
- **v0.2**（当前） — 自带 `exp_uploader.py` + 多 runtime 注册 + 后台自动上传控制
  - **v0.2.12+**：随包 UserPromptSubmit hook（每条消息自动注入 top-3 历史经验）；
    所有 slash 命令强制中文输出 + 字段释义
- **v0.3** — 托管 HTTP MCP endpoint，Bearer API Key 鉴权，客户端不再依赖 Python subprocess
- **v0.4** — 提交到 `anthropics/claude-plugins-official` 官方 marketplace
  （需切到 OAuth：DCR 或 CIMD）

</details>

## License

Same as the parent expool service.
