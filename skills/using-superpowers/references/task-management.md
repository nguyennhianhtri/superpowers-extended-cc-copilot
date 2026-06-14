# Native Task Management on Copilot CLI

Skills in this collection were authored for Claude Code's **native task tools**
(`TaskCreate`, `TaskGet`, `TaskUpdate`, `TaskList`) with dependency tracking and
embedded `json:metadata`. Copilot CLI has no `TaskXxx` tools — instead it ships a
per-session **SQLite database** with two pre-created tables that provide the same
capabilities:

- `todos` — `id, title, description, status, created_at, updated_at`
- `todo_deps` — `todo_id, depends_on` (real dependency edges)

You operate on them with the **`sql`** tool. This file is the canonical mapping.
Whenever a skill says `TaskCreate` / `TaskGet` / `TaskUpdate` / `TaskList`, do the
equivalent `sql` operation below. The behavior the skills demand — dependency
enforcement, no front-running, cross-task metadata, real-time visibility — is
fully preserved.

## Tool mapping

| Claude Code native task | Copilot CLI equivalent |
|-------------------------|------------------------|
| `TaskCreate {subject, description}` | `INSERT INTO todos (id, title, description, status) VALUES (...)` |
| Task dependency (`blockedBy`) | `INSERT INTO todo_deps (todo_id, depends_on) VALUES (...)` |
| `TaskGet <id>` | `SELECT * FROM todos WHERE id = '<id>'` |
| `TaskUpdate <id> status=...` | `UPDATE todos SET status='...' WHERE id='<id>'` |
| `TaskList` | `SELECT id,title,status FROM todos ORDER BY created_at` |
| "next unblocked task" | the **ready query** below |
| `.tasks.json` cross-session resume | the on-disk `.tasks.json` file (write with `create`, read with `view`) is the durable source of truth; the `todos` table is the in-session working copy you hydrate from it — see [Cross-session persistence](#cross-session-persistence) |

### Status values

Use Copilot CLI's status vocabulary: `pending`, `in_progress`, `done`, `blocked`.
Map Claude's terms: `completed` → `done`, `not_started` → `pending`.

## Task IDs

Use descriptive kebab-case IDs that encode plan order, e.g. `task-1-price-validation`,
`gate-1-e2e`. Never `t1`/`t2`. The ID is the handle every other operation and every
dependency edge uses.

## Creating a task (TaskCreate equivalent)

Embed the **full structured metadata inside `description`** — exactly the
`json:metadata` fence the skills describe. This is not a workaround: the `todos`
table has no metadata column, and keeping the fence in `description` means a later
`SELECT` returns everything (Goal / Files / Acceptance Criteria / Verify + the JSON),
which is what `executing-plans`, `subagent-driven-development`, and `checking-gates`
all parse.

```sql
INSERT INTO todos (id, title, description, status) VALUES
('task-1-price-validation',
 'Task 1: Add price validation to optimizer',
 '**Goal:** Validate input prices before optimization runs.

**Files:**
- Modify: `src/optimizer.py:45-60`
- Create: `tests/test_price_validation.py`

**Acceptance Criteria:**
- [ ] Negative prices raise ValueError
- [ ] Empty price list raises ValueError
- [ ] Valid prices pass through unchanged

**Verify:** `pytest tests/test_price_validation.py -v`

```json:metadata
{"files": ["src/optimizer.py", "tests/test_price_validation.py"],
 "verifyCommand": "pytest tests/test_price_validation.py -v",
 "acceptanceCriteria": ["Negative prices raise ValueError",
   "Empty price list raises ValueError",
   "Valid prices pass through unchanged"]}
```',
 'pending');
```

The `json:metadata` schema is unchanged — see
`skills/shared/task-format-reference.md` for every key (`files`, `verifyCommand`,
`acceptanceCriteria`, `userGate`, `tags`, `requiresUserSpecification`, `gateScope`,
`failurePolicy`, `subagentBrief`, `model`, `modelTier`, …). All of it lives in the
description text; you read it back with a `SELECT`.

## Declaring dependencies (no front-running)

This is the headline discipline: **a task must not start until its dependencies are
`done`.** Record edges in `todo_deps`:

```sql
INSERT INTO todo_deps (todo_id, depends_on) VALUES
('task-2-wire-api', 'task-1-price-validation');  -- task 2 waits for task 1
```

### Ready query — the next task you are ALLOWED to start

Run this before picking up any task. It returns only `pending` tasks whose every
dependency is already `done`. If a task isn't in this list, it is blocked — do not
start it. The `LEFT JOIN` is deliberate: a dependency edge that points at a missing
or misspelled task id resolves to `NULL` and is treated as **not done**, so a corrupt
edge blocks the task rather than silently letting it through.

```sql
SELECT t.* FROM todos t
WHERE t.status = 'pending'
AND NOT EXISTS (
  SELECT 1 FROM todo_deps td
  LEFT JOIN todos dep ON td.depends_on = dep.id
  WHERE td.todo_id = t.id
    AND (dep.id IS NULL OR dep.status != 'done')
)
ORDER BY t.created_at;
```

## The execution loop

1. **Before starting:** mark `in_progress`
   `UPDATE todos SET status='in_progress' WHERE id='task-1-price-validation';`
2. **Read full context when dispatching/verifying:**
   `SELECT title, description FROM todos WHERE id='task-1-price-validation';`
   Parse the `json:metadata` fence out of `description`.
3. **On completion:** mark `done`
   `UPDATE todos SET status='done' WHERE id='task-1-price-validation';`
4. **If blocked mid-flight:** mark `blocked` and record why in the description.
5. **Re-run the ready query** to find the next allowed task.

## Real-time visibility

Pair every status change with a `report_intent` call so the user sees progress, and
periodically surface the board:

```sql
SELECT id, title, status FROM todos ORDER BY created_at;
```

This reproduces Claude Code's TaskList panel: pending / in_progress / done / blocked,
with what's next and what's gated.

## Cross-session persistence

The `sql` `todos`/`todo_deps` tables are **per-session** — they're empty in a new
session. The durable, cross-session source of truth is the on-disk **`.tasks.json`**
file that `writing-plans` writes next to the plan document (e.g.
`docs/superpowers/plans/2026-01-15-feature.md.tasks.json`). Treat them as two layers:

- **On disk (`.tasks.json`)** — survives across sessions. Write/update it with the
  `create`/`edit` tools; read it with `view`. It holds the full task list, statuses,
  `blockedBy` edges, and the `json:metadata` per task. This is what a fresh session
  resumes from.
- **In session (`todos` + `todo_deps`)** — the working copy used for the ready query,
  dependency enforcement, and live visibility.

**Resuming in a new session:** `view` the `.tasks.json`, then hydrate the tables —
`INSERT` each task into `todos` (mapping its status; `completed`→`done`) and each
`blockedBy` entry into `todo_deps`. **On every status change, update BOTH** the
`todos` row and the `.tasks.json` file so the on-disk copy stays authoritative for the
next session.

## User-gate metadata

`userGate: true` and `tags: ["user-gate"]` go in the `json:metadata` fence in
`description`, identical to upstream. Because Copilot CLI hooks do not fire at
runtime yet (see README → Feature parity), the gate is enforced by **discipline**:
the `checking-gates` skill must run before any task carrying that flag is marked
`done`. To make detection reliable, **always serialize the flag exactly as**
`"userGate": true` (one space after the colon — the canonical form everywhere in this
port). Detect open gates with:

```sql
SELECT id, title FROM todos
WHERE status != 'done' AND description LIKE '%"userGate": true%';
```

If you ever serialize metadata differently, also check `LIKE '%userGate%'` and parse
the fence to confirm.
