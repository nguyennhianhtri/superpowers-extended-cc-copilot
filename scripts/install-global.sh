#!/bin/bash
# Global, one-time setup for superpowers-extended-cc-copilot.
#
# Makes the superpowers discipline + pre-commit task gate apply automatically,
# without running init-superpowers.sh in every repo. It sets up three things:
#
#   1. Global skills discipline  -> ~/.copilot/copilot-instructions.md
#      Copilot CLI injects this file's content into EVERY session in EVERY repo
#      (verified against build 0.0.367). A managed, sentinel-delimited block is
#      written; any existing content is preserved.
#
#   2. Pre-commit task gate for NEW repos -> git `init.templateDir`
#      Git copies the template's hooks into every `git init` and `git clone`, so
#      every new/cloned repo gets the gate automatically. Existing per-repo hooks
#      are untouched.
#
#   3. (Optional) Pre-commit gate for ALL repos, including existing ones, via
#      `git config --global core.hooksPath` — enabled with `--all-repos`.
#      NOTE: core.hooksPath REPLACES each repo's .git/hooks, so if you rely on
#      other per-repo hooks, prefer the default (template) mode + run
#      init-superpowers.sh in those repos instead.
#
# Idempotent. Safe to re-run. Requires: bash, git, python3.
#
# Usage:
#   scripts/install-global.sh              # discipline + new-repo gate (recommended)
#   scripts/install-global.sh --all-repos  # also gate ALL repos via core.hooksPath
#   scripts/install-global.sh --uninstall  # remove everything this installed

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SELF_DIR/.." && pwd)"
SRC_HOOK="$PLUGIN_ROOT/hooks/pre-commit"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.copilot}"
# Copilot reads $XDG_CONFIG_HOME/.copilot/... when XDG is set, else ~/.copilot/...
if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
  INSTR="$XDG_CONFIG_HOME/.copilot/copilot-instructions.md"
else
  INSTR="$HOME/.copilot/copilot-instructions.md"
fi
SP_HOME="$HOME/.copilot/superpowers"
TEMPLATE_DIR="$SP_HOME/git-template"

BEGIN="<!-- BEGIN superpowers-extended-cc-copilot global -->"
END="<!-- END superpowers-extended-cc-copilot global -->"

MODE="${1:-}"

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [[ "$MODE" == "--uninstall" ]]; then
  if [[ -f "$INSTR" ]]; then
    python3 - "$INSTR" "$BEGIN" "$END" <<'PY'
import sys, re
path, begin, end = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
new = re.sub(re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "", text, flags=re.DOTALL)
open(path, "w", encoding="utf-8").write(new)
print(f"Removed managed block from {path}.")
PY
  fi
  cur_t="$(git config --global --get init.templateDir || true)"
  [[ "$cur_t" == "$TEMPLATE_DIR" ]] && git config --global --unset init.templateDir && echo "Unset init.templateDir."
  cur_h="$(git config --global --get core.hooksPath || true)"
  [[ "$cur_h" == "$SP_HOME/git-hooks" ]] && git config --global --unset core.hooksPath && echo "Unset core.hooksPath."
  rm -rf "$SP_HOME"
  echo "Uninstalled. (Per-repo .git/hooks installed earlier by init-superpowers.sh are left alone.)"
  exit 0
fi

if [[ ! -f "$SRC_HOOK" ]]; then
  echo "Error: $SRC_HOOK not found. Run from your clone of the plugin." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Global skills discipline -> copilot-instructions.md
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$INSTR")"

read -r -d '' BLOCK <<'EOF' || true
<!-- BEGIN superpowers-extended-cc-copilot global -->
# Superpowers skills discipline (global)

Before responding to ANY message — including clarifying questions — check whether an
installed skill matches the task and invoke it via the `skill` tool. Even a 1% chance
a skill applies is enough to invoke it; if it turns out wrong, you don't have to use
it. See the `using-superpowers` skill for the full rule.

Process skills first (`brainstorming`, `systematic-debugging`), implementation skills
second. New feature: brainstorming -> writing-plans -> executing-plans /
subagent-driven-development. Bug: systematic-debugging before any fix. Before "done":
verification-before-completion.

