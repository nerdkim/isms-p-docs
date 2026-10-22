#!/usr/bin/env bash
# bootstrap-hooks.sh - wire the local git hooks and the commit template in THIS working copy.
#
# Why this exists: `core.hooksPath` and `commit.template` live in `.git/config`, which is not
# committed and therefore does not travel. A fresh clone of a fully adopted consumer has the
# guard files, the workflow and the CLAUDE.md block, and NO local hooks at all: a deliberately
# violating commit lands clean with no checker output. The guard looks installed and enforces
# nothing locally.
#
# CI is unaffected, and CI is the authority (docs/20 s2), so this is about fast feedback rather
# than about the gate. But "the hooks silently do not exist in this clone" is exactly the state
# that teaches people the hooks are optional.
#
# Run it after cloning:   bash harness/bootstrap-hooks.sh
# A Node repo gets it automatically from the root package.json `prepare` script.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 0

[ -d harness/githooks ] || { echo "bootstrap-hooks: harness/githooks is absent; nothing to wire." >&2; exit 0; }
chmod +x harness/githooks/* 2>/dev/null || true

existing="$(git config --get core.hooksPath 2>/dev/null || true)"
if [ -z "$existing" ] || [ "$existing" = "harness/githooks" ]; then
  git config core.hooksPath harness/githooks
  echo "bootstrap-hooks: core.hooksPath = harness/githooks"
else
  echo "bootstrap-hooks: core.hooksPath is already '$existing'; leaving it alone." >&2
  echo "  chain the guard from it, or switch with: git config core.hooksPath harness/githooks" >&2
fi

# In a public repository (harness/public-repo, docs/22 s7) the template's trailer names the OWNER's
# bot co-author, so a contributor's clone must not get it: every commit written in the editor would
# carry someone else's identity. The template is wired only for an identity on the owner allowlist,
# and a contributor's clone that an earlier run wired is unwired. harness/lib.sh is the one reader of
# both facts; without it the repository is treated as private, as before.
contributor=0
if [ -f harness/lib.sh ]; then
  # shellcheck source=/dev/null
  . harness/lib.sh
  if command -v playbook_public_repo >/dev/null 2>&1 && [ "$(playbook_public_repo .)" = on ]; then
    IFS=$'\t' read -r id_name id_email <<< "$(playbook_git_identity .)"
    if [ -n "${id_name:-}${id_email:-}" ] && ! playbook_is_owner "${id_name:-}" "${id_email:-}"; then contributor=1; fi
  fi
fi

if [ -f harness/gitmessage ] && [ "$contributor" -eq 1 ]; then
  if [ "$(git config --get commit.template 2>/dev/null || true)" = harness/gitmessage ]; then
    git config --unset commit.template || exit 1
    echo "bootstrap-hooks: public repository and a contributor identity: commit.template unset (it names the owner's co-author)"
  else
    echo "bootstrap-hooks: public repository and a contributor identity: commit.template left alone (the playbook one names the owner's co-author)"
  fi
elif [ -f harness/gitmessage ]; then
  current_template="$(git config --get commit.template 2>/dev/null || true)"
  if [ -z "$current_template" ] || [ "$current_template" = harness/gitmessage ]; then
    git config commit.template harness/gitmessage || exit 1
    echo "bootstrap-hooks: commit.template = harness/gitmessage"
  else
    echo "bootstrap-hooks: preserving commit.template=$current_template"
  fi
fi
