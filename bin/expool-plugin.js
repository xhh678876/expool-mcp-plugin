#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const pluginRoot = path.join(root, "plugins", "expool");
const registerScript = path.join(pluginRoot, "scripts", "register-mcp.sh");
const autoScript = path.join(pluginRoot, "scripts", "auto-upload.sh");
const uploader = path.join(pluginRoot, "vendor", "exp_uploader.py");
const configFile = path.join(os.homedir(), ".config", "expool", "plugin.json");

function gatewayFromUiPublicUrl() {
  const ui = process.env.EXP_UI_PUBLIC_URL || "";
  const match = ui.replace(/\/$/, "").match(/^(.*)\/proxy\/\d+$/);
  return match ? `${match[1]}/proxy/3080` : "";
}

const defaultBase =
  process.env.EXPOOL_BASE ||
  process.env.EXP_BIND_BASE_URL ||
  process.env.EXP_PUBLIC_BASE_URL ||
  readConfiguredBase() ||
  gatewayFromUiPublicUrl() ||
  "https://expool.clawsii.com";

function usage() {
  console.log(`Usage: expool-plugin <command> [options]

Commands:
  install       Register bundled MCP into agent registries.
  register      Alias for install.
  bind          Bind a portal API key (expk_...) into ~/.config/expool.
  bind-api      Alias for bind.
  bind+api      Alias for bind-api, matching the slash command spelling.
  pair          Exchange a portal pairing code (expair_...) for a local API key.
  auto          Control automatic uploads: on|off|status|tick|logs.
  detect        Show the newest local sessions and detected runtime.
  status        Show local credential identity through the bundled uploader.
  doctor        Check local prerequisites and plugin files.
  path          Print the bundled plugin path.

Install options:
  --agents LIST       Comma-separated agents. Default: claude,codex,openclaw,hermes
  --targets LIST      Alias for --agents.
  --base URL          Experience Pool gateway. Default: ${defaultBase}
  --force             Replace existing MCP registration.
  --direct            Register current package path instead of copying.
  --dry-run           Preview registry changes.
  --mcp-only          Only register MCP; skip Claude/Codex plugin install.

Bind options:
  --api-key KEY       API key from portal /me/api-keys. Can also be positional.
  --agent-name NAME   Optional local label for the credential file.
  --base URL          Experience Pool gateway. Default: ${defaultBase}
  --no-verify         Write credential without checking the gateway.

Examples:
  expool-plugin install                       # 推荐：自动检测 gateway + 装 MCP + 写 slash 命令
  expool-plugin pair expair_...               # 推荐绑定方式（配对码）
  expool-plugin bind-api expk_...             # 备选：长期 API key
  expool-plugin auto on
  expool-plugin doctor

  # 高级用法（指定 gateway 或限定 agents）
  expool-plugin install --agents claude --base https://your-gateway/`);
}

function die(message, code = 1) {
  console.error(`expool-plugin: ${message}`);
  process.exit(code);
}

function exists(file) {
  return fs.existsSync(file);
}

function run(command, args, options = {}) {
  const status = runReturn(command, args, options);
  process.exit(status);
}

function runReturn(command, args, options = {}) {
  const env = { ...process.env, ...(options.env || {}) };
  const proc = spawnSync(command, args, {
    stdio: "inherit",
    env,
    cwd: options.cwd || root,
  });
  if (proc.error) {
    die(`${command} failed: ${proc.error.message}`);
  }
  return proc.status === null ? 1 : proc.status;
}

function capture(command, args) {
  const proc = spawnSync(command, args, { encoding: "utf8" });
  return {
    ok: !proc.error && proc.status === 0,
    status: proc.status,
    stdout: (proc.stdout || "").trim(),
    stderr: (proc.stderr || "").trim(),
    error: proc.error,
  };
}

function splitOption(args, names, fallback = "") {
  for (const name of names) {
    const idx = args.indexOf(name);
    if (idx >= 0) {
      const value = args[idx + 1];
      if (!value || value.startsWith("--")) {
        die(`missing value for ${name}`, 2);
      }
      args.splice(idx, 2);
      return value;
    }
  }
  return fallback;
}

function consumeFlag(args, name) {
  const idx = args.indexOf(name);
  if (idx < 0) return false;
  args.splice(idx, 1);
  return true;
}