Native tasks: use the `sql` tool on the `todos` + `todo_deps` tables (there is no
TaskCreate tool). Record dependencies in `todo_deps`; never start a task whose
dependencies aren't `done`. Persist the plan's task list to an on-disk `.tasks.json`
for cross-session resume. See the using-superpowers skill's
references/task-management.md.

User gates: before marking any task `done` whose description contains
`"userGate": true`, invoke the `checking-gates` skill. A git pre-commit hook also
blocks `git commit` while any `.tasks.json` has unfinished tasks.
<!-- END superpowers-extended-cc-copilot global -->
EOF

if [[ -f "$INSTR" ]] && grep -Fq "$BEGIN" "$INSTR"; then
  python3 - "$INSTR" "$BEGIN" "$END" "$BLOCK" <<'PY'
import sys, re
path, begin, end, block = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
new = re.sub(re.escape(begin) + r".*?" + re.escape(end), block, text, count=1, flags=re.DOTALL)
open(path, "w", encoding="utf-8").write(new)
print(f"{'No change to' if new==text else 'Updated managed block in'} {path}.")
PY
elif [[ -f "$INSTR" ]]; then
  [[ "$(tail -c 1 "$INSTR")" != $'\n' ]] && printf '\n' >> "$INSTR"
  printf '\n%s\n' "$BLOCK" >> "$INSTR"
  echo "Appended global discipline block to existing $INSTR."
else
  printf '%s\n' "$BLOCK" > "$INSTR"
  echo "Created $INSTR with global discipline block."
fi

# ---------------------------------------------------------------------------
# 2. Pre-commit gate for NEW repos via init.templateDir
# ---------------------------------------------------------------------------
existing_tpl="$(git config --global --get init.templateDir || true)"
if [[ -n "$existing_tpl" && "$existing_tpl" != "$TEMPLATE_DIR" ]]; then
  # Respect a template dir the user already configured: drop our hook into it.
  mkdir -p "$existing_tpl/hooks"
  cp "$SRC_HOOK" "$existing_tpl/hooks/pre-commit"
  chmod +x "$existing_tpl/hooks/pre-commit"
  echo "Added pre-commit gate to your existing git template: $existing_tpl/hooks/pre-commit"
else
  mkdir -p "$TEMPLATE_DIR/hooks"
  cp "$SRC_HOOK" "$TEMPLATE_DIR/hooks/pre-commit"
  chmod +x "$TEMPLATE_DIR/hooks/pre-commit"
  git config --global init.templateDir "$TEMPLATE_DIR"
  echo "Set git init.templateDir=$TEMPLATE_DIR (new repos + clones get the gate)."
fi

# ---------------------------------------------------------------------------
# 3. Optional: gate ALL repos via core.hooksPath
# ---------------------------------------------------------------------------
if [[ "$MODE" == "--all-repos" ]]; then
  HOOKS_PATH="$SP_HOME/git-hooks"
  mkdir -p "$HOOKS_PATH"
  cp "$SRC_HOOK" "$HOOKS_PATH/pre-commit"
  chmod +x "$HOOKS_PATH/pre-commit"
  git config --global core.hooksPath "$HOOKS_PATH"
  echo "Set git core.hooksPath=$HOOKS_PATH (ALL repos gated)."
  echo "  Caveat: this overrides per-repo .git/hooks. Remove with: git config --global --unset core.hooksPath"
fi

cat <<EOF

Done. Summary:
  • Skills discipline injected globally via $INSTR (every Copilot CLI session).
  • Plugin skills: ensure installed once per machine ->
      copilot plugin install nguyennhianhtri/superpowers-extended-cc-copilot
  • Commit gate: new repos/clones get it automatically via init.templateDir.$([[ "$MODE" == "--all-repos" ]] && echo "
    ALL repos gated via core.hooksPath.")
  • Existing repos: run scripts/init-superpowers.sh inside them (or re-run with --all-repos).

Undo everything: scripts/install-global.sh --uninstall
EOF
