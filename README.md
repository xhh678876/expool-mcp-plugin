# expool-mcp-plugin

Agent plugin package that ships one plugin (`expool`) for the
experience-pool service. The package includes a stdio MCP server and a
registry script for wiring that MCP server into Claude Code, Codex, OpenClaw,
and Hermes-style agent runtimes.

## Install

### Claude Code marketplace

```bash
# 1. add this marketplace once
claude plugin marketplace add <git-url-of-this-repo>

# 2. install the plugin
claude plugin install expool
```

### npm / npx installer

```bash
npx @haohui666/expool-plugin install --agents claude,codex,openclaw,hermes \
  --base <gateway-from-portal-/plugins>  # e.g. https://nat2.../proxy/3080
npx @haohui666/expool-plugin pair expair_...
npx @haohui666/expool-plugin bind expk_...
npx @haohui666/expool-plugin bind-api expk_...
npx @haohui666/expool-plugin bind+api expk_...
npx @haohui666/expool-plugin detect
npx @haohui666/expool-plugin auto on --sources claude-code,codex,hermes
```

Before the npm package is published, use the GitHub source package after the
repository is pushed:

```bash
npx --yes git+https://github.com/xhh666/expool-mcp-plugin.git install \
  --agents claude,codex,openclaw,hermes \
  --base <gateway-from-portal-/plugins>
```

For offline/internal transfer, build a local tarball:

```bash
npm run release:artifact
npm install -g ./dist/chuangzhi-expool-plugin-*.tgz
expool-plugin install --agents claude,codex --base <gateway-from-portal-/plugins>
```

On the Experience Pool intranet portal, `npm run release:artifact` also copies
the tarball to `dist-public/plugins/`, so users can install directly from:

```bash
curl --noproxy '*' -fsSL <gateway-from-portal-/plugins>/plugins/install.sh | bash
```

For machines where shell piping is disabled, run the manual equivalent:

```bash
tmp="${TMPDIR:-/tmp}/expool-plugin.tgz"
curl --noproxy '*' -fsSL <gateway-from-portal-/plugins>/plugins/expool.tgz -o "$tmp"
npm install -g "$tmp"
expool-plugin install --agents claude,codex,openclaw,hermes --base <gateway-from-portal-/plugins> --force
```

That's it. Next `claude` session, you get `/expool:upload`,
`/expool:search`, `/expool:list`, `/expool:auto-on`, and the other slash
commands.

## 命令速查（按使用场景）

| 想干什么 | 用哪个命令 |
|---|---|
| 一次性把所有 agent 的会话扫描并上传到 private 库 | `/expool:upload-all` |
| 只上传当前这个 session | `/expool:upload [task-classifier]` |
| 看本机有哪些 runtime 的会话可被识别（不上传） | `/expool:detect` |
| 检索经验池找历史做法 | `/expool:search "<query>"` |
| 拉一条经验的完整卡片 | `/expool:get <id8>` |
| 列出我自己的全部经验 | `/expool:list` |
| 撤回一条已上传的经验 | `/expool:revoke <id8>` |
| 把一条 private 经验发布到社区池 | `/expool:publish <id8>` |
| 一次性绑定（推荐用配对码） | `/expool:pair expair_...` |
| 查看绑定 / 配额 / 守护进程状态 | `/expool:status` |
| 开启 / 关闭后台自动上传 | `/expool:auto-on` / `/expool:auto-off` |

## UserPromptSubmit 自动检索（v0.2.12+）

插件自带一个 UserPromptSubmit hook（`plugins/expool/hooks/hooks.json` →
`plugins/expool/scripts/auto-search.sh`）。一旦你在 Claude Code 里启用 `expool`
插件，**每条用户消息发送时**都会被这个 hook 拦下来，做一遍智能过滤后调
`exp search` 拉 top-3 历史命中，注入到当轮上下文。

智能过滤（任一条件命中即跳过检索）：

- 长度 < 20 字符（Unicode 字符数）
- 以 `/` 开头的 slash 命令
- 整串归一化后是 `yes / no / ok / thanks / 好的 / 谢谢 / 保存 / 上传 / 收到 / 明白` 等纯招呼

环境变量调参：

| 变量 | 默认值 | 作用 |
|---|---|---|
| `EXPOOL_AUTO_SEARCH` | `1` | 设 `0` 临时关闭整个 hook（不需要改 settings.json） |
| `EXPOOL_AUTO_SEARCH_TOP_K` | `3` | 注入的命中数量 |
| `EXPOOL_AUTO_SEARCH_MIN_CHARS` | `20` | 过滤阈值（字符数） |
| `EXPOOL_AUTO_SEARCH_TIMEOUT` | `8` | 检索的最长等待秒数 |

注入失败（401 / 网络 / 超时）会静默退出，**不会**打断你的对话。
完全禁用：在 `~/.claude/settings.json` 中删除 UserPromptSubmit 段，或加
`"disableAllHooks": true`。

The installer does two things: it registers the bundled MCP server into the
agent registry, and when Claude Code or Codex is installed it also adds this
local marketplace and installs the `expool` plugin so slash commands are
available. Use `--mcp-only` only when you want the registry entry without
plugin slash commands.

Bind with a portal API key:

```text
/expool:pair expair_...
/expool:bind expk_...
/expool:bind-api expk_...
/expool:bind+api expk_...
```

