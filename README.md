# 🧠 expool-mcp-plugin —— 让你的 AI Agent 有"长期记忆"

> **创智 SII 经验池**的官方插件。一行命令装好，
> Claude Code / Codex 开启自动召回后会在任务前检索你的历史经验，做过的题不用再 debug 第二遍。

## 🔗 经验池门户入口

🏢 **创智 SII 经验池主页**：<https://nat2-notebook-inspire.sii.edu.cn/ws-0349f1f3-e433-45b7-a935-1dd1bfaf8f6b/project-969649d6-31b8-45af-b6ff-ffb85bbfb3c9/user-ef4936dd-0231-4485-ba30-34e92bf3ea53/vscode/6bf937f8-4826-43cd-b0f6-54f30c688f96/a5119654-19ab-4e0d-9527-bb73a246b9a8/proxy/3002>

- 首页：经验池总览
- `/me`：拿 API key / 一次性配对码
- `/plugins`：插件安装命令

---

- 🔍 **自动召回** —— 开启后每个非平凡任务先从个人经验池捞相似经验，再让 agent 处理
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
Codex CLI 按官方 custom prompt 入口使用：重启 Codex 后输入
`/prompts:ep search "你的问题"`，或使用完整命令如 `/prompts:expool-status`。

---

## 🎯 命令速查

Claude Code 使用 `/expool:*`。Codex CLI 的官方入口是 `/prompts:*`，安装器会把
prompt 写到 `~/.codex/prompts/`；短别名用 `/prompts:ep <子命令>`。

按你想干什么直接选：

| 想干什么 | 命令 |
|---|---|
| 开工前先读个人池同类经验并出计划 | `/expool:prep 修复 FastAPI HMAC 签名失败` |
| 让 AI 找历史经验 | `/expool:search <你的问题>` |
| 生成可注入上下文的 RAG 召回包 | `/expool:rag-search <你的问题> --scope personal` |
| 查看可用项目池 | `/expool:projects` |
| 把所有本机会话扫描+上传 | `/expool:upload-all` |
| 只上传当前这次对话 | `/expool:upload` |
| 看本机有哪些 runtime 的会话可识别 | `/expool:detect` |
| 看一条经验的完整内容 | `/expool:get <id8>` |
| 列出我自己的全部经验 | `/expool:list` |
| 删掉一条经验 | `/expool:revoke <id8>` |
| 把经验发布到社区池（分享给别人） | `/expool:publish <id8>` |
| 看绑定 / 配额 / 守护进程状态 | `/expool:status` |
| 开启每个任务前自动 RAG 召回 | `/expool:recall-on --targets claude,codex --top-k 5` |
| 开启项目池召回 | `/expool:recall-on --scope project:<slug> --top-k 8` |
| 查看 / 关闭自动召回 | `/expool:recall-status` / `/expool:recall-off` |
| 给刚才召回的经验打奖励反馈 | `/expool:feedback --last --reward 1 --reason helped` |
| 后台自动上传开 / 关 | `/expool:auto-on` / `/expool:auto-off` |
| 开启后立刻前台跑一次并看进度 | `/expool:auto-on --sources claude-code,codex,hermes --run-now --verbose` |
| 看自动上传后台日志 | `/expool:auto-logs` |

Codex 示例：`/prompts:ep status`、`/prompts:ep upload debugging`、
`/prompts:expool-upload-all`、`/prompts:ep rag 修复 FastAPI HMAC 签名失败`。

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

## 🤖 它怎么"自动召回"的？

开启命令：

```bash
/expool:recall-on --targets claude,codex --top-k 2
/expool:recall-on --scope project:<slug> --top-k 3
```

Claude Code 侧会启用 `UserPromptSubmit` hook，**每条非平凡消息发送前**
优先调用平台侧 `/v1/rag/context`。服务端会把长 session 切成可检索的
`context -> action -> outcome` 子经验 chunk，生成干净 `keyphrases`，再做
FTS / 向量 / 质量分混合排序、ACL 过滤、同经验去重，最后返回一段可直接注入上下文的
RAG context pack。Codex 侧没有同级 hook，所以命令会把一段 managed contract 写入
`~/.codex/AGENTS.md`，要求 Codex 每个非平凡任务先跑同款 RAG 召回，再开始处理。

