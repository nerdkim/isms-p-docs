#!/usr/bin/env bash
# lib.sh - the one place the playbook version marker is defined and compared.
#
# Why this file exists: the marker was read in four places with three different patterns and
# written in a fifth, and NONE of the readers could parse the form the legacy population
# actually uses. A bolded line, `> **playbook version:** v0.1.6`, returned no match, so a repo
# that adopted the standard a year ago was reported as never having adopted it, which is the
# worst direction for the error: the update path treats it as greenfield.
#
# Nothing here compares versions with `sort -V` alone. The version line was RESET (the
# published history restarts at v0.1.0, and the release title for it says so), so a consumer
# still carrying a pre-reset v1.x marker sorts ABOVE current and would be told it is ahead of
# the standard, suppressing the very update it needs.
#
# It is also the one place two per-repository facts are read, for the same reason: the commit-author
# allowlist and the public repository marker (harness/public-repo) decide who the owner-only rules
# apply to, and the commit checker, the structure checker, the installer and the hook bootstrap must
# not drift into four different answers.
#
# Source it, do not execute it:  . "$(dirname "$0")/lib.sh"
# Tested by harness/test-lib.sh (docs/00 D6).

# While canon uses major 0, legacy major 1 and above belong to the earlier numbering scheme.
# Revisit this boundary before canon returns to major 1; the number alone cannot identify an epoch.
PLAYBOOK_MIN_COMPARABLE_MAJOR=1

# One pattern, tolerating markdown emphasis around either the label or the value, and both
# label languages. `\K` drops everything before the version so the match IS the version.
PLAYBOOK_MARKER_RE='playbook[[:space:]]*[*_]*[[:space:]]*(버전|version)[[:space:]]*[*_]*[[:space:]]*:[[:space:]]*[*_]*[[:space:]]*\Kv[0-9]+\.[0-9]+\.[0-9]+'

# playbook_read_adopted DIR -> the adopted version, or empty.
# harness/ADOPTED is the machine-readable answer and is preferred; the prose marker in
# CLAUDE.md is the fallback for a repo installed before ADOPTED existed. v0.3.x kept that prose
# in a regular AGENTS.md, so that name is read after CLAUDE.md. A public repository keeps the
# block in the gitignored CLAUDE.local.md, which is read last. Prose is for people and a
# parser should not depend on it, which is exactly how four readers drifted.
playbook_read_adopted() {
  local d="${1:-.}" v="" f
  if [ -f "$d/harness/ADOPTED" ]; then
    v="$(grep -m1 -oP '^version:[[:space:]]*\Kv[0-9]+\.[0-9]+\.[0-9]+' "$d/harness/ADOPTED" 2>/dev/null || true)"
  fi
  for f in CLAUDE.md AGENTS.md CLAUDE.local.md; do
    [ -z "$v" ] || break
    v="$(grep -hoP "$PLAYBOOK_MARKER_RE" "$d/$f" 2>/dev/null | head -1 || true)"
  done
  printf '%s' "$v"
}

# playbook_version_cmp A B -> prints one of:
#   behind | current | ahead | pre-reset | unknown
# read as "A is <result> relative to B", where B is normally the canon VERSION.
playbook_version_cmp() {
  local a="${1:-}" b="${2:-}" amaj amin apat bmaj bmin bpat
  case "$a" in v[0-9]*) ;; *) printf 'unknown'; return 0 ;; esac
  case "$b" in v[0-9]*) ;; *) printf 'unknown'; return 0 ;; esac
  IFS=. read -r amaj amin apat <<< "${a#v}"
  IFS=. read -r bmaj bmin bpat <<< "${b#v}"
  case "$amaj$amin$apat$bmaj$bmin$bpat" in *[!0-9]*|'') printf 'unknown'; return 0 ;; esac
  # A pre-reset marker is not "ahead". It is a different numbering scheme, and the only honest
  # answer is that the repo predates the reset and must re-adopt.
  if [ "$amaj" -ge "$PLAYBOOK_MIN_COMPARABLE_MAJOR" ] && [ "$bmaj" -lt "$PLAYBOOK_MIN_COMPARABLE_MAJOR" ]; then
    printf 'pre-reset'; return 0
  fi
  if   [ "$amaj" -lt "$bmaj" ]; then printf 'behind'
  elif [ "$amaj" -gt "$bmaj" ]; then printf 'ahead'
  elif [ "$amin" -lt "$bmin" ]; then printf 'behind'
  elif [ "$amin" -gt "$bmin" ]; then printf 'ahead'
  elif [ "$apat" -lt "$bpat" ]; then printf 'behind'
  elif [ "$apat" -gt "$bpat" ]; then printf 'ahead'
  else printf 'current'
  fi
}