function ensureBundledFiles() {
  for (const file of [registerScript, autoScript, uploader]) {
    if (!exists(file)) {
      die(`package is incomplete; missing ${file}`);
    }
  }
}

function readConfiguredBase() {
  try {
    const parsed = JSON.parse(fs.readFileSync(configFile, "utf8"));
    if (typeof parsed.base === "string" && parsed.base.trim()) {
      return parsed.base.trim().replace(/\/$/, "");
    }
  } catch {
    // Config is optional; env vars still win.
  }
  return "";
}

function writePluginConfig(base) {
  if (!base) return;
  fs.mkdirSync(path.dirname(configFile), { recursive: true });
  const payload = {
    base: base.replace(/\/$/, ""),
    packageRoot: root,
    updatedAt: new Date().toISOString(),
  };
  fs.writeFileSync(configFile, `${JSON.stringify(payload, null, 2)}\n`, { mode: 0o600 });
}

function cmdInstall(args) {
  ensureBundledFiles();
  const targets = splitOption(args, ["--agents", "--targets"], "claude,codex,openclaw,hermes");
  const base = splitOption(args, ["--base"], defaultBase);
  const mcpOnly = consumeFlag(args, "--mcp-only") || consumeFlag(args, "--skip-plugin-install");
  const dryRun = consumeFlag(args, "--dry-run");
  const out = ["--targets", targets, "--base", base];
  if (consumeFlag(args, "--force")) out.push("--force");
  if (consumeFlag(args, "--direct")) out.push("--direct");
  if (dryRun) out.push("--dry-run");
  if (args.length > 0) die(`unknown install argument: ${args[0]}`, 2);
  const status = runReturn("bash", [registerScript, ...out]);
  if (status !== 0) process.exit(status);
  if (!dryRun) writePluginConfig(base);
  if (!mcpOnly && !dryRun) {
    // 先把 slash 命令写到 ~/.claude/commands/expool/ —— 即使下面的 plugin
    // marketplace install 因 claude CLI 缺失 / 网络问题 / 已注册冲突等原因失败，
    // 用户仍能在 Claude Code 里直接用 /expool:status、/expool:upload-all 等。
    writeUserLevelClaudeCommands();
    try {
      installAgentPlugins(targets);
    } catch (e) {
      console.error(`[expool] plugin marketplace install skipped: ${e.message}`);
    }
  }
}

function writeUserLevelClaudeCommands() {
  // 即使 `claude` CLI 没装、或 plugin marketplace install 因任何原因没跑成功，
  // 也保证用户在 ~/.claude/commands/expool/ 下能看到一份 slash command 副本，
  // 下次进 Claude Code 直接用 /expool/status、/expool/upload-all 等。
  const srcDir = path.join(pluginRoot, "commands");
  const destDir = path.join(os.homedir(), ".claude", "commands", "expool");
  if (!exists(srcDir)) return;
  let files;
  try {
    files = fs.readdirSync(srcDir).filter((f) => f.endsWith(".md"));
  } catch (e) {
    console.error(`[expool] skipped user-level slash commands: ${e.message}`);
    return;
  }
  if (files.length === 0) return;
  try {
    fs.mkdirSync(destDir, { recursive: true });
    for (const f of files) {
      fs.copyFileSync(path.join(srcDir, f), path.join(destDir, f));
    }
    console.error(
      `[expool] wrote ${files.length} slash commands to ${destDir} (use /expool/status, /expool/list, ...)`,
    );
  } catch (e) {
    console.error(`[expool] failed to write user-level slash commands: ${e.message}`);
  }
}

