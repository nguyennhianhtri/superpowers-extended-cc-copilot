<!-- BEGIN superpowers-extended-cc-copilot bootstrap -->
## Skills discipline (superpowers-extended-cc-copilot)

Before responding to any message — including clarifying questions — check whether an
installed skill matches the task and invoke it via the `skill` tool. Even a 1% chance
that a skill applies is enough to invoke it. If the invoked skill turns out to be
wrong, you don't have to use it. See the `using-superpowers` skill for the full rule.

Process skills first (`brainstorming`, `systematic-debugging`), implementation skills
second. New feature: brainstorming -> writing-plans -> executing-plans /
subagent-driven-development. Bug: systematic-debugging before any fix. Before "done":
verification-before-completion.

Native tasks: use the `sql` tool on the `todos` + `todo_deps` tables (no TaskCreate
tool exists). Record dependencies in `todo_deps`; never start a task whose
dependencies aren't `done`. See using-superpowers/references/task-management.md.

User gates: before marking any task `done` whose description contains
`"userGate": true`, invoke the `checking-gates` skill. Do not invent a cheaper check.
<!-- END superpowers-extended-cc-copilot bootstrap -->
