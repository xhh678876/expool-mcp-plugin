---
description: 搜索蒸馏后的 skill 库，可选直接安装一个到本地。
argument-hint: "\"<query>\" [--install <name> --target <dir>]"
allowed-tools: [mcp__expool__exp_search_skills, mcp__expool__exp_install_skill]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Two modes, depending on `$ARGUMENTS`:

**Mode A — search** (default).
If `$ARGUMENTS` is plain text or quoted, call `mcp__expool__exp_search_skills`
with `q=<that text>` and `top_k=3`. Render each hit as:

```
[<name>]  <one-line description>  q=<quality>
```

End with a hint: `/expool:skills "<query>" --install <name> --target <dir>` to
extract one locally.

**Mode B — install.**
If `$ARGUMENTS` contains `--install <name>` and `--target <dir>`, skip
search and call `mcp__expool__exp_install_skill` with those args. On success
print:

> 📦 installed skill `<name>` → `<target>`

On failure, surface the error.
