---
description: "Guided setup for superpowers' optional flows on Copilot CLI (model routing, user-gate enforcement, commit strategy). Explains what's discipline-based vs config-file-based and writes any chosen config files in place."
---

# Superpowers Onboarding (Copilot CLI)

Walk the user through the optional flows one at a time. Ask with `ask_user` (one
question at a time), then immediately write the chosen configuration.

## Important platform note — read this to the user first

The upstream Claude Code fork enforces these flows with **hooks** registered in
`.claude/settings.json`. **Copilot CLI does not execute plugin hooks at runtime
yet** (verified empirically — see README → Feature parity). So on Copilot CLI these
flows are enforced by **skill discipline**, not by an automatic hook:

- **User-gate enforcement** — the `checking-gates` / `specifying-gates` skills must
  be invoked before any task carrying `"userGate": true` is marked `done`. There is
  no hook to register; the discipline lives in the skills and in your `AGENTS.md`
  bootstrap.
- **Pre-commit task gate** — there is no commit-blocking hook. Instead, before you
  `git commit`, run the open-task check and refuse if work is unfinished:
  `SELECT id,title,status FROM todos WHERE status NOT IN ('done');`
- **Subagent model routing** — Copilot CLI subagents (`task` tool) take an
  `agent_type` and an optional `model`. The routing config below tells the
  `subagent-driven-development` skill which model tier to request per task.

## Ground rules

- Assume a clean slate. Don't audit existing config — go straight to the questions.
- Each flow is optional. "No" means write nothing and move on.
- NEVER commit anything. Files are written to the working tree only.
- After the last flow, summarize what was written and how to undo it.

## Scope — ask ONCE

Ask: "Where should superpowers configuration live?" with `ask_user`:
- **This project (recommended)** → `docs/superpowers/<file>.json` in this repo.
- **User-level (all projects)** → `~/.copilot/superpowers/<file>.json`.

## Flow 1 — Subagent model routing (optional)

If yes, write `<scope>/model-routing.json` mapping tiers to Copilot models, e.g.:

```json
{
  "tiers": {
    "mechanical": "claude-haiku-4.5",
    "standard": "claude-sonnet-4.5",
    "frontier": "claude-opus-4.5"
  }
}
```

When this file exists, pass the model mapped from a task's `modelTier`
(read from its `json:metadata`) to the `task` tool's `model` parameter **by hand** —
there is no routing hook on Copilot CLI to do it automatically, so treat this as
advisory. Absent file → every subagent inherits the session model.

## Flow 2 — User-gate enforcement (optional)

If yes, there is nothing to register (no runtime hooks). Confirm to the user that the
`checking-gates`/`specifying-gates` discipline is active via the skills and the
`AGENTS.md` bootstrap, and that the `writing-plans` skill will tag user-requested
verification tasks with `"userGate": true`.

## Flow 3 — Commit strategy (optional)

If yes, write `<scope>/workflow.json`:

```json
{ "commitStrategy": "per-plan" }
```

`per-task` (default) → one commit per task. `per-plan` → a single commit at plan end.
The execution skills honor this file on a best-effort basis; there is no enforcing
hook on Copilot CLI, so it is advisory.

## Closing

Summarize: files written and where, flows skipped, and how to undo (delete the JSON
files; remove the bootstrap block from `AGENTS.md`).
