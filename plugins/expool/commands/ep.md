---
description: Expool short alias for Codex custom prompts. Use status, search, rag, feedback, projects, recall-on, recall-off, recall-status, upload, list, get, revoke, skills, quota, detect, or upload-all.
argument-hint: "status | search <query> | rag <query> | feedback --last --reward 1 | projects | recall-on | recall-off | recall-status | upload [task] | list | get <id8> | revoke <id8> | skills <query> | quota | detect | upload-all"
allowed-tools: [Bash, mcp__expool__expool_status, mcp__expool__exp_quota, mcp__expool__exp_daemon_state, mcp__expool__exp_dashboard, mcp__expool__exp_rag_context, mcp__expool__exp_reuse_feedback, mcp__expool__exp_search, mcp__expool__exp_push_latest, mcp__expool__exp_list, mcp__expool__exp_get, mcp__expool__exp_revoke, mcp__expool__exp_search_skills, mcp__expool__exp_detect_runtimes, mcp__expool__exp_upload_all]
---

You are handling a short alias for the Experience Pool plugin. Reply in Chinese and do not print raw JSON.

Parse `$ARGUMENTS` as:

- `status` or empty: call `expool_status`, `exp_quota`, `exp_daemon_state`, and `exp_dashboard`; summarize binding status, quota, daemon state, and dashboard.
- `search <query>`: call `exp_rag_context` with `q=<query>`, `top_k=3`, `scope=personal`; summarize compactly and suggest `get <id8>` for the best hit if useful. If `exp_rag_context` is unavailable, fallback to `exp_search`.
- `rag <query>`: run `expool-plugin recall search --q <query>`; summarize the returned platform RAG context pack.
- `feedback <args>`: run `expool-plugin reuse-feedback <args>`; if args are empty, use `--last --reward 1 --reason helped`. Summarize how many items and experiences were updated.
- `projects`: run `expool-plugin projects`; list project slugs and explain that recall can use `--scope project:<slug>`.
- `recall-on [opts]`: run `expool-plugin recall on <opts>`; default target is `claude,codex`, default scope is `personal`.
- `recall-off [opts]`: run `expool-plugin recall off <opts>`.
- `recall-status`: run `expool-plugin recall status`; summarize Claude hook and Codex AGENTS state.
- `upload [task]`: call `exp_push_latest` with `source=auto`, `task=<task or inferred task>`, `sensitivity=medium`, `no_trace=false`, `annotate=false`; report the first 8 chars of the returned experience id.
- `list`: call `exp_list` with `limit=20`; summarize compactly.
- `get <id8>`: call `exp_get`; summarize intent, steps, pitfalls, and outcome.
- `revoke <id8>`: call `exp_revoke`; confirm the revoked id.
- `skills <query>`: call `exp_search_skills` with `top_k=3`; summarize available skills.
- `quota`: call `exp_quota`; summarize publish count and whether community publishing is unlocked.
- `detect`: call `exp_detect_runtimes`; show detected runtimes and counts.
- `upload-all`: call `exp_detect_runtimes` first, then call `exp_upload_all` with `full=false`; summarize uploaded/skipped counts. Use private ACL only.

If the first word is unknown, show the supported forms in one compact line.