自动召回默认只走 `/v1/rag/context --json`，再在本地做二次压缩和分数过滤。
低于阈值的结果不会注入。旧 gateway 如需临时回退到经验卡 `/v1/lite/search`，
显式设置 `EXPOOL_AUTO_SEARCH_CARD_FALLBACK=1`；默认不开，避免把长而低相关的
经验卡整包塞进上下文。

每次 RAG 召回都会生成 `event_id`，自动 hook 真正注入上下文后会把最近一次事件写到
`~/.config/expool/runtime/last-recall.json`。任务结束后可以反馈这次召回是否有用：

```bash
/expool:feedback --last --reward 1 --confidence 0.35 --reason helped
/expool:feedback --last --reward -1 --reason misleading
```

反馈会以小步长更新被召回经验的 5 维 Q 值，增加 `reuse_count`，并写入
`q_updates` 审计记录。正反馈会提升未来排序，负反馈会压低误召回，但不会删除原始
session。同一个 event/chunk 的反馈是首次生效，重试不会重复加 Q；`--not-used`
只记录标注，不更新 Q 或 `reuse_count`。

召回 query 尽量使用短语或实体组合，而不是单关键词。比如 `qzcli spec_id
resource_spec_price`、`mova moe scaling law`、`openveo3 prompt 235` 会比
单独搜 `qzcli` / `mova` / `openveo3` 稳定得多；单关键词通常只适合粗过滤。

项目池不是把经验复制到公共池。项目成员进入门户 `/projects` 创建项目、邀请好友、
授权自己的 personal owner 后，agent 就可以用：

```bash
/expool:rag-search "MOVA 测评怎么做" --scope project:<slug>
/expool:recall-on --scope project:<slug>
```

这样检索的是项目已授权成员的个人库聚合 RAG 池，默认不包含 `high` 敏感度经验。

智能过滤（避免无谓检索 + token 浪费）：

- ⏭️ 长度 < 20 字符的消息
- ⏭️ 以 `/` 开头的 slash 命令
- ⏭️ 单纯的 `yes / 好的 / 谢谢 / 收到` 等回应

调参（环境变量）：

| 变量 | 默认 | 干啥 |
|---|---|---|
| `EXPOOL_AUTO_SEARCH` | `0` | `/expool:recall-on` 会设为 `1` |
| `EXPOOL_AUTO_SEARCH_TOP_K` | `2` | 最多注入几个强命中 chunks |
| `EXPOOL_AUTO_SEARCH_SCOPE` | `personal` | 自动召回范围：`personal`、`community`、`project:<slug>` |
| `EXPOOL_AUTO_SEARCH_MIN_SCORE` | `0.32` | 低于该 RAG score 不注入 |
| `EXPOOL_AUTO_SEARCH_MAX_CHARS` | `900` | 单次自动召回注入的总字数上限 |
| `EXPOOL_AUTO_SEARCH_MAX_ITEM_CHARS` | `260` | 单条命中的字数上限 |
| `EXPOOL_AUTO_SEARCH_CARD_FALLBACK` | `0` | 是否允许 RAG 失败后回退旧 card search |
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
    ├── scripts/auto-recall.sh            ← 开关 Claude/Codex 自动召回
    ├── hooks/hooks.json                  ← 插件随包声明的 hook
    ├── commands/                         ← /expool:* slash 命令
    └── README.md
```

### 手动注册 MCP server

```bash
plugins/expool/scripts/register-mcp.sh --targets claude,codex,openclaw,hermes
```

注册时会把 `servers/` + `vendor/` + `scripts/auto-upload.sh` +
`scripts/auto-search.sh` + `scripts/auto-recall.sh` 拷一份到 agent 自己的目录
（`~/.codex/mcp-servers/expool/` 等），避免注册表指向临时 checkout。
`--force` 覆盖、`--dry-run` 预览、`--direct` 指向当前 plugin 目录。

### 后台自动上传（命令行）

```bash
plugins/expool/scripts/auto-upload.sh start --sources claude-code,codex --interval 120
plugins/expool/scripts/auto-upload.sh start --sources claude-code,codex --run-now --verbose
plugins/expool/scripts/auto-upload.sh status
plugins/expool/scripts/auto-upload.sh tick --dry-run
plugins/expool/scripts/auto-upload.sh tick --verbose
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
