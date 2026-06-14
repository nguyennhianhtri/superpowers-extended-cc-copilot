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
| Hooks via `.claude/settings.json` | git `pre-commit` hook for the task gate; `AGENTS.md` for discipline. (Copilot CLI hooks at `.github/hooks/**/*.json` fire but don't consume `additionalContext`/`deny` in build 0.0.367 — see "Copilot CLI hooks" below.) |
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
  `specifying-gates`, and `shared/task-format-reference.md`; `hooks/pre-commit` (the
  git task gate).
- **Rewrote**: `using-superpowers` "How to Access Skills" / "Platform Adaptation"
  for Copilot-CLI-primary; `commands/*` to invoke skills via the `skill` tool;
  `scripts/init-superpowers.sh` to write the `AGENTS.md` bootstrap **and** install the
  git pre-commit gate.

## Copilot CLI hooks (verified against build 0.0.367)

Copilot CLI runs lifecycle hooks loaded from `<git-root>/.github/hooks/**/*.json`:

```json
{ "version": 1, "hooks": { "preToolUse": [ { "type": "command", "bash": "…", "timeoutSec": 15 } ] } }
```

Events: `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`,
`sessionEnd`, `errorOccurred`. A command hook gets the event as JSON on stdin and may
print a JSON decision on stdout. **Verified by experiment** that hooks fire (a
sessionStart side-effect ran; a preToolUse hook saw the `bash` `git commit` args).

**Limitation in this build:** the runtime only consumes `userPromptSubmitted.modifiedPrompt`,
`preToolUse.modifiedArgs`, and `postToolUse.modifiedResult`. It does **not** consume
`sessionStart.additionalContext` or `preToolUse.permissionDecision` (`deny`) — those
appear in the schema/SDK but are never read by the bundled runtime. Therefore a Copilot
hook can neither inject session context nor block a tool call yet.

Consequences for this port:
- **Skills discipline** is injected via the auto-loaded repo-root `AGENTS.md`
  (`scripts/init-superpowers.sh` writes it), not a sessionStart hook.
- **Pre-commit task gate** is a real **git** `pre-commit` hook (`hooks/pre-commit`,
  installed by the init script) — git enforces it regardless of Copilot.
- **`COPILOT_CUSTOM_INSTRUCTIONS_DIRS`** registers a path but doesn't load the file
  body, so the repo-local `AGENTS.md` remains the only auto-injected instructions
  surface.

If a later build starts consuming `additionalContext`/`permissionDecision`, the
discipline and gate can additionally move into native `.github/hooks/` configs.

## Re-syncing with upstream

When `pcvelz/superpowers` releases a new version:

1. Diff each `skills/<name>/SKILL.md` against this repo's copy.
2. Apply the adaptation rules above to any new content (keep behavior content
   verbatim; only remap tools/tasks/plan-mode/hooks).
3. If a new skill touches native tasks, add a `<!-- copilot-cli adaptation -->` note
   pointing to `references/task-management.md`.
4. Bump `version` in `plugin.json`.
