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
> feature). The Extended-CC features that upstream implemented as **Claude Code hooks**
> are reproduced two ways: the **pre-commit task gate** ships as a real **git
> pre-commit hook** (git enforces it on every commit — fully working), and the
> **skills discipline** is injected via the auto-loaded repo-root **`AGENTS.md`**.
> Copilot CLI *does* run its own lifecycle hooks (verified), but in the current build
> (0.0.367) the runtime only honors a hook's `modifiedPrompt`/`modifiedArgs` outputs —
> not `additionalContext` or a `deny` decision — so a Copilot hook can't inject context
> or block a commit; the git hook + `AGENTS.md` are the reliable surfaces.
> See [Feature parity](#feature-parity).

## Quick start

```bash
# 1. Install the plugin (once per machine). Skills then auto-load in EVERY project.
copilot plugin install nguyennhianhtri/superpowers-extended-cc-copilot
#    …or from a local clone:
copilot plugin install /path/to/superpowers-extended-cc-copilot

# 2. Verify
copilot plugin list

# 3. (Recommended, per repo) install the AGENTS.md discipline + git pre-commit gate.
#    Run the init script from your clone of this repo:
cd /path/to/your/project
/path/to/superpowers-extended-cc-copilot/scripts/init-superpowers.sh
```

Plugins install at the **user level**, so there is no per-project install — once
installed, the skills are available everywhere. The per-project step 3 writes the
skills discipline into the repo's auto-loaded `AGENTS.md` and installs a git
pre-commit task gate (see [Feature parity](#feature-parity)).

> **Visibility:** while this repo is **private**, only accounts you've granted read
> access can `copilot plugin install` it. Make it **public** and anyone can install it
> with `copilot plugin install nguyennhianhtri/superpowers-extended-cc-copilot` — no
> special access required.

## Install (details)

```bash
# From GitHub
copilot plugin install nguyennhianhtri/superpowers-extended-cc-copilot

# From a local clone
copilot plugin install /path/to/superpowers-extended-cc-copilot

# Verify
copilot plugin list

# Update later (after pushing changes)
copilot plugin install nguyennhianhtri/superpowers-extended-cc-copilot
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
| Skill-first discipline ("check for a skill before responding") | ✅ Full | `using-superpowers` skill + the auto-loaded repo-root `AGENTS.md` bootstrap (`scripts/init-superpowers.sh`). |
| Native task management | ✅ Full (re-mapped) | `sql` on `todos`; `TaskGet`/`Update`/`List` → `SELECT`/`UPDATE`. |
| Dependency tracking / no front-running | ✅ Full (re-mapped) | `todo_deps` + the ready query (LEFT JOIN: corrupt edges block, not pass). |
| Structured task metadata (`json:metadata`) | ✅ Full (re-mapped) | Embedded in `todos.description`; schema unchanged. |
| Cross-session resume | ✅ Full (re-mapped) | On-disk `.tasks.json` (written by `writing-plans`) is the durable source of truth; a new session re-hydrates the session `todos` tables from it. |
| User-thrown gate flow (`checking-gates`/`specifying-gates`) | ✅ Skills full; ⚠️ enforcement manual | Skills ported. Copilot hooks can't `deny` a tool (see below), so closing a gate is enforced by discipline: invoke `checking-gates` before closing any `"userGate": true` task. |
| Pre-commit task gate (block `git commit` with open tasks) | ✅ Full | A real **git pre-commit hook** (`scripts/init-superpowers.sh` installs `hooks/pre-commit` into `.git/hooks/`) blocks `git commit` while any `.tasks.json` has unfinished tasks. Works for every commit, agent or human. Bypass: `git commit --no-verify`. |
| Subagent model routing (`mechanical`/`standard`/`frontier`) | ➖ Scaffolding only | `onboard` writes `model-routing.json` and the `modelTier` metadata key is preserved, but nothing auto-enforces it. Advisory: pass the mapped `model` to the `task` tool by hand. |
| Configurable commit strategy (`per-task`/`per-plan`) | ➖ Scaffolding only | `onboard` writes `workflow.json`; execution skills honor it best-effort. |
| `EnterPlanMode`/`ExitPlanMode` | ➖ N/A | No equivalent; skills write the plan to a file and pause for review. |

Legend: ✅ full parity · ⚠️ available but enforced by discipline · ➖ not applicable,
or config scaffolding present but not auto-enforced.

### About Copilot CLI hooks (the accurate story)

Copilot CLI **does** run lifecycle hooks — verified directly against the installed
runtime (build `0.0.367`). Hook configs load from `<git-root>/.github/hooks/**/*.json`
with this shape:

```json
{ "version": 1, "hooks": { "preToolUse": [ { "type": "command", "bash": "…", "timeoutSec": 15 } ] } }
```

Events: `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`,
`sessionEnd`, `errorOccurred`. Each command hook receives the event as JSON on
**stdin** and may return a JSON decision on **stdout**. Confirmed by experiment
(sessionStart side-effect fired; preToolUse received the `bash` tool's `git commit`
args).

**The catch in this build:** the runtime only consumes a *subset* of each hook's
declared output — `userPromptSubmitted.modifiedPrompt`, `preToolUse.modifiedArgs`,
and `postToolUse.modifiedResult`. It does **not** currently consume
`sessionStart.additionalContext` or `preToolUse.permissionDecision` (`"deny"`). So a
Copilot hook cannot inject session context or veto a tool call yet. That's why this
port uses the two surfaces that *are* reliable:

1. **`AGENTS.md`** (auto-loaded from the repo root) for the skills discipline — the
   `using-superpowers` content is written there by `scripts/init-superpowers.sh`.
2. **A real git `pre-commit` hook** for the task gate — git enforces it unconditionally,
   so it doesn't depend on Copilot honoring `deny`.

If a future Copilot CLI build starts consuming `additionalContext`/`permissionDecision`,
these features can additionally move into native `.github/hooks/` configs.

## Credits

- Original cross-platform toolkit: [obra/superpowers](https://github.com/obra/superpowers) (MIT).
- Claude Code Extended fork (the porting source): [pcvelz/superpowers](https://github.com/pcvelz/superpowers) (MIT).
- Prior Copilot CLI port that established the platform-gap findings:
  [jonathan-aulson/superpowers-copilot-cli](https://github.com/jonathan-aulson/superpowers-copilot-cli).

MIT licensed (preserved from upstream). See [`UPSTREAM.md`](UPSTREAM.md) for the
porting rules and re-sync instructions.
