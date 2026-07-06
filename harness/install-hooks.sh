#!/usr/bin/env bash
# install-hooks.sh - wire this working copy to the guard set under harness/.
#
# WHY THIS EXISTS
#   git hooks are activated by `core.hooksPath`, which lives in .git/config. That is LOCAL
#   state: it is not committed and does not travel with a clone. A Node repo hides this by
#   putting the git config call in package.json's `prepare` script, which pnpm runs on
#   install. This repository holds documents only, so there is no package.json and no
#   install step to hang it on. Run this once per clone instead.
#
# WHAT IT DOES (idempotent, local only, nothing is committed)
#   core.hooksPath  = harness/githooks    activates pre-commit, commit-msg, pre-push
#   commit.template = harness/gitmessage  prefills the commit message form
#   and makes sure the three hooks are executable.
#
# The hooks are a convenience guardrail and are bypassable with `git commit --no-verify`.
# The authoritative gate is CI (.github/workflows/docs.yml), which runs the same checkers
# and cannot be bypassed (playbook docs/16 6, docs/20 2).
#
# Usage, from anywhere inside the working copy:
#   bash harness/install-hooks.sh
set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "install-hooks: not inside a git working copy." >&2
  echo "차단: git working copy 안에서 실행하세요." >&2
  exit 1
}
cd "$root" || exit 1

hooks_dir="harness/githooks"
template="harness/gitmessage"
rc=0

# 1. the hooks must exist and be executable, or core.hooksPath points at nothing useful.
missing=""
for h in pre-commit commit-msg pre-push; do
  if [ -f "$hooks_dir/$h" ]; then
    chmod +x "$hooks_dir/$h"
  else
    missing="$missing $h"
  fi
done
if [ -n "$missing" ]; then
  echo "install-hooks: missing hook(s) in $hooks_dir:$missing" >&2
  echo "차단: guard 파일이 없습니다. 자료집을 다시 clone하거나 playbook의 harness/install.sh로 복구하세요." >&2
  exit 1
fi

# 2. wire the hooks.
git config core.hooksPath "$hooks_dir" || rc=1

# 3. wire the commit template only when it is actually present, so a partial guard set
#    does not leave git pointing at a file that does not exist.
if [ -f "$template" ]; then
  git config commit.template "$template" || rc=1
else
  echo "install-hooks: $template not found, commit.template left unset." >&2
fi

if [ "$rc" -ne 0 ]; then
  echo "install-hooks: git config failed." >&2
  exit "$rc"
fi

echo "install-hooks: wired this working copy."
echo "  core.hooksPath  = $(git config --get core.hooksPath)"
echo "  commit.template = $(git config --get commit.template || echo '(unset)')"
echo
echo "Active guards: pre-commit (documentation conventions), commit-msg (message rules),"
echo "pre-push (blocks a direct push to master). CI is the authoritative gate."
