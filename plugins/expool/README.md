# expool

Experience-pool integration for Claude Code and other local agents. It ships
slash commands plus a stdio MCP server that lets the model search past
trajectories and upload new ones to your private pool.

## Slash commands

Claude Code uses the `/expool:*` commands below. For Codex CLI, the installer
also writes official custom prompts into `~/.codex/prompts/`; after restarting
Codex, use `/prompts:expool-status` for full command names or
`/prompts:ep status` for the short dispatcher.

| Command | What it does |
|---|---|
| `/expool:prep 修复 FastAPI HMAC 签名失败` | Before starting work, search your personal pool and draft a plan. Quotes are optional. |
| `/expool:upload [task]` | Upload the current Claude Code session (private). |
| `/expool:upload-file <path> [task]` | Upload one specific trajectory file. |
| `/expool:search <q>` | Browse matching experience cards (auto / personal / community). Quotes are optional for plain text. |
| `/expool:rag-search <q>` | Build a platform-side RAG context pack for recall injection. Supports `--scope project:<slug>`. |
| `/expool:feedback --last --reward 1` | Mark the latest recalled context helpful/harmful and update experience Q values. |
| `/expool:projects` | List project pools available to this credential. |
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
| `/expool:recall-on [opts]` | Enable automatic RAG recall before tasks. |
| `/expool:recall-off [opts]` | Disable automatic recall. |
| `/expool:recall-status` | Show Claude Code hook + Codex AGENTS recall state. |
| `/expool:recall-search <q>` | Run one manual RAG recall pass for debugging. |
| `/expool:auto-on [opts]` | Enable automatic upload scheduling. Add `--run-now --verbose` to watch one foreground pass. |
| `/expool:auto-off` | Disable automatic upload scheduling. |
| `/expool:auto-status` | Show scheduler + daemon state. |
| `/expool:auto-tick [--dry-run --verbose]` | Run one incremental auto-upload tick now. `--verbose` prints progress. |
| `/expool:auto-logs` | Show recent background auto-upload logs. |

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
- Default install mode copies `servers/`, `vendor/`, `scripts/auto-upload.sh`,
  `scripts/auto-search.sh`, and `scripts/auto-recall.sh` into
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

## Automatic recall

Automatic recall is the "learn before doing" path:

```bash
./scripts/auto-recall.sh on --targets claude,codex --scope personal --top-k 2
./scripts/auto-recall.sh on --targets claude,codex --scope project:my-project --top-k 3
./scripts/auto-recall.sh status
./scripts/auto-recall.sh search --q "修复 FastAPI HMAC 签名失败"
./scripts/auto-recall.sh off
```

Claude Code has a real `UserPromptSubmit` hook, so enabling recall patches
`~/.claude/settings.json` and injects a platform-side RAG context pack before
the model sees each non-trivial task. Codex does not expose the same hook
contract in this plugin, so enabling recall writes a managed block into
`~/.codex/AGENTS.md`; Codex then treats RAG recall as a required pre-task step.

The recall path first calls `/v1/rag/context`: the gateway keeps the full
session for inspection, but indexes smaller experience units shaped as
`context -> action -> outcome`. Each unit carries cleaned keywords and
`keyphrases`, so phrase/entity queries such as `qzcli spec_id
resource_spec_price`, `mova moe scaling law`, or `openveo3 prompt 235` can hit
the exact sub-step instead of averaging over an entire long trace. The gateway
then applies ACL, combines vector/FTS/quality signals, caps repeated chunks
from the same experience, and returns compact context text. Automatic recall
then filters low-score chunks, strips runtime boilerplate, truncates each item,
and injects nothing when there is no strong match. Card-level `/v1/lite/search`
fallback is disabled by default because it is noisy; set
`EXPOOL_AUTO_SEARCH_CARD_FALLBACK=1` only during gateway rollouts.

Every RAG context response includes an `event_id`. When automatic recall injects
context, the hook stores that event plus the injected chunk ids in
`~/.config/expool/runtime/last-recall.json`. Agents or users can then send
feedback:

```bash
expool-plugin reuse-feedback --last --reward 1 --confidence 0.35 --reason helped
expool-plugin reuse-feedback --event-id <event> --chunk-id <chunk> --reward -1
```

Feedback is confidence-weighted and conservative: it updates the recalled
experience's five Q dimensions with a small EMA step, increments `reuse_count`,
and writes a `q_updates` audit row. Positive feedback raises future ranking;
negative feedback suppresses misleading recalls without deleting the original
session. Feedback is first-write-wins per event/chunk so retries are idempotent;
`--not-used` records the annotation but does not update Q or `reuse_count`.

Single-keyword recall is intentionally treated as broad recall. Terms like
`mova`, `openveo3`, or `api` can match hundreds of chunks; use phrase/entity
queries for precise recall, or let the automatic hook send the user's full task
message.

The default scope is `personal`, not `auto`, to avoid mixing community results
into the agent's implicit learning path. Project recall uses
`--scope project:<slug>` and searches the project members' granted personal
owners without publishing those experiences to the community pool. Manual
`/expool:search` can still use `--scope auto` or `--scope community`.

## Automatic upload

Automatic upload is explicit opt-in. The plugin exposes slash commands, but the
real control plane is a normal shell script so users can operate it outside an
agent session:

```bash
./scripts/auto-upload.sh start --sources claude-code,codex --interval 120
./scripts/auto-upload.sh start --sources claude-code,codex --run-now --verbose
./scripts/auto-upload.sh status
./scripts/auto-upload.sh tick --dry-run
./scripts/auto-upload.sh tick --verbose
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

`auto-on` starts a background scheduler, so the command itself does not keep a
live progress bar open. To watch one pass immediately, run
`/expool:auto-on --run-now --verbose` while enabling, or
`/expool:auto-tick --verbose` after it is already enabled. Background progress
is written to `expool-plugin auto logs`.

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

1. Bump `version` in `package.json`, `.claude-plugin/plugin.json`,
   `.codex-plugin/plugin.json`, and `vendor/exp_uploader.py`.
2. `git tag v0.1.x && git push --tags`.
3. Update the marketplace `sha`/`ref` if the marketplace entry is pinned.
4. Users get the update automatically on the next `claude plugin` cycle.
