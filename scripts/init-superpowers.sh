#!/bin/bash
# Per-repo init for superpowers-extended-cc-copilot.
#
# Writes (or updates in place) a sentinel-delimited block in the project's
# AGENTS.md so Copilot CLI picks up the skills discipline on every session in
# that repo.
#
# Why per-repo: as of Copilot CLI v1.0.55 the only auto-loaded instructions
# surface that actually injects content into the model context is the
# repo-local AGENTS.md (git root or cwd). Plugin hooks/hooks.json does not fire,
# and COPILOT_CUSTOM_INSTRUCTIONS_DIRS registers a path but does not load the
# body — both verified empirically (see README "Feature parity").
#
# Idempotent: re-running updates the managed block in place; any other content
# in your AGENTS.md is preserved untouched.

set -euo pipefail

if root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  target="$root/AGENTS.md"
  where="git root"
else
  target="$PWD/AGENTS.md"
  where="current directory (no git repo found)"
fi

BEGIN="<!-- BEGIN superpowers-extended-cc-copilot bootstrap -->"
END="<!-- END superpowers-extended-cc-copilot bootstrap -->"

read -r -d '' BLOCK <<'EOF' || true
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
EOF

if [[ ! -f "$target" ]]; then
  printf '%s\n' "$BLOCK" > "$target"
  echo "Created $target ($where) with bootstrap block."
  exit 0
fi

if grep -Fq "$BEGIN" "$target"; then
  python3 - "$target" "$BEGIN" "$END" "$BLOCK" <<'PY'
import sys, re
path, begin, end, block = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
text = open(path, encoding="utf-8").read()
pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
new = pattern.sub(block, text, count=1)
if new == text:
    print(f"No change to {path} (block already up to date).")
else:
    open(path, "w", encoding="utf-8").write(new)
    print(f"Updated managed block in {path}.")
PY
else
  if [[ -s "$target" ]] && [[ "$(tail -c 1 "$target")" != $'\n' ]]; then
    printf '\n' >> "$target"
  fi
  if [[ -s "$target" ]]; then
    printf '\n' >> "$target"
  fi
  printf '%s\n' "$BLOCK" >> "$target"
  echo "Appended bootstrap block to existing $target."
fi
