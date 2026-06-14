---
description: Execute a saved plan task-by-task with review checkpoints.
---

Use the `skill` tool to invoke the **executing-plans** skill and follow it exactly as presented to you. Track task state with the `sql` tool on the `todos` table; respect `todo_deps` (never start a task whose dependencies aren't `done`).
