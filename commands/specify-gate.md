---
description: "Lock down verification mechanics for a user-gate task whose HOW is ambiguous. Asks a few short questions, writes the answers back into the task's metadata, then returns control to executing-plans."
---

Use the `skill` tool to invoke the **specifying-gates** skill and follow it exactly as presented to you. Ask the questions with `ask_user` (one at a time). Write the captured HOW back into the target task's `json:metadata` fence by `UPDATE`ing that row's `todos.description` via the `sql` tool.

Target task: the task id passed by the user.
