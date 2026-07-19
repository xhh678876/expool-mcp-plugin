---
description: 把一条 private 经验发布到社区池（不可逆，需要显式确认）。
argument-hint: "<id-or-8char-prefix>"
allowed-tools: [mcp__expool__exp_publish]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

**Safety-critical command** — `exp_publish` makes the experience visible to
every member of the community pool. Never call it unprompted.

Process:

1. Parse `$ARGUMENTS` as the experience id. If empty, ask the user which one.
2. Show the user a one-line summary of what publishing means and **ask
   for explicit confirmation** ("Are you sure you want to make `<id8>`
   visible to the whole community? yes/no"). Do not skip this step even
   if the user already typed `/expool:publish`.
3. Only on a clear "yes", call `mcp__expool__exp_publish` with
   `experience_id=<id>` and `confirm=true`.
4. On success print:

   > 🌐 published `<id8>` to community pool — `/expool:unpublish <id8>` to drop.

   On rejection by the gateway (e.g. strict-sanitize trip), surface the
   reason and suggest revising before retrying.

If the user is unsure, recommend `/expool:get <id8>` first so they can
read the card before deciding.