function splitTargets(value) {
  return value
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

function hasTarget(targets, names) {
  const set = new Set(splitTargets(targets));
  return names.some((name) => set.has(name));
}

function installAgentPlugins(targets) {
  if (hasTarget(targets, ["claude", "claude-code"])) {
    installClaudePlugin();
  }
  if (hasTarget(targets, ["codex"])) {
    installCodexPlugin();
  }
}

function installClaudePlugin() {
  if (!capture("bash", ["-lc", "command -v claude"]).ok) {
    console.error("[expool] claude CLI not found in PATH — skipping plugin marketplace install (user-level /expool:* 命令已写入 ~/.claude/commands/expool/)");
    return;
  }
  console.error("[expool] installing Claude Code plugin marketplace entry");
  let status = runReturn("claude", ["plugin", "marketplace", "add", root, "--scope", "user"]);
  if (status !== 0) {
    console.error(`[expool] claude plugin marketplace add 失败 (exit ${status}) — 跳过，已有 user-level slash 命令兜底`);
    return;
  }
  status = runReturn("claude", ["plugin", "install", "expool@expool-mcp-plugin"]);
  if (status !== 0) {
    console.error(`[expool] claude plugin install 失败 (exit ${status}) — 跳过，已有 user-level slash 命令兜底`);
    return;
  }
  status = runReturn("claude", ["plugin", "update", "expool@expool-mcp-plugin"]);
  if (status !== 0) {
    console.error(`[expool] claude plugin update 失败 (exit ${status}) — 通常无害，已安装的版本不变`);
  }
}

function installCodexPlugin() {
  if (!capture("bash", ["-lc", "command -v codex"]).ok) {
    console.error("[expool] codex CLI not found in PATH — skipping Codex plugin marketplace install");
    return;
  }
  console.error("[expool] installing Codex plugin marketplace entry");
  const marketplace = prepareCodexMarketplace();
  runReturn("codex", ["plugin", "marketplace", "remove", marketplace.name]);
  let status = runReturn("codex", ["plugin", "marketplace", "add", marketplace.root]);
  if (status !== 0) {
    console.error(`[expool] codex plugin marketplace add 失败 (exit ${status}) — 跳过`);
    return;
  }
  status = runReturn("codex", ["plugin", "add", `expool@${marketplace.name}`]);
  if (status !== 0) {
    console.error(`[expool] codex plugin add 失败 (exit ${status}) — 跳过`);
  }
}

function prepareCodexMarketplace() {
  const name = readCodexMarketplaceName();
  const dest = path.join(os.homedir(), ".codex", "plugin-marketplaces", name);
  fs.rmSync(dest, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(root, dest, {
    recursive: true,
    force: true,
    filter: (src) => {
      const rel = path.relative(root, src);
      if (!rel) return true;
      const parts = rel.split(path.sep);
      return !parts.some((part) =>
        part === ".git" ||
        part === "node_modules" ||
        part === "dist" ||
        part === "__pycache__" ||
        part.endsWith(".pyc")
      );
    },
  });
  return { name, root: dest };
}

function readCodexMarketplaceName() {
  const manifest = path.join(root, ".agents", "plugins", "marketplace.json");
  try {
    const parsed = JSON.parse(fs.readFileSync(manifest, "utf8"));
    if (typeof parsed.name === "string" && parsed.name.trim()) {
      return parsed.name.trim();
    }
  } catch {
    // Fall through to the package default.
  }
  return "expool-mcp-plugin";
}

function cmdBind(args) {
  ensureBundledFiles();
  const base = splitOption(args, ["--base"], defaultBase);
  const agentName = splitOption(args, ["--agent-name"], "");
  const apiKey = splitOption(args, ["--api-key"], "") || args.shift() || "";
  const noVerify = consumeFlag(args, "--no-verify");
  if (args.length > 0) die(`unknown bind argument: ${args[0]}`, 2);
  if (!apiKey) die("missing API key. Create one at /me/api-keys, then run: expool-plugin bind expk_...", 2);
  writePluginConfig(base);
  const out = [uploader, "--base", base, "bind-api", "--api-key", apiKey];
  if (agentName) out.push("--agent-name", agentName);
  if (noVerify) out.push("--no-verify");
  run("python3", out, {
    env: {
      EXP_CRED_DIR: process.env.EXPOOL_CRED_DIR || path.join(os.homedir(), ".config", "expool"),
    },
  });
}

function cmdPair(args) {
  ensureBundledFiles();
  const base = splitOption(args, ["--base"], defaultBase);
  const agentName = splitOption(args, ["--agent-name"], "");
  const code = splitOption(args, ["--code"], "") || args.shift() || "";
  const noVerify = consumeFlag(args, "--no-verify");
  if (args.length > 0) die(`unknown pair argument: ${args[0]}`, 2);
  if (!code) die("missing pairing code. Create one at /me/api-keys, then run: expool-plugin pair expair_...", 2);
  writePluginConfig(base);
  const out = [uploader, "--base", base, "pair", "--code", code];
  if (agentName) out.push("--agent-name", agentName);
  if (noVerify) out.push("--no-verify");
  run("python3", out, {
    env: {
      EXP_CRED_DIR: process.env.EXPOOL_CRED_DIR || path.join(os.homedir(), ".config", "expool"),
    },
  });
}

function cmdAuto(args) {
  ensureBundledFiles();
  const sub = args.shift() || "status";
  const base = splitOption(args, ["--base"], defaultBase);
  const mapped = {
    on: "start",
    enable: "start",
    off: "stop",
    disable: "stop",
    status: "status",
    tick: "tick",
    logs: "logs",
  }[sub];
  if (!mapped) die(`unknown auto command: ${sub}`, 2);
  run("bash", [autoScript, mapped, ...args], {
    env: { EXPOOL_BASE: base },
  });
}

function cmdStatus(args) {
  ensureBundledFiles();
  const base = splitOption(args, ["--base"], defaultBase);
  if (args.length > 0) die(`unknown status argument: ${args[0]}`, 2);
  run("python3", [uploader, "--base", base, "whoami"], {
    env: {
      EXP_CRED_DIR: process.env.EXPOOL_CRED_DIR || path.join(os.homedir(), ".config", "expool"),
    },
  });
}

function cmdDetect(args) {
  ensureBundledFiles();
  const limit = splitOption(args, ["--limit"], "5");
  const source = splitOption(args, ["--source"], "auto");
  const base = splitOption(args, ["--base"], defaultBase);
  if (args.length > 0) die(`unknown detect argument: ${args[0]}`, 2);
  run("python3", [uploader, "--base", base, "list-sessions", "--source", source, "--limit", limit, "--with-model"], {
    env: {
      EXP_CRED_DIR: process.env.EXPOOL_CRED_DIR || path.join(os.homedir(), ".config", "expool"),
    },
  });
}

function checkLine(label, ok, detail = "") {
  console.log(`${ok ? "ok " : "err"}  ${label}${detail ? ` - ${detail}` : ""}`);
}

function cmdDoctor() {
  checkLine("package root", exists(root), root);
  checkLine("plugin root", exists(pluginRoot), pluginRoot);
  checkLine("register script", exists(registerScript), registerScript);
  checkLine("auto-upload script", exists(autoScript), autoScript);
  checkLine("uploader", exists(uploader), uploader);

  const python = capture("python3", ["--version"]);
  checkLine("python3", python.ok, python.stdout || python.stderr || "not found");

  const mcp = capture("python3", ["-c", "import mcp; print(getattr(mcp, '__version__', 'installed'))"]);
  checkLine("python mcp package", mcp.ok, mcp.stdout || mcp.stderr || "install with: pip install --user 'mcp>=1.12'");

  for (const bin of ["claude", "codex", "openclaw", "hermes"]) {
    const res = capture("bash", ["-lc", `command -v ${bin}`]);
    checkLine(`${bin} cli`, res.ok, res.stdout || "not on PATH");
  }

  const health = capture("curl", ["--noproxy", "*", "-fsS", "--max-time", "3", `${defaultBase.replace(/\/$/, "")}/healthz`]);
  checkLine("gateway health", health.ok, health.stdout || health.stderr || defaultBase);

  const pair = capture("bash", [
    "-lc",
    `code=$(curl --noproxy '*' -sS -o /tmp/expool-doctor-pair.json -w '%{http_code}' --max-time 5 -X POST '${defaultBase.replace(/'/g, "'\\''").replace(/\/$/, "")}/v1/plugin/pair' -H 'Content-Type: application/json' -d '{"code":"expair_invalid"}' || true); test "$code" = 400`,
  ]);
  checkLine("gateway pairing endpoint", pair.ok, pair.ok ? "invalid pairing code returns 400" : "old gateway or unreachable; /expool:pair will fail");
}

const args = process.argv.slice(2);
const command = args.shift() || "help";

switch (command) {
  case "install":
  case "register":
    cmdInstall(args);
    break;
  case "bind":
  case "bind-api":
  case "bind+api":
    cmdBind(args);
    break;
  case "pair":
    cmdPair(args);
    break;
  case "auto":
    cmdAuto(args);
    break;
  case "detect":
    cmdDetect(args);
    break;
  case "status":
    cmdStatus(args);
    break;
  case "doctor":
    cmdDoctor(args);
    break;
  case "path":
    console.log(pluginRoot);
    break;
  case "help":
  case "--help":
  case "-h":
    usage();
    break;
  default:
    usage();
    die(`unknown command: ${command}`, 2);
}
