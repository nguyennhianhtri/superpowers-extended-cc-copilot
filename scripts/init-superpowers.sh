#!/bin/bash
# Per-repo init for superpowers-extended-cc-copilot.
#
# Sets up two things in the current repo:
#   1. A sentinel-delimited block in AGENTS.md so Copilot CLI picks up the skills
#      discipline on every session (AGENTS.md at the git root is auto-injected into
#      the model context — verified on Copilot CLI 0.0.367).
#   2. A real git pre-commit hook (.git/hooks/pre-commit) that blocks `git commit`
#      while any task in a *.tasks.json under the repo is unfinished — the working
#      equivalent of upstream's pre-commit task gate. (Copilot CLI's own preToolUse
#      hooks fire but cannot deny a tool in 0.0.367, so we gate at the git layer,
#      which is bulletproof. See README "Feature parity".)
#
# Idempotent: re-running updates the managed AGENTS.md block in place and refreshes
# the git hook; any other content in AGENTS.md and any pre-existing pre-commit hook
# are preserved (the latter is chained).

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SELF_DIR/.." && pwd)"

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

Commit gate: a git pre-commit hook blocks `git commit` while any `.tasks.json` in this
repo has unfinished tasks. Finish/cancel them first (or `git commit --no-verify`).
<!-- END superpowers-extended-cc-copilot bootstrap -->
EOF

if [[ ! -f "$target" ]]; then
  printf '%s\n' "$BLOCK" > "$target"
  echo "Created $target ($where) with bootstrap block."
elif grep -Fq "$BEGIN" "$target"; then
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

# ---------------------------------------------------------------------------
# 2. Install the git pre-commit task gate (only when inside a git repo).
# ---------------------------------------------------------------------------
if [[ -n "${root:-}" ]]; then
  src_hook="$PLUGIN_ROOT/hooks/pre-commit"
  hooks_dir="$(git rev-parse --git-path hooks)"
  dest_hook="$hooks_dir/pre-commit"
  marker="superpowers-extended-cc-copilot — pre-commit task gate"

  if [[ ! -f "$src_hook" ]]; then
    echo "Note: $src_hook not found; skipped git hook install."
  else
    mkdir -p "$hooks_dir"
    if [[ -f "$dest_hook" ]] && ! grep -Fq "$marker" "$dest_hook"; then
      # Preserve a pre-existing, non-superpowers hook by chaining to it.
      if [[ ! -f "$hooks_dir/pre-commit.local" ]]; then
        mv "$dest_hook" "$hooks_dir/pre-commit.local"
        echo "Preserved your existing pre-commit hook as pre-commit.local (it will still run)."
      fi
      cp "$src_hook" "$dest_hook"
      # Chain the preserved hook at the end of ours.
      printf '\n# chain previously-installed hook\n[ -x "%s/pre-commit.local" ] && exec "%s/pre-commit.local" "$@"\n' \
        "$hooks_dir" "$hooks_dir" >> "$dest_hook"
    else
      cp "$src_hook" "$dest_hook"
    fi
    chmod +x "$dest_hook"
    echo "Installed git pre-commit task gate at $dest_hook."
  fi
else
  echo "Not a git repo — skipped git pre-commit hook (AGENTS.md block written only)."
fi

