---
description: 搜索蒸馏后的 skill 库，可选直接安装一个到本地。
argument-hint: "\"<query>\" [--install <name> --target <dir>]"
allowed-tools: [mcp__expool__exp_search_skills, mcp__expool__exp_install_skill]
---

## 输出规范（全 /expool:* 命令统一）

- **回复语言：全中文。** 表头、字段名以外的解释、提示都用中文。
- **字段释义：** 服务端字段第一次出现时附一句中文释义。常见字段速查：
  - `auto_approved` 自动审核通过 · `pending` 待人工审核 · `revoked` 已撤回
  - `skipped` 本轮看过但已存档，不重复推送
  - `available_now` 本地可见的 session 总数
  - `redactions` 上传前 layer-1 自动脱敏的次数（按字段统计）
  - `community_unlocked` 是否解锁向社区池发布
  - `acl=private/public/team:<name>` 仅自己 / 全社区 / 指定团队
- **不要直接贴原始 JSON**；用紧凑表格或要点列表呈现。

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