# playbook_describe_delta ADOPTED CURRENT -> a sentence for a human, on one line.
playbook_describe_delta() {
  local a="${1:-}" b="${2:-}" r
  if [ -z "$a" ]; then printf 'no marker: this repo is adopting the standard now'; return 0; fi
  r="$(playbook_version_cmp "$a" "$b")"
  case "$r" in
    behind)    printf 'BEHIND: adopted %s, current %s. Re-run install-playbook.sh to update.' "$a" "$b" ;;
    current)   printf 'CURRENT: adopted %s matches the standard.' "$a" ;;
    ahead)     printf 'AHEAD: adopted %s is newer than the clone (%s). The clone is stale: git -C playbook pull.' "$a" "$b" ;;
    pre-reset) printf 'PRE-RESET: adopted %s predates the version reset (current numbering starts at v0.1.0). Re-adopt rather than compare.' "$a" ;;
    *)         printf 'UNKNOWN: could not compare %s with %s.' "$a" "$b" ;;
  esac
}

# ---- the owner, and whether this repository is public -----------------------------------

# playbook_owner_re -> the commit-author allowlist, an extended regex matched against
# "AUTHOR_NAME AUTHOR_EMAIL". check-commit-messages.sh M5 reports an author outside it, and in a
# public repository it also decides which commits are the owner's. Override with
# ALLOWED_AUTHOR_RE in a repo with more authors. noreply@github.com is the author of the synthetic
# pull request merge commit GitHub creates, which is not a contributor's.
playbook_owner_re() {
  printf '%s' "${ALLOWED_AUTHOR_RE:-nerdkim|@nerd\.kim|noreply@github\.com}"
}

# playbook_is_owner NAME EMAIL -> status 0 when the author is on the allowlist.
# Git author fields are self-declared, so this is a policy split and not an identity proof: anyone
# can write a commit under any name. That is acceptable only because being classified as the owner
# never exempts a commit from anything; it is the owner who gets the stricter rules.
playbook_is_owner() {
  # A here-string, never a pipe into grep -q: callers run under pipefail, where grep's early exit
  # can turn a match into a failure through SIGPIPE.
  grep -qE "$(playbook_owner_re)" <<< "${1:-} ${2:-}"
}

# playbook_git_identity DIR -> "NAME<TAB>EMAIL" of the author git would record for a commit made in
# DIR now, or nothing when git cannot tell. `git var` honours GIT_AUTHOR_NAME and GIT_AUTHOR_EMAIL
# as well as user.name and user.email, so it answers what the commit will actually carry.
playbook_git_identity() {
  local id name email
  id="$(git -C "${1:-.}" var GIT_AUTHOR_IDENT 2>/dev/null)" || return 0
  case "$id" in *' <'*'>'*) ;; *) return 0 ;; esac
  name="${id%% <*}"
  email="${id#* <}"; email="${email%%>*}"
  printf '%s\t%s' "$name" "$email"
}

# playbook_public_repo DIR -> prints one of:
#   (nothing)  no marker: a private repository, every rule applies to every commit
#   on         harness/public-repo is present and states a reason
#   bad:WHY    the marker is present but unusable; callers treat the mode as OFF and report WHY
#
# The marker switches owner-only rules off for everybody else, so it defends itself the way
# harness/commit-gate-since and conventions-allow do: the first non-comment line is a reason of at
# least 10 characters, and a marker without one grants nothing. A marker that is not a regular file
# grants nothing either. Every reader fails closed on `bad`, so a broken marker can only ever make
# the checks stricter, never laxer.
playbook_public_repo() {
  local f reason
  f="${1:-.}/harness/public-repo"
  [ -e "$f" ] || [ -L "$f" ] || return 0
  if [ -L "$f" ] || [ ! -f "$f" ]; then
    printf 'bad:harness/public-repo is not a regular file'; return 0
  fi
  reason="$(grep -vE '^[[:space:]]*(#|$)' "$f" 2>/dev/null | head -1 | tr -d '[:space:]')"
  if [ "${#reason}" -lt 10 ]; then
    printf 'bad:harness/public-repo states no reason (its first non-comment line must give one, 10 or more characters)'
    return 0
  fi
  printf 'on'
}

# ---- whether a directory is the playbook repository itself ---------------------------------

# playbook_is_self DIR -> status 0 when DIR is the playbook repository, the source of the standard
# rather than a consumer of it. Self mode switches the consumer-only rules off, T4, T8 and T9 in
# check-structure-conformance.sh and the module-code rule [9] in check-infra-conformance.sh (where the
# playbook's own modules/ and template fixtures are the code that rule keeps out of service
# repositories), and switches the playbook-only T14 on. Both checkers read this one answer so they
# cannot drift apart.
#
# It must not be spoofable, so it requires real playbook content rather than the paths: the installer's
# own marker string inside harness/install.sh, the conventions workflow template, a docs/00-*.md overview
# and a VERSION holding vX.Y.Z (the leading v optional, so renaming the overview or dropping the prefix
# does not silently turn self mode off). Three empty files with the right names stay a consumer.
playbook_is_self() {
  local d="${1:-.}"
  [ -f "$d/VERSION" ] && [ -f "$d/harness/conventions.yml" ] \
    && grep -q 'playbook guard-set install' "$d/harness/install.sh" 2>/dev/null \
    && [ -n "$(find "$d/docs" -maxdepth 1 -name '00-*.md' -print -quit 2>/dev/null)" ] \
    && grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$' "$d/VERSION" 2>/dev/null
}
