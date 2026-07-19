---
description: 上传指定路径的 trajectory 文件到 private 库。
argument-hint: "<absolute-path> [task-classifier]"
allowed-tools: [mcp__expool__exp_push_file]
---

输出规范见 @../shared/output-spec.md：全中文回复、服务端字段首次出现附一句中文释义、不要直接贴原始 JSON（用紧凑表格或要点列表）。

---

Upload the trajectory file the user supplied.

Parse `$ARGUMENTS`:
- The **first** whitespace-delimited token is the file path. Expand `~` and
  any env vars before passing it through. The path MUST exist; if it does
  not, ask the user to confirm before guessing.
- The **rest** of `$ARGUMENTS` is the task classifier (kebab-case). If
  empty, infer from the file name or contents.

Then call `mcp__expool__exp_push_file` with:

- `file`: the parsed path
- `task`: classifier (default `misc`)
- `sensitivity`: "medium" unless the file obviously contains secrets/PII
- `no_trace`: false

On success, print ONE line:

> 📤 uploaded `<basename>` as `<id8>` (task=`<task>`) — `/expool:revoke <id8>` to revoke
