# expool

Experience-pool integration for Claude Code and other local agents. It ships
slash commands plus a stdio MCP server that lets the model search past
trajectories and upload new ones to your private pool.

## Slash commands

| Command | What it does |
|---|---|
| `/expool:upload [task]` | Upload the current Claude Code session (private). |
| `/expool:upload-file <path> [task]` | Upload one specific trajectory file. |
| `/expool:search "<q>"` | Semantic search the pool (auto / personal / community). |
| `/expool:list [--limit N]` | List your own experiences. |
| `/expool:get <id8>` | Full card for one experience. |
| `/expool:revoke <id8>` | Soft-delete an experience you own. |
| `/expool:publish <id8>` | Promote to community pool (requires confirmation). |
| `/expool:skills "<q>"` | Search / install distilled skills. |
| `/expool:status` | Quota + daemon state + dashboard. |
| `/expool:pair <expair_...>` | Bind via one-time portal pairing code. |
| `/expool:bind <expk_...>` | Bind this plugin with a portal API key. |
| `/expool:bind-api <expk_...>` | Explicit API-key binding alias. |
| `/expool:bind+api <expk_...>` | Same as `/expool:bind-api`, for users who type `bind+api`. |
| `/expool:register-mcp` | Register this MCP server into local agent registries. |
| `/expool:auto-on [opts]` | Enable automatic upload scheduling. |
| `/expool:auto-off` | Disable automatic upload scheduling. |
| `/expool:auto-status` | Show scheduler + daemon state. |
| `/expool:auto-tick [--dry-run]` | Run one incremental auto-upload tick now. |

## How it works

```
Agent runtime  --stdio-->  servers/expool_mcp.py  --subprocess-->  vendor/exp_uploader.py  --HTTP-->  expool gateway
                              (this plugin)                         (bundled)
```

The Python MCP server is bundled inside the plugin at
`servers/expool_mcp.py`. Claude Code auto-launches it via `.mcp.json` when
the plugin is enabled. For Codex, OpenClaw, Hermes, or a non-plugin Claude
install, run:

```bash
./scripts/register-mcp.sh --targets claude,codex,openclaw,hermes
```

The server subprocesses the bundled `vendor/exp_uploader.py` instead of
re-implementing sanitize / HMAC / dedup logic.

When a command uses `source=auto`, the uploader picks the runtime with the
newest local session and then reads model metadata from that trace. That keeps
`/expool:upload` correct on machines where Claude Code, Codex, OpenClaw, and
Hermes have all been used.

## Prerequisites

1. **Python `mcp` SDK** >= 1.12 on PATH:
   ```bash
   pip install --user 'mcp>=1.12'
   ```
2. **A bound credential**. Open the intranet portal account page
   (`https://nat2.../proxy/3002/me`), then prefer
   `/expool:pair <expair_...>` using a one-time pairing code from
   `/me/api-keys`; the plugin exchanges it for an API key and stores that key
   under `~/.config/expool/`. Manual
   `/expool:bind-api <expk_...>` and legacy `agent_name + secret` binding
   still work.

## MCP Registry

The registry script prefers native commands:

- Claude Code: `claude mcp add`
- Codex: `codex mcp add`
- Default install mode copies `servers/`, `vendor/`, and
  `scripts/auto-upload.sh` into
  `~/.<agent>/mcp-servers/expool/`, then registers that stable path.
- OpenClaw / Hermes: tries `<runtime> mcp add`; if unavailable, writes a
  portable descriptor to `~/.openclaw/mcp/expool.json` or
  `~/.hermes/mcp/expool.json`.

Examples:

```bash
./scripts/register-mcp.sh --targets claude,codex --force
EXPOOL_BASE=<gateway-from-portal-/plugins> ./scripts/register-mcp.sh
./scripts/register-mcp.sh --targets portable --dry-run
./scripts/register-mcp.sh --targets codex --direct
```

## Automatic upload

Automatic upload is explicit opt-in. The plugin exposes slash commands, but the
real control plane is a normal shell script so users can operate it outside an
agent session:

```bash
./scripts/auto-upload.sh start --sources claude-code,codex --interval 120
./scripts/auto-upload.sh status
./scripts/auto-upload.sh tick --dry-run
./scripts/auto-upload.sh stop
```

`start` installs a per-user scheduler:

- Linux: `systemd --user` timer when available.
- macOS: `launchd` user agent.
- Fallback: a background loop with a pid file under
  `~/.local/share/expool/`.

Each tick calls the bundled uploader's `daemon-tick`, which tracks state in
`~/.local/share/expool/state.json` via `EXP_STATE_PATH` and uploads only new
sessions. Defaults are conservative: sources `claude-code,codex,hermes`, task
`auto-sync`, ACL `private`, and one pass every 120 seconds.

## ACL safety

The `exp_push_latest` and `exp_push_file` MCP tools **hard-lock** `acl` to
`private`. To make an experience visible to the community, you must call
`exp_publish` with `confirm=True` afterwards. The `/expool:publish`
command always asks the user before doing this.

## Troubleshooting

- **`vendored exp_uploader.py not found`** — the plugin install is incomplete;
  reinstall the plugin package.
- **No results from `/expool:search`** — verify your credential is still
  valid with `/expool:status` or `/expool:bind`.
- **Server hangs on first call** — increase the timeout:
  `export EXPOOL_MCP_TIMEOUT=300`.
- **Auto upload did not start** — run
  `./scripts/auto-upload.sh status` and then
  `./scripts/auto-upload.sh logs`.

## Releasing a new version

This plugin lives in a Claude Code marketplace repo. To ship an update:

1. Bump `version` in `.claude-plugin/plugin.json`.
2. `git tag v0.1.x && git push --tags`.
3. Update the marketplace `sha`/`ref` if the marketplace entry is pinned.
4. Users get the update automatically on the next `claude plugin` cycle.
