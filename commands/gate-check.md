---
description: "Run the 'do I know HOW?' self-check on a user-gate task and either execute its verification with captured evidence, or hand off to specifying-gates when the HOW is ambiguous."
---

Use the `skill` tool to invoke the **checking-gates** skill and follow it exactly as presented to you.

Target task: the task id passed by the user (e.g. `gate-1-e2e`). If none was given, find the open user-gate tasks with:

```sql
SELECT id, title FROM todos WHERE status != 'done' AND description LIKE '%"userGate": true%';
```
