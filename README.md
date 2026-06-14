# superpowers-extended-cc-copilot

A **GitHub Copilot CLI** port of [`pcvelz/superpowers`](https://github.com/pcvelz/superpowers)
(*Superpowers Extended for Claude Code*), which is itself a Claude Code–specific fork
of [`obra/superpowers`](https://github.com/obra/superpowers).

It brings the full superpowers workflow discipline to Copilot CLI: a library of
skills covering brainstorming, planning, TDD, debugging, code review, and
verification — plus the Extended-CC additions (**native task management with
dependency tracking** and the **user-thrown gate** flow) mapped onto Copilot CLI's
own primitives.

> **TL;DR on parity:** every *skill* ports cleanly and is auto-discovered by Copilot
> CLI. Native task management maps **1:1** onto Copilot CLI's `sql` `todos` +
> `todo_deps` tables (real dependency enforcement — the headline Extended-CC
> feature). The Extended-CC features that were implemented as **Claude Code hooks**
> (pre-commit gate, automatic user-gate re-validation, model-routing enforcement)
> cannot fire automatically because **Copilot CLI does not execute plugin hooks at
> runtime yet** — so they are re-expressed as *skill discipline* + a per-repo
> `AGENTS.md` bootstrap. See [Feature parity](#feature-parity).

## Install

```bash
# From a local clone
copilot plugin install /path/to/superpowers-extended-cc-copilot

# Verify
copilot plugin list
```

Then, in each repo where you want the discipline auto-loaded at session start:

```bash
/path/to/superpowers-extended-cc-copilot/scripts/init-superpowers.sh
```

This writes a small sentinel-delimited block into the repo's `AGENTS.md` (the only
instructions surface Copilot CLI auto-injects today). It's idempotent and preserves
the rest of your `AGENTS.md`.

## Skills

| Skill | Purpose |
|-------|---------|
| `using-superpowers` | Bootstrap discipline: check for a skill before any response. Contains the tool + task-management mappings. |
| `brainstorming` | Pre-implementation design dialogue (hard-gate against premature coding). |
| `writing-plans` | Turn an approved design into dependency-tracked, bite-sized tasks. |
| `executing-plans` | Work a saved plan task-by-task with review checkpoints. |
| `subagent-driven-development` | Dispatch a fresh subagent per task with two-stage review. |
| `test-driven-development` | RED → GREEN → refactor; delete code written before its test. |
| `systematic-debugging` | Root-cause investigation before any fix. |
| `verification-before-completion` | No "done" without running a verification command. |
| `requesting-code-review` | Rigorous review before merging. |
| `receiving-code-review` | Technical rigor when applying feedback. |
| `writing-skills` | Author new skills that plug into this framework. |
| `using-git-worktrees` | Isolate feature work from the current workspace. |
| `dispatching-parallel-agents` | Fan out 2+ truly independent tasks. |
| `finishing-a-development-branch` | Structured merge / PR / cleanup options. |
| `checking-gates` | The "do I know HOW?" self-check for a user-gate task; runs verification and posts evidence. |
| `specifying-gates` | Locks down verification mechanics for an ambiguous user gate. |

Skills are **auto-discovered** by Copilot CLI from each `skills/<name>/SKILL.md`
`description` frontmatter. Describe your task and the matching skill surfaces via the
`skill` tool — no manual registration.

## Commands

The Claude Code slash-commands are ported under `commands/` as thin entry points that
invoke the matching skill (`brainstorm`, `write-plan`, `execute-plan`, `gate-check`,
`specify-gate`, `onboard`). On Copilot CLI you normally just *describe the task* and
the skill surfaces automatically; the command files document the canonical entry
points and the `onboard` flow.

## Native task management on Copilot CLI

The Extended-CC headline is native tasks with **dependency enforcement** (Task 2
blocked until Task 1 completes — no front-running). Claude Code does this with
`TaskCreate`/`TaskGet`/`TaskUpdate`/`TaskList`. Copilot CLI has no such tools, but it
ships a per-session SQLite database with `todos` + `todo_deps` tables that provide the
**same** capabilities through the `sql` tool:

- Dependencies → rows in `todo_deps`; the "ready query" returns only tasks whose
  dependencies are `done`.
- Per-task metadata (`json:metadata`) → embedded in `todos.description` (read back
  with `SELECT`), exactly as upstream embeds it in the task description.
- Real-time visibility → `SELECT id,title,status FROM todos` reproduces the TaskList
  panel; pair with `report_intent`.

Full mapping: [`skills/using-superpowers/references/task-management.md`](skills/using-superpowers/references/task-management.md).
Tool-name mapping: [`skills/using-superpowers/references/copilot-tools.md`](skills/using-superpowers/references/copilot-tools.md).

## Feature parity

| Upstream (Extended-CC) feature | Status on Copilot CLI | How |
|---|---|---|
| 16 workflow skills | ✅ Full | Ported verbatim (behavior-shaping content preserved); auto-discovered via `description`. |
| Skill-first discipline ("check for a skill before responding") | ✅ Full | `using-superpowers` skill + `AGENTS.md` bootstrap (`scripts/init-superpowers.sh`) + `hooks/hooks.json` sessionStart prompt (for when hooks land). |
| Native task management | ✅ Full (re-mapped) | `sql` on `todos`; `TaskGet`/`Update`/`List` → `SELECT`/`UPDATE`. |
| Dependency tracking / no front-running | ✅ Full (re-mapped) | `todo_deps` + the ready query (LEFT JOIN: corrupt edges block, not pass). |
| Structured task metadata (`json:metadata`) | ✅ Full (re-mapped) | Embedded in `todos.description`; schema unchanged. |
| Cross-session resume | ✅ Full (re-mapped) | On-disk `.tasks.json` (written by `writing-plans`) is the durable source of truth; a new session re-hydrates the session `todos` tables from it. |
| User-thrown gate flow (`checking-gates`/`specifying-gates`) | ✅ Skills full; ⚠️ enforcement manual | Skills ported. Auto re-validation hook can't fire → enforced by discipline: invoke `checking-gates` before closing any `"userGate": true` task. |
| Pre-commit task gate (block `git commit` with open tasks) | ⚠️ Discipline-only | No commit hook fires on Copilot CLI. `executing-plans` / `onboard` instruct: check `SELECT … WHERE status NOT IN ('done')` before committing. |
| Subagent model routing (`mechanical`/`standard`/`frontier`) | ➖ Scaffolding only | `onboard` writes `model-routing.json` and the `modelTier` metadata key is preserved, but **nothing auto-enforces it** (no routing hook). Advisory: pass the mapped `model` to the `task` tool by hand. |
| Configurable commit strategy (`per-task`/`per-plan`) | ➖ Scaffolding only | `onboard` writes `workflow.json` and execution skills can honor it on a best-effort basis, but there's no enforcing hook. |
| `EnterPlanMode`/`ExitPlanMode` | ➖ N/A | No equivalent; skills write the plan to a file and pause for review. |

Legend: ✅ full parity · ⚠️ available but enforced by discipline rather than an
automatic hook · ➖ not applicable, or config scaffolding present but not
auto-enforced (no hook to honor it yet).

### Why the hook-based features are discipline-only

Copilot CLI's config schema documents a `hooks` system (`sessionStart`,
`userPromptSubmitted`, `preToolUse`, `postToolUse`, `agentStop`) and a
`COPILOT_CUSTOM_INSTRUCTIONS_DIRS` env var, but **as of CLI v1.0.55 neither injects
behavior at runtime** — empirically verified by the upstream Copilot-CLI port author
([`jonathan-aulson/superpowers-copilot-cli`](https://github.com/jonathan-aulson/superpowers-copilot-cli),
token-count diffs). The only auto-loaded instructions surface that actually reaches
the model is the repo-local `AGENTS.md`. This port therefore ships:

1. `hooks/hooks.json` — the sessionStart bootstrap, ready for when hooks start firing.
2. `scripts/init-superpowers.sh` — writes the same bootstrap into the repo's
   `AGENTS.md` so it works **today**.
3. The discipline baked into the skills themselves.

When Copilot CLI begins honoring hooks, the same `hooks.json` activates automatic
enforcement with no other change.

## Credits

- Original cross-platform toolkit: [obra/superpowers](https://github.com/obra/superpowers) (MIT).
- Claude Code Extended fork (the porting source): [pcvelz/superpowers](https://github.com/pcvelz/superpowers) (MIT).
- Prior Copilot CLI port that established the platform-gap findings:
  [jonathan-aulson/superpowers-copilot-cli](https://github.com/jonathan-aulson/superpowers-copilot-cli).

MIT licensed (preserved from upstream). See [`UPSTREAM.md`](UPSTREAM.md) for the
porting rules and re-sync instructions.