See `plugins/expool/README.md` for the full per-command reference, the
MCP server design, and the ACL safety model.

## Repo layout

```
expool-mcp-plugin/
├── .claude-plugin/marketplace.json       ← marketplace manifest
├── package.json                           ← npm/npx installer package
├── PUBLISHING.md                          ← release and publish runbook
├── bin/expool-plugin.js                   ← npm CLI installer
├── scripts/                               ← release-check and publish helpers
├── plugins/expool/
│   ├── .claude-plugin/plugin.json        ← plugin manifest
│   ├── .codex-plugin/plugin.json         ← Codex plugin metadata
│   ├── .mcp.json                         ← stdio MCP server registration
│   ├── servers/expool_mcp.py             ← the actual MCP server (FastMCP)
│   ├── vendor/exp_uploader.py             ← bundled canonical uploader
│   ├── scripts/register-mcp.sh            ← writes agent MCP registries
│   ├── scripts/auto-upload.sh             ← starts/stops auto upload
│   ├── scripts/auto-search.sh             ← UserPromptSubmit hook (auto top-3 search)
│   ├── hooks/hooks.json                   ← plugin-shipped hook declarations
│   ├── commands/                          ← slash commands
│   └── README.md
└── README.md  ← you are here
```

## Agent registry wiring

Run the registry script from the repo checkout or from an installed plugin:

```bash
plugins/expool/scripts/register-mcp.sh --targets claude,codex,openclaw,hermes
```

It registers the bundled stdio MCP server as `expool`:

- Claude Code uses `claude mcp add`.
- Codex uses `codex mcp add`.
- Before registering, the script copies `servers/`, `vendor/`, and
  `scripts/auto-upload.sh` into a stable agent-owned directory such as
  `~/.codex/mcp-servers/expool/`. This mirrors the ARIS pattern and avoids
  registry entries pointing at a temporary checkout.
- OpenClaw and Hermes use `<runtime> mcp add` when available; otherwise the
  script writes a portable descriptor at `~/.openclaw/mcp/expool.json` or
  `~/.hermes/mcp/expool.json`.

Use `--force` to replace an existing registration, `--dry-run` to preview, and
`--direct` if you explicitly want the registry to point at the current plugin
directory instead of an agent-owned copy.

The npm CLI wraps the same script:

```bash
expool-plugin install --agents claude,codex --force
expool-plugin bind-api expk_...
expool-plugin detect --source auto
expool-plugin doctor
```

The registry entry launches a generated `scripts/expool-mcp-runner.sh` inside
the agent-owned copy. The runner exports `EXPOOL_PLUGIN_ROOT`, `EXPOOL_BASE`,
and `PYTHONUNBUFFERED` before starting the Python MCP server, so the install
does not depend on each agent CLI's environment-variable option syntax.

## Automatic upload control

Auto upload is controlled from the command line as well as slash commands:

```bash
plugins/expool/scripts/auto-upload.sh start --sources claude-code,codex --interval 120
plugins/expool/scripts/auto-upload.sh status
plugins/expool/scripts/auto-upload.sh tick --dry-run
plugins/expool/scripts/auto-upload.sh stop
```

Inside Claude Code, the matching commands are `/expool:auto-on`,
`/expool:auto-off`, `/expool:auto-status`, and `/expool:auto-tick`.

The scheduler uses the vendored `daemon-tick` implementation, so it is
incremental and deduped by local state plus server-side fingerprints. Default
ACL is `private`.

Manual uploads use `source=auto` by default. The uploader selects the runtime
with the newest local session, then parses trace metadata to infer the model,
such as Claude model IDs from Claude Code JSONL or Codex model IDs from
Codex `turn_context` / `session_meta` records.

## How updates work

Claude Code treats marketplaces as **git remotes**. When you `git push` to
this repo, every machine that ran `claude plugin marketplace add <url>`
picks up the change on its next refresh (a few minutes or on next session
start, depending on Claude Code's cache). Users don't need to do anything.

If you tag versions in `.claude-plugin/plugin.json` and pin them in the
marketplace manifest with `ref: v0.1.x`, you can ship updates more
deliberately. Right now the manifest uses `source: "./plugins/expool"`
which always tracks the marketplace HEAD — simpler, fine for the early
phase.

Before publishing, run:

```bash
npm run release:check
EXPOOL_CHECK_GATEWAY=1 EXPOOL_RELEASE_BASE=<intranet-proxy-3080> npm run release:check
npm run gateway:check -- <intranet-proxy-3080>
npm run release:artifact
```

See `PUBLISHING.md` for the GitHub and npm release flow.

## Roadmap

- **v0.1** — stdio MCP server, subprocesses local `exp` CLI.
- **v0.2** (current) — stdio MCP server with bundled `exp_uploader.py` and
  multi-agent registry wiring plus explicit auto-upload start/stop control.
  Since **v0.2.12**: ships a UserPromptSubmit hook that auto-injects top-3
  experience-pool hits before each user prompt; all slash commands now
  enforce Chinese output and explain server-side fields inline.
- **v0.3** — optional hosted HTTP MCP endpoint
  (`https://expool.clawsii.com/mcp`). Auth via Bearer API key. No Python
  subprocess required on the client.
- **v0.4** — Promote to the `anthropics/claude-plugins-official`
  marketplace. Requires moving to OAuth (DCR or CIMD) since `static_bearer`
  is not endorsed for directory entries.

## License

Same as the parent expool service.
