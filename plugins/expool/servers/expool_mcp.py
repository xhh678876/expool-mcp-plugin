#!/usr/bin/env python3
"""
expool MCP server — stdio bridge between Claude Code (or any MCP host) and the
vendored exp_uploader.py shipped alongside this plugin.

Design notes (v0.2):
- The plugin is fully self-contained. It vendors `exp_uploader.py` under
  `${CLAUDE_PLUGIN_ROOT}/vendor/` and invokes it as a Python subprocess. No
  dependency on a pre-existing `~/.experience-pool/` install.
- Credentials live at ~/.config/expool/<agent>.json — written by the
  /expool:bind slash command, read by the vendored script via EXP_CRED_DIR.
  The legacy ~/.experience-pool/credentials/ fallback is intentionally
  removed: callers must run /expool:bind once to register their API key.
- Auto-upload is opt-in and managed by scripts/auto-upload.sh. The MCP server
  exposes upload/status tools; the scheduler is controlled by CLI/slash
  commands so users can start and stop it explicitly.
- ACL hardlock: push tools force --acl private. Promotion to community pool
  requires the dedicated exp_publish tool with confirm=True.
"""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional

from mcp.server.fastmcp import FastMCP

# ---------- paths -------------------------------------------------------------

# When invoked through Claude Code, EXPOOL_PLUGIN_ROOT is set by .mcp.json.
# When invoked directly for testing, fall back to the parent of this file.
PLUGIN_ROOT = Path(
    os.environ.get("EXPOOL_PLUGIN_ROOT")
    or Path(__file__).resolve().parent.parent
).resolve()

VENDORED_CLI = PLUGIN_ROOT / "vendor" / "exp_uploader.py"

# Plugin-owned credential directory — completely independent of the legacy
# ~/.experience-pool/credentials/ location.
CRED_DIR = Path(
    os.environ.get("EXPOOL_CRED_DIR")
    or (Path.home() / ".config" / "expool")
).expanduser()
CRED_FILE = CRED_DIR / "credential.json"

# Gateway URL. Agent registry runners set EXPOOL_BASE during install. The
# additional fallbacks let portal-generated shell commands pass one env var
# through every component consistently.
def _gateway_from_ui_public_url() -> str | None:
    ui = (os.environ.get("EXP_UI_PUBLIC_URL") or "").rstrip("/")
    marker = "/proxy/"
    if marker not in ui:
        return None
    prefix = ui.rsplit(marker, 1)[0]
    return f"{prefix}/proxy/3080"


DEFAULT_BASE = "https://expool.clawsii.com"
EXPOOL_BASE = (
    os.environ.get("EXPOOL_BASE")
    or os.environ.get("EXP_BIND_BASE_URL")
    or os.environ.get("EXP_PUBLIC_BASE_URL")
    or _gateway_from_ui_public_url()
    or DEFAULT_BASE
).strip() or DEFAULT_BASE

DEFAULT_TIMEOUT = int(os.environ.get("EXPOOL_MCP_TIMEOUT", "120"))

mcp = FastMCP("expool")


# ---------- credential gate ---------------------------------------------------

