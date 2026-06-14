# Upstream & porting notes

This plugin is a port of [`pcvelz/superpowers`](https://github.com/pcvelz/superpowers)
(*Superpowers Extended for Claude Code*, "Extended-CC"), a fork of
[`obra/superpowers`](https://github.com/obra/superpowers).

- **Porting source**: `pcvelz/superpowers` (Extended-CC), version `6.0.3-dev`.
- **Base upstream**: `obra/superpowers`.
- **License**: MIT (preserved).

## Adaptation rules

Skill *bodies* are kept **verbatim** wherever they carry behavior-shaping content
(`<HARD-GATE>`, `<EXTREMELY-IMPORTANT>`, red-flag tables, DOT flowcharts, persuasion
framing). The adaptation is centralized in two reference docs plus short
`<!-- copilot-cli adaptation: ... -->` notes at the top of the task-heavy skills, so
re-syncing with upstream stays mechanical.

| Upstream (Claude Code) | This port (Copilot CLI) |
|---|---|
| `Skill` tool | `skill` tool (auto-discovery by `description`) |
| `Read` / `Write` / `Edit` / `Bash` / `Grep` / `Glob` | `view` / `create` / `edit` / `bash` / `grep` / `glob` (see `references/copilot-tools.md`) |
| `TaskCreate` / `TaskGet` / `TaskUpdate` / `TaskList` | `sql` on `todos` + `todo_deps` (see `references/task-management.md`) |
| Task dependencies / `blockedBy` | rows in `todo_deps` + the "ready query" |
| `json:metadata` block | embedded verbatim in `todos.description` |
| `TodoWrite` | `sql` `todos` table |
| `AskUserQuestion` (structured picker) | `ask_user` (with `choices`), one question at a time |
| `EnterPlanMode` / `ExitPlanMode` | none — write the plan to a file, pause for review |
| `Task` subagent / `subagent_type` | `task` tool with `agent_type` (`general-purpose` / `explore`); `read_agent` / `list_agents` |
| `WebFetch` / `WebSearch` | `web_fetch` |
| Hooks via `.claude/settings.json` | `hooks/hooks.json` (does not fire yet — see below) |
| `~/.claude/` paths | `~/.copilot/` paths |
| `CLAUDE.md` | `AGENTS.md` / `.github/copilot-instructions.md` |
| "Claude Code" / "Claude" runtime | "Copilot CLI" / "Copilot" |

## Files changed vs a verbatim copy

- **Removed**: `references/codex-tools.md`, `references/gemini-tools.md` (other
  platforms), `systematic-debugging/CREATION-LOG.md` (authoring artifact).
- **Renamed**: `writing-skills/examples/CLAUDE_MD_TESTING.md` →
  `AGENTS_MD_TESTING.md` (+ updated the one reference to it).
- **Added**: `references/task-management.md` (the keystone native-task mapping);
  Copilot-CLI rows in `references/copilot-tools.md`; `<!-- copilot-cli adaptation -->`
  notes in `writing-plans`, `executing-plans`, `subagent-driven-development`,
  `brainstorming`, `dispatching-parallel-agents`, `checking-gates`,
  `specifying-gates`, and `shared/task-format-reference.md`.
- **Rewrote**: `using-superpowers` "How to Access Skills" / "Platform Adaptation"
  for Copilot-CLI-primary; `commands/*` to invoke skills via the `skill` tool;
  `commands/onboard.md` for the no-runtime-hooks reality; `hooks/hooks.json` and
  `scripts/init-superpowers.sh` for Copilot CLI.

## Platform gaps (Copilot CLI v1.0.55)

Two documented Copilot CLI surfaces do not yet affect runtime behavior, verified
empirically by the prior port
([`jonathan-aulson/superpowers-copilot-cli`](https://github.com/jonathan-aulson/superpowers-copilot-cli)):

1. **Plugin hooks don't fire.** `hooks/hooks.json` is shipped and ready, but no event
   currently executes it. Workaround: `scripts/init-superpowers.sh` writes the
   sessionStart bootstrap into the repo's `AGENTS.md`.
2. **`COPILOT_CUSTOM_INSTRUCTIONS_DIRS` doesn't inject content.** It registers a path
   but doesn't load the file body. The repo-local `AGENTS.md` (git root or cwd) is the
   only auto-injected instructions surface today.

When either gap closes upstream, the shipped `hooks/hooks.json` activates automatic
enforcement (pre-commit gate, user-gate re-validation, model routing) with no other
change.

## Re-syncing with upstream

When `pcvelz/superpowers` releases a new version:

1. Diff each `skills/<name>/SKILL.md` against this repo's copy.
2. Apply the adaptation rules above to any new content (keep behavior content
   verbatim; only remap tools/tasks/plan-mode/hooks).
3. If a new skill touches native tasks, add a `<!-- copilot-cli adaptation -->` note
   pointing to `references/task-management.md`.
4. Bump `version` in `plugin.json`.