def _credential_file_candidate() -> Path:
    """Mirror vendor/exp_uploader.py credential selection.

    Bind writes $EXP_CRED_DIR/<agent>.json, not credential.json. Keep
    credential.json as a compatibility fallback but prefer EXP_AGENT_NAME and
    newest named credentials so status and upload gates match the CLI.
    """
    env_name = os.environ.get("EXP_AGENT_NAME")
    if env_name:
        env_path = CRED_DIR / f"{env_name}.json"
        if env_path.exists():
            return env_path
    if CRED_FILE.exists():
        return CRED_FILE
    try:
        files = sorted(
            CRED_DIR.glob("*.json"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
    except OSError:
        files = []
    return files[0] if files else CRED_DIR / "default.json"


def _credential_status() -> tuple[bool, Optional[str], Optional[str]]:
    """Return (configured, agent_name, error_message)."""
    cred_file = _credential_file_candidate()
    if not cred_file.exists():
        return False, None, (
            f"no API key configured in {CRED_DIR}. "
            "Run /expool:bind to set up your credential."
        )
    try:
        data = json.loads(cred_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        return False, None, f"credential file at {cred_file} is unreadable: {e}"
    if data.get("api_key"):
        return True, str(data.get("agent_name") or "api-key"), None
    if not data.get("agent_name") or not data.get("secret"):
        return False, None, (
            f"credential file at {cred_file} is missing 'api_key' or "
            "'agent_name' + 'secret'. Re-run /expool:bind."
        )
    return True, str(data["agent_name"]), None


def _require_key() -> Optional[dict[str, Any]]:
    """Return None if a key is configured; else an error dict for the caller."""
    ok, _, err = _credential_status()
    if ok:
        return None
    return {
        "ok": False,
        "error": err,
        "remedy": "/expool:bind",
    }


def _subprocess_env() -> dict[str, str]:
    """Build the env passed to every subprocess call: point the vendored CLI
    at our plugin-owned credential dir + state file, decoupled from the
    legacy ~/.experience-pool/ install."""
    env = os.environ.copy()
    env["EXP_CRED_DIR"] = str(CRED_DIR)
    # state.json lives in a plugin-owned dir so /upload-all's daemon-tick
    # doesn't interleave with any standalone exp daemon the user may run.
    plugin_state_root = Path(
        os.environ.get("EXPOOL_STATE_ROOT") or (Path.home() / ".local" / "share" / "expool")
    ).expanduser()
    plugin_state_root.mkdir(parents=True, exist_ok=True)
    env["EXP_STATE_PATH"] = str(plugin_state_root / "state.json")
    return env


# ---------- subprocess helper -------------------------------------------------

def _run(
    args: list[str],
    *,
    timeout: int = DEFAULT_TIMEOUT,
    require_key: bool = True,
) -> dict[str, Any]:
    """Invoke the vendored CLI and return a structured dict."""
    if require_key:
        gate = _require_key()
        if gate is not None:
            return gate

    if not VENDORED_CLI.exists():
        return {
            "ok": False,
            "error": f"vendored exp_uploader.py not found at {VENDORED_CLI}. "
                     "Plugin install may be incomplete.",
        }

    cmd = ["python3", str(VENDORED_CLI), "--base", EXPOOL_BASE, *args]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=_subprocess_env(),
        )
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "error": f"vendored CLI timed out after {timeout}s",
            "cmd": shlex.join(cmd),
        }
    except FileNotFoundError as e:
        return {"ok": False, "error": str(e), "cmd": shlex.join(cmd)}

    out = (proc.stdout or "").strip()
    err_tail = (proc.stderr or "").strip().splitlines()[-20:]
    parsed: Any = out
    if out:
        try:
            parsed = json.loads(out)
        except json.JSONDecodeError:
            parsed = out

    result: dict[str, Any] = {
        "ok": proc.returncode == 0,
        "exit_code": proc.returncode,
        "result": parsed,
    }
    if err_tail:
        result["stderr_tail"] = "\n".join(err_tail)
    if proc.returncode != 0 and "error" not in result:
        result["error"] = f"vendored CLI returned {proc.returncode}"
    return result


def _force_private_acl(acl: Optional[str]) -> str:
    if acl is None or acl == "" or acl == "private":
        return "private"
    raise ValueError(
        f"acl={acl!r} is not allowed via MCP push tools. Push always uploads "
        "as 'private'. Use exp_publish with confirm=True to promote later."
    )


# ---------- bootstrap / status tools (no key required) ------------------------

@mcp.tool()
def expool_status() -> dict[str, Any]:
    """Show plugin status: is the API key configured, where is it stored,
    which gateway are we pointed at, is the vendored CLI present."""
    ok, agent_name, err = _credential_status()
    auth_type = "none"
    cred_file = _credential_file_candidate()
    if ok and cred_file.exists():
        try:
            data = json.loads(cred_file.read_text(encoding="utf-8"))
            auth_type = "api_key" if data.get("api_key") else "hmac"
        except (OSError, json.JSONDecodeError):
            auth_type = "unknown"
    return {
        "ok": True,
        "configured": ok,
        "auth_type": auth_type,
        "agent_name": agent_name,
        "credential_file": str(cred_file),
        "credential_dir": str(CRED_DIR),
        "gateway": EXPOOL_BASE,
        "plugin_root": str(PLUGIN_ROOT),
        "vendored_cli": str(VENDORED_CLI),
        "vendored_cli_present": VENDORED_CLI.exists(),
        "auto_upload_script": str(PLUGIN_ROOT / "scripts" / "auto-upload.sh"),
        "key_error": err,
    }


@mcp.tool()
def expool_bind(
    agent_name: str,
    secret: str,
    agent_id: Optional[str] = None,
    team: Optional[str] = None,
    verify: bool = True,
) -> dict[str, Any]:
    """Install an API key for the user.

    Writes ~/.config/expool/<agent_name>.json with the supplied agent_name +
    secret. By default also runs a post-bind /healthz check against the
    gateway. Pass verify=False if you want to skip the network roundtrip.

    Args:
        agent_name: portal-issued agent name, e.g. "user-alice".
        secret: portal-issued HMAC secret.
        agent_id: optional explicit agent_id (else random UUID is assigned).
        team: optional team slug.
        verify: run /healthz after writing (default True).
    """
    args = [
        "bind",
        "--name", agent_name,
        "--secret", secret,
        "--skip-claude-settings",
    ]
    if agent_id:
        args += ["--agent-id", agent_id]
    if team:
        args += ["--team", team]
    if not verify:
        args += ["--no-verify"]

    # Ensure the credential dir exists before the CLI writes to it.
    CRED_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(CRED_DIR, 0o700)
    except OSError:
        pass

    out = _run(args, require_key=False)
    # The bind subcommand may write multiple files; tighten perms post-hoc.
    cred_path = None
    if isinstance(out.get("result"), dict):
        raw_path = out["result"].get("credential_path")
        if raw_path:
            cred_path = Path(str(raw_path)).expanduser()
    if cred_path and cred_path.exists():
        try:
            os.chmod(cred_path, 0o600)
        except OSError:
            pass
    return out


@mcp.tool()
def expool_bind_api(
    api_key: str,
    agent_name: Optional[str] = None,
    verify: bool = True,
) -> dict[str, Any]:
    """Install a portal-issued Bearer API key for the user.

    This is the plugin-first binding path. The key is stored under
    ~/.config/expool and future requests use Authorization: Bearer.

    Args:
        api_key: portal-issued API key, e.g. "expk_...".
        agent_name: optional local label; server identity is derived from key.
        verify: run /v1/me/quota after writing (default True).
    """
    args = ["bind-api", "--api-key", api_key]
    if agent_name:
        args += ["--agent-name", agent_name]
    if not verify:
        args += ["--no-verify"]

    CRED_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(CRED_DIR, 0o700)
    except OSError:
        pass

    out = _run(args, require_key=False)
    cred_path = None
    if isinstance(out.get("result"), dict):
        raw_path = out["result"].get("credential_path")
        if raw_path:
            cred_path = Path(str(raw_path)).expanduser()
    if cred_path and cred_path.exists():
        try:
            os.chmod(cred_path, 0o600)
        except OSError:
            pass
    return out


@mcp.tool()
def expool_pair(
    code: str,
    agent_name: Optional[str] = None,
    verify: bool = True,
) -> dict[str, Any]:
    """Exchange a portal one-time pairing code for a local API key.

    Args:
        code: short-lived portal pairing code, e.g. "expair_...".
        agent_name: optional local label override.
        verify: run /v1/me/quota after writing (default True).
    """
    args = ["pair", "--code", code]
    if agent_name:
        args += ["--agent-name", agent_name]
    if not verify:
        args += ["--no-verify"]

    CRED_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(CRED_DIR, 0o700)
    except OSError:
        pass

    out = _run(args, require_key=False)
    cred_path = None
    if isinstance(out.get("result"), dict):
        raw_path = out["result"].get("credential_path")
        if raw_path:
            cred_path = Path(str(raw_path)).expanduser()
    if cred_path and cred_path.exists():
        try:
            os.chmod(cred_path, 0o600)
        except OSError:
            pass
    return out


@mcp.tool()
def expool_whoami() -> dict[str, Any]:
    """Show the current credential identity (agent_name / agent_id)."""
    return _run(["whoami"])


# ---------- read tools --------------------------------------------------------

@mcp.tool()
def exp_search(
    q: str,
    top_k: int = 5,
    scope: str = "auto",
    task_type: Optional[str] = None,
) -> dict[str, Any]:
    """Semantic search across the experience pool.

    Args:
        q: free-text query.
        top_k: max results (default 5).
        scope: auto | personal | community.
        task_type: optional filter, e.g. 'debugging'.
    """
    args = ["search", "--q", q, "--top-k", str(top_k), "--scope", scope, "--json"]
    if task_type:
        args += ["--task-type", task_type]
    return _run(args)


@mcp.tool()
def exp_search_skills(q: str, top_k: int = 3) -> dict[str, Any]:
    """Search the distilled skills library."""
    return _run(["skills-search", "--q", q, "--top-k", str(top_k)])


@mcp.tool()
def exp_get(experience_id: str) -> dict[str, Any]:
    """Fetch the full card for one experience by id."""
    return _run(["get", experience_id])


@mcp.tool()
def exp_list(limit: int = 50) -> dict[str, Any]:
    """List the caller's personal pool entries."""
    return _run(["list", "--limit", str(limit)])


@mcp.tool()
def exp_quota() -> dict[str, Any]:
    """Show publish_count and community-pool unlock state."""
    return _run(["quota"])


@mcp.tool()
def exp_dashboard() -> dict[str, Any]:
    """Global pool metrics."""
    return _run(["dashboard"])


@mcp.tool()
def exp_daemon_state() -> dict[str, Any]:
    """Last-seen state per source — useful for /upload-all preview."""
    return _run(["daemon-state"])


@mcp.tool()
def exp_get_rewards(experience_id: str) -> dict[str, Any]:
    """Fetch stored 5-dim rewards for an experience."""
    return _run(["get-rewards", "--experience-id", experience_id])


# ---------- runtime detection / bulk upload -----------------------------------

@mcp.tool()
def exp_detect_runtimes() -> dict[str, Any]:
    """Detect which agent runtimes have local session data on this machine.

    For each known source (claude-code, codex, hermes, cursor, aider,
    continue-dev, open-interpreter, agents-chat, generic), call
    `list-sessions` and report counts. Returns a summary the caller can
    show to the user before /upload-all. This is read-only and intentionally
    works before /expool:bind so users can verify runtime/model detection.
    """
    sources = [
        "claude-code", "codex", "hermes", "cursor", "aider",
        "continue-dev", "open-interpreter", "agents-chat", "generic",
    ]
    detected: dict[str, Any] = {}
    for src in sources:
        r = _run(
            ["list-sessions", "--source", src, "--limit", "5", "--with-model"],
            timeout=30,
            require_key=False,
        )
        result = r.get("result") if isinstance(r.get("result"), dict) else {}
        sessions = result.get("sessions") if isinstance(result, dict) else []
        sessions = sessions if isinstance(sessions, list) else []
        newest = sessions[0] if sessions else {}
        detected[src] = {
            "available": bool(r.get("ok") and sessions),
            "count": len(sessions),
            "newest": newest.get("mtime") or newest.get("ended_at") or newest.get("updated_at"),
            "model": newest.get("model") or "unknown",
            "preview": result or r.get("result"),
            "error": r.get("error"),
        }
    return {"ok": True, "detected": detected}


@mcp.tool()
def exp_upload_all(
    sources: Optional[list[str]] = None,
    full: bool = False,
) -> dict[str, Any]:
    """One-shot bulk upload across detected agent runtimes.

    Args:
        sources: explicit list of sources to sync. If None, the vendored CLI
                 picks up every enabled source via its daemon state.
        full: if True, run `push-all` per source (re-upload everything; server
              dedups by fingerprint). If False (default), run `daemon-tick`
              which is incremental and cheap.

    All uploads are forced to acl=private. To promote any of them, use
    exp_publish with confirm=True afterwards.
    """
    if full:
        if not sources:
            return {
                "ok": False,
                "error": "full=True requires an explicit sources=[...] list "
                         "to avoid blasting every backend.",
            }
        results: dict[str, Any] = {}
        for src in sources:
            results[src] = _run(
                ["push-all", "--source", src, "--yes",
                 "--task", "auto-sync", "--sensitivity", "medium",
                 "--acl", "private"],
                timeout=max(DEFAULT_TIMEOUT, 600),
            )
        return {"ok": True, "mode": "full", "by_source": results}

    return _run(["daemon-tick"], timeout=max(DEFAULT_TIMEOUT, 600))


# ---------- skill install -----------------------------------------------------

@mcp.tool()
def exp_install_skill(name: str, target: str) -> dict[str, Any]:
    """Install a distilled skill into a local directory."""
    return _run(["skills-install", "--name", name, "--target", target])


# ---------- write tools (ACL hardlocked) --------------------------------------

@mcp.tool()
def exp_push_latest(
    source: str = "auto",
    task: str = "misc",
    sensitivity: str = "medium",
    tag: Optional[str] = None,
    no_trace: bool = False,
    annotate: bool = False,
) -> dict[str, Any]:
    """Upload the most recent local session (private)."""
    try:
        acl = _force_private_acl(None)
    except ValueError as e:
        return {"ok": False, "error": str(e)}

    args = [
        "push-latest", "--yes",
        "--source", source,
        "--task", task,
        "--sensitivity", sensitivity,
        "--acl", acl,
    ]
    if tag:
        args += ["--tag", tag]
    if no_trace:
        args += ["--no-trace"]
    if annotate:
        args += ["--annotate"]
    return _run(args, timeout=max(DEFAULT_TIMEOUT, 300))


@mcp.tool()
def exp_push_file(
    file: str,
    task: str = "misc",
    sensitivity: str = "medium",
    tag: Optional[str] = None,
    no_trace: bool = False,
) -> dict[str, Any]:
    """Upload one specific trajectory file (private)."""
    try:
        acl = _force_private_acl(None)
    except ValueError as e:
        return {"ok": False, "error": str(e)}

    p = Path(file).expanduser()
    if not p.exists():
        return {"ok": False, "error": f"file not found: {p}"}

    args = [
        "push-file", "--yes",
        "--file", str(p),
        "--task", task,
        "--sensitivity", sensitivity,
        "--acl", acl,
    ]
    if tag:
        args += ["--tag", tag]
    if no_trace:
        args += ["--no-trace"]
    return _run(args, timeout=max(DEFAULT_TIMEOUT, 300))


@mcp.tool()
def exp_revoke(experience_id: str) -> dict[str, Any]:
    """Revoke one of the caller's experiences."""
    return _run(["revoke", experience_id])


@mcp.tool()
def exp_publish(experience_id: str, confirm: bool = False) -> dict[str, Any]:
    """Promote a private experience to the community pool. Requires confirm=True."""
    if not confirm:
        return {
            "ok": False,
            "error": (
                "publish requires confirm=True. This makes the experience "
                "visible to the whole community pool. Ask the user before "
                "retrying."
            ),
        }
    return _run(["publish", "--experience-id", experience_id])


@mcp.tool()
def exp_unpublish(experience_id: str) -> dict[str, Any]:
    """Drop a previously-published experience back to private."""
    return _run(["unpublish", "--experience-id", experience_id])


# ---------- MCP prompts (slash commands) --------------------------------------
#
# Codex 把 slash 命令通过 MCP 协议的 `prompts/list` + `prompts/get` 暴露给用户。
# 把 commands/*.md 文件动态注册为 @mcp.prompt 后，codex 用户在终端打
# `/expool:status` 之类就能直接拿到对应的命令指令。Claude Code 则同时通过
# plugin commands/*.md 直接拿到同一份文件，两路殊途同归。

COMMANDS_DIR = PLUGIN_ROOT / "commands"


def _split_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """从 markdown 中切出 YAML frontmatter（简版解析，仅取 key: value 行）"""
    if not text.startswith("---\n"):
        return {}, text
    parts = text.split("---\n", 2)
    if len(parts) < 3:
        return {}, text
    fm_block, body = parts[1], parts[2]
    fm: dict[str, str] = {}
    for line in fm_block.splitlines():
        if ":" in line and not line.lstrip().startswith("#"):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm, body.lstrip("\n")


def _make_prompt_callable(body_text: str):
    """构造一个**无参数**的 prompt 实现，避免 FastMCP 把闭包变量当作用户参数。"""
    def _prompt_impl() -> str:
        return body_text
    return _prompt_impl


def _register_command_prompts() -> None:
    if not COMMANDS_DIR.exists():
        return
    for md_file in sorted(COMMANDS_DIR.glob("*.md")):
        name = md_file.stem  # e.g. "status", "upload-all"
        try:
            text = md_file.read_text(encoding="utf-8")
        except OSError:
            continue
        fm, body = _split_frontmatter(text)
        description = fm.get("description") or f"/expool:{name}"
        prompt_name = f"expool:{name}"
        impl = _make_prompt_callable(body)
        mcp.prompt(name=prompt_name, description=description)(impl)


_register_command_prompts()


# ---------- entry point -------------------------------------------------------

if __name__ == "__main__":
    try:
        mcp.run()
    except KeyboardInterrupt:
        sys.exit(0)
