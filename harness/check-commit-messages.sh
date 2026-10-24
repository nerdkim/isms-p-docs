#!/usr/bin/env bash
# check-commit-messages.sh - the SERVER-SIDE backstop for commit-message rules.
#
# Why this exists: the commit-msg git hook is bypassable with `git commit --no-verify`,
# and a file-content grep cannot see a commit message, so until now the co-author policy
# (docs/12 s2, D29) and the forbidden-unicode rule in commit messages (docs/16 s2.1) had
# NO authoritative gate. This checker reads the messages back out of git history over a
# commit range, so CI (a required status check) re-validates every commit in a PR and a
# `--no-verify` commit is caught before merge.
#
# Three modes:
#   range mode  (CI):   check every commit in a range   -> bash check-commit-messages.sh [--range A..B]
#   single mode (hook): check one prepared message file -> bash check-commit-messages.sh --msg-file .git/COMMIT_EDITMSG
#   pr mode     (CI):   check a pull request's text     -> PR_TITLE=.. PR_BODY=.. bash check-commit-messages.sh --pr-text
#
# Rules (source doc in parentheses):
#   FAIL M1 forbidden unicode punctuation in the message (docs/16 s2.1)
#   FAIL M2 unsanctioned co-author, generated signature or Claude session link (docs/12 s2, D30, D36, D48)
#   FAIL P1 the same co-author, signature and session link rules on a pull request title and body
#           opened by the repository owner (docs/12 s5.3, D48)
#   WARN M3 subject is not Conventional Commits `type(scope): subject` (docs/12 s2.1)
#   WARN M4 subject ends with a period (docs/16 s4.4)
#   WARN M5 commit author is outside the allowlist (docs/12 s2)
#   WARN M6 Hangul in the commit message; commits are English (docs/16 s4.1). ADVISORY ONLY
#   WARN M7 the sanctioned co-author trailer is absent (docs/12 s2, D30)
#   ADVI M8 a superseded attribution: the legacy co-author trailer, or a Claude session link in a
#           commit written before the rule and checked against a base without it (docs/12 s2, D30, D36)
#
# Severity ratchet (brownfield-friendly, docs/11): M1 and M2 are always FAIL because the
# commit-msg hook already enforced them, so CI only closes the bypass. M3 to M5 and M7 are
# later rules and start as WARN so adopting an existing repo is not blocked by pre-existing
# history. Promote them to FAIL for a repo that is clean over the range its pull requests check
# (see the adoption cutoff below) by creating the marker file
# `harness/commitmsg-strict` (the new-project scaffold creates it) or by exporting
# COMMITMSG_STRICT=1. M6 and M8 stay advisory even under STRICT: M6 because a commit that
# changes a Korean-language rule must be able to quote the Korean form it changes, and M8
# because the trailer it names WAS the sanctioned one, so promoting it would turn every
# already-adopted repo's own history into a merge blocker on the day the identity changed.
#
# Adoption cutoff (docs/21 s4.2). `harness/commit-gate-since` bounds the OLD end of the range
# for the identity rules M2, M5, M7 and M8 only, so a repo adopting the standard is judged on the
# identity (co-author, signature, author, trailer) of the commits it writes afterwards: none of
# those can be retrofitted to history that already exists. The file holds a sha or an ISO date on
# its first non-comment line and a mandatory reason on the next; a reasonless marker suppresses
# nothing and FAILs, mirroring the conventions-allow self-defense (docs/16 s6.2). M1 is never
# bounded: a forbidden character in an old message is still worth naming, and the range is bounded
# by the base ref anyway. The shape rules M3 and M4 and the M6 advisory are not bounded either, on
# purpose (harness/install.sh probes the real history the same way): every commit in the range is
# judged on its subject, pre-adoption ones included. Under strict mode a pull request whose range
# still reaches pre-adoption commits with non-Conventional subjects therefore fails M3. Before
# creating `harness/commitmsg-strict` by hand, run this checker with COMMITMSG_STRICT=1 over the
# range a release PR checks: `--range origin/main..develop` in a develop-main repository, or
# `--range origin/main..<work branch>` in a main-only one.
#
# Public repository (docs/22 s7). `harness/public-repo` marks a repository that outside
# contributors commit to. The identity rules M2, M5, M7 and M8 describe the OWNER's commits (his
# author name, his bot co-author, no generated signature), so there they run only for commits whose
# author is on the M5 allowlist; every other commit is a contributor commit and gets M1, the shape
# rules M3 and M4, and the M6 advisory, exactly like the owner's. The marker's first non-comment
# line is a mandatory reason; a reasonless or unreadable marker is a FAIL and grants nothing.
# Honest limit: git author fields are self-declared, so the split is policy, not a security
# boundary. Claiming the owner's name gains a contributor nothing (it only adds rules), but an
# owner commit written under another identity is read as a contributor's. In hook mode an identity
# git cannot tell is treated as the owner's, so an unknown author gets every rule (fail closed).
#
# Merge commits and `Revert "..."` commits are exempt from the subject-shape rules (git
# generates those subjects). An empty message is skipped.
#
# Requires GNU grep (-P) and harness/lib.sh beside this file. Exit 1 on any FAIL, else 0.
set -uo pipefail
# No pipe into `grep -q` (see check-structure-conformance.sh): under pipefail an early match can
# fail the pipe through SIGPIPE, so variables go in with a here-string.

if ! grep -qP x <<< x 2>/dev/null; then
  echo "error: GNU grep -P (PCRE) required" >&2; exit 2
fi
# The author allowlist and the public repository marker are read in one place, harness/lib.sh, so
# this gate, the structure checker, the installer and the hook bootstrap agree on who the owner is.
# Refuse without it rather than guess: a missing lib.sh is an incomplete guard set (T7), and a
# fallback copy of the allowlist here is the drift the shared reader exists to prevent.
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$HERE/lib.sh" ]; then
  # shellcheck source=/dev/null
  . "$HERE/lib.sh"
fi
if ! command -v playbook_public_repo >/dev/null 2>&1; then
  echo "error: harness/lib.sh is missing or outdated beside $0; re-run install-playbook.sh" >&2; exit 2
fi
# Fail CLOSED on a locale where grep -P cannot match a `\x{...}` code point. In a non-UTF-8 locale
# grep exits 2, and because the M1 capture ends in `|| true` that error would be read as "no hits",
# making the forbidden-character rule silently pass. Probe once and refuse to run instead.
if ! grep -qP '[\x{2014}]' <<< $'\xe2\x80\x94' 2>/dev/null; then
  echo "error: grep -P cannot match \\x{...} in this locale (LC_ALL=${LC_ALL:-unset}, LANG=${LANG:-unset})." >&2
  echo "       Re-run under a UTF-8 locale, e.g. LC_ALL=C.UTF-8 bash $0" >&2
  exit 2
fi

# Forbidden unicode (docs/16 s2.1), referenced by code point only, so this file carries no
# literal of them and passes check-conventions[1] like every other file.
FORBIDDEN='[\x{2014}\x{2013}\x{2015}\x{00B7}\x{2022}\x{FF0D}]'

# The single sanctioned co-author (docs/12 s2, D30). Anything else, including a generated
# signature, is blocked. Anchored at both ends: an unanchored pattern would let a line reading
# `Co-Authored-By: Claude <x> Co-Authored-By: mikdren <bot-sidekick@nerd.kim>` satisfy the
# negative grep and smuggle a second co-author through on the same line.
COAUTHOR='^[[:space:]]*co-authored-by:[[:space:]]*mikdren[[:space:]]*<bot-sidekick@nerd\.kim>[[:space:]]*$'
# The identity D30 supersedes. It is ACCEPTED but reported (M8), never promoted to FAIL. The
# rename is not a bare substitution: this repository alone carries the old trailer on 39 of its
# commits and every already-adopted project carries it too, and M2 runs over the whole pull
# request range, so a hard swap would turn every historical sanctioned commit into a merge
# blocker. A release that changes an identity may only WIDEN what is accepted; narrowing it
# again is a later, separate decision once the cutoff has moved past the last legacy commit.
COAUTHOR_LEGACY='^[[:space:]]*co-authored-by:[[:space:]]*nerdkim-sidekick[[:space:]]*<bot-sidekick@nerd\.kim>[[:space:]]*$'
# A generated signature in every form an AI tool writes it (D48): the "Generated with" line, a Claude
# co-author, the Anthropic noreply address, the Claude Code link that the signature carries even
# without its usual wording, and any other `<word>-by:` trailer naming Claude or Anthropic
# (Assisted-by, Generated-by, Signed-off-by). Prose that only mentions Claude Code still passes.
GENERATED='Generated with|Co-authored-by:[[:space:]]*Claude|noreply@anthropic\.com|claude\.com/claude-code|^[[:space:]]*[a-z]+(-[a-z]+)*-by:.*(claude|anthropic)'
# Claude Code appends a `Claude-Session: <url>` trailer to a commit, and the same claude.ai link to a
# pull request body, whenever the session runs on the web or under Remote Control (D36). It does so on
# top of the attribution text, so naming the sanctioned trailer does not keep it out; the settings turn
# it off with attribution.sessionUrl false (docs/22 s2). The trailer is matched only as a trailer line,
# so a message that mentions it in prose still passes, while a session URL is caught anywhere.
SESSION_LINK='^[[:space:]]*claude-session[[:space:]]*:|claude\.ai/code/session_'
# When the rule binds. It FAILs a message being written now (the hook) and, in a range, every commit
# whose own tree already carried the rule (the commit that installed this release and every later one)
# as well as every commit of a range whose base carries it, so a branch cut before the rule cannot bring
# the link into a branch that enforces it. Only a commit with neither, one written before the rule and
# checked against a base that predates it too, is an M8 advisory: docs/21 s4.3 does not rewrite history
# for a new rule, and the pull request that installs this release would otherwise be blocked by the
# commits sessions signed before it. SESSION_RULE_MARK is what a tree's copy of this file is searched for.
SESSION_RULE_MARK='session-link-rule:D36'
BASE_HAS_RULE=0
# session_rule_in_tree COMMIT -> 0 when the checker in COMMIT's tree carries the rule. Only a path that
# is really absent, or a copy without the mark, answers 1. A tree or blob git cannot read (a partial
# clone whose origin is gone, say) answers 0, so a broken read fails closed instead of excusing the link.
session_rule_in_tree() {
  local entry guard
  entry="$(git ls-tree "$1" -- harness/check-commit-messages.sh 2>/dev/null)" || return 0
  [ -n "$entry" ] || return 1
  guard="$(git show "$1:harness/check-commit-messages.sh" 2>/dev/null)" || return 0
  grep -qF "$SESSION_RULE_MARK" <<< "$guard"
}

# Conventional Commits (docs/12 s2.1). A trailing `!` marks a breaking change. A scope may
# name several areas separated by a comma (`fix(templates,docs): ...`).
CC_RE='^(feat|fix|chore|docs|refactor|test|perf|ci|build|style|revert|infra)(\([a-zA-Z0-9._/, -]+\))?!?: .+'

# Commit-author allowlist (M5): playbook_owner_re and playbook_is_owner in harness/lib.sh. Override
# with ALLOWED_AUTHOR_RE in a repo with more authors; in a public repository the same list also names
# whose commits are the owner's.

MODE="range"; RANGE=""; MSGFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --range)    MODE="range"; RANGE="$2"; shift 2 ;;
    --msg-file) MODE="single"; MSGFILE="$2"; shift 2 ;;
    --pr-text)  MODE="pr"; shift ;;
    -h|--help)  grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          # Every sibling checker takes a ROOT directory, so a bare `.` or a real path here is
                # almost certainly that habit rather than a commit range. Say so plainly instead of
                # failing later with a confusing "cannot resolve the commit range '.'".
                if [ "$1" = "." ] || [ "$1" = ".." ] || [ -d "$1" ]; then
                  echo "error: '$1' is a directory, not a commit range." >&2
                  echo "       This checker takes a range, unlike the other check-*.sh scripts:" >&2
                  echo "         bash $0                      # infer the range (CI event, else origin mainline)" >&2
                  echo "         bash $0 --range A..B          # explicit range" >&2
                  echo "         bash $0 --msg-file FILE       # one prepared message (hook mode)" >&2
                  exit 2
                fi
                if [ -z "$RANGE" ]; then RANGE="$1"; shift; else echo "unknown arg: $1" >&2; exit 2; fi ;;
  esac
done

STRICT=0
[ "${COMMITMSG_STRICT:-0}" = "1" ] && STRICT=1
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -f "$root/harness/commitmsg-strict" ] && STRICT=1

# ---- public repository ------------------------------------------------------
# With a valid harness/public-repo, M2/M5/M7/M8 run for allowlisted authors only. An unusable marker
# is a FAIL and leaves the mode OFF, so it can only ever make this gate stricter.
PUBLIC=0; PUBLIC_BAD=""; CONTRIB=0
_pstate="$(playbook_public_repo "$root")"
case "$_pstate" in
  on)    PUBLIC=1 ;;
  bad:*) PUBLIC_BAD="${_pstate#bad:}" ;;
esac

# is_contributor NAME EMAIL -> 0 when this commit is exempt from the owner-only rules: the repository
# is public, the author is known, and the author is not on the allowlist. An empty identity is not a
# contributor, so a commit whose author cannot be read keeps every rule.
is_contributor() {
  [ "$PUBLIC" -eq 1 ] || return 1
  [ -n "${1:-}${2:-}" ] || return 1
  ! playbook_is_owner "${1:-}" "${2:-}"
}

# ---- adoption cutoff -------------------------------------------------------
# `harness/commit-gate-since` bounds the old end of the range for the identity rules M2, M5, M7
# and M8; M1, M3, M4 and M6 still judge every commit in the range (see the header). Format: the first
# non-comment line is a sha or an ISO date, the second is the reason. The reason is MANDATORY,
# for the same reason `conventions-allow` requires one: a bare marker is the cheapest way to
# switch a rule off for an entire history, and a suppression nobody had to justify is one
# nobody reviews. The marker is committed, so weakening the gate appears in the diff.
CUTOFF=""; CUTOFF_KIND=""; CUTOFF_EPOCH=""; CUTOFF_BAD=""
if [ -f "$root/harness/commit-gate-since" ]; then
  _cl="$(grep -vE '^[[:space:]]*(#|$)' "$root/harness/commit-gate-since" 2>/dev/null || true)"
  _cval="$(printf '%s\n' "$_cl" | sed -n '1p' | tr -d '[:space:]')"
  _creason="$(printf '%s\n' "$_cl" | sed -n '2,$p' | tr -d '[:space:]')"
  if [ -z "$_cval" ]; then
    CUTOFF_BAD="harness/commit-gate-since is empty"
  elif [ "${#_creason}" -lt 10 ]; then
    CUTOFF_BAD="harness/commit-gate-since states no reason on the line after the cutoff (>= 10 characters required)"
  elif git rev-parse --verify -q "${_cval}^{commit}" >/dev/null 2>&1; then
    CUTOFF="$(git rev-parse --verify -q "${_cval}^{commit}")"; CUTOFF_KIND="sha"
  elif CUTOFF_EPOCH="$(date -u -d "$_cval" +%s 2>/dev/null)" && [ -n "$CUTOFF_EPOCH" ]; then
    CUTOFF="$_cval"; CUTOFF_KIND="date"
  else
    CUTOFF_BAD="harness/commit-gate-since holds '$_cval', which is neither a resolvable commit nor a date"
  fi
fi

# before_cutoff SHA -> 0 when the commit is at or before the cutoff (pre-adoption).
# An unresolvable comparison answers "not before", so an unreadable cutoff never widens the
# exemption; it only ever narrows it (fail-closed on scope, docs/20 s3).
before_cutoff() {
  [ -n "$CUTOFF" ] || return 1
  case "$CUTOFF_KIND" in
    sha)  git merge-base --is-ancestor "$1" "$CUTOFF" 2>/dev/null ;;
    date) local ct; ct="$(git log -1 --format=%ct "$1" 2>/dev/null || true)"
          [ -n "$ct" ] && [ "$ct" -le "$CUTOFF_EPOCH" ] ;;
    *)    return 1 ;;
  esac
}

FAIL=0; WARN=0
say() { printf '%s\n' "$*"; }

# report SEV LABEL DETAIL. A WARN becomes a FAIL under STRICT.
report() {
  local sev="$1" label="$2" detail="$3"
  [ "$sev" = "WARN" ] && [ "$STRICT" -eq 1 ] && sev="FAIL"
  say "  [$sev] $label"
  printf '%s\n' "$detail" | sed 's/^/    /'
  if [ "$sev" = "FAIL" ]; then FAIL=1; else WARN=1; fi
  return 0
}

# An advisory WARN that STRICT never promotes. Used where a mechanical gate would be
# unfaithful to the rule (see M6).
advise() {
  say "  [WARN] $1"
  printf '%s\n' "$2" | sed 's/^/    /'
  WARN=1
  return 0
}

# The comment character is configurable, and hardcoding `#` meant that under a non-default
# core.commentChar the `git commit -v` scissors line went unrecognised, so the whole diff below it
# was scanned as message text and blocked legitimate commits.
CC="$(git config core.commentChar 2>/dev/null || true)"
{ [ -n "$CC" ] && [ "$CC" != "auto" ]; } || CC='#'

# Two views of a prepared message, because the hook must not end up laxer than CI.
#   body_full : scissors diff removed, comments KEPT. Everything git will actually store.
#   body_clean: comments removed too. Used only for the subject-shape rules, so the commit
#               template's own comment lines cannot masquerade as a subject.
# The FAIL rules (M1, M2) run on body_full. Stripping comments for them was a real divergence:
# git keeps `#` lines for -m and -F (cleanup=whitespace), so the hook skipped text that CI then
# read straight out of %B and failed on.
strip_scissors() { awk -v c="$CC" 'index($0, c) == 1 && $0 ~ />8/ {exit} {print}'; }
strip_comments() { awk -v c="$CC" 'index($0, c) != 1'; }

# check_msg LABEL MSG_FULL MSG_CLEAN AUTHOR_NAME AUTHOR_EMAIL [PRE_ADOPTION] [SHA]
# MSG_FULL feeds the FAIL rules; MSG_CLEAN (comments removed) feeds the subject-shape rules.
# In range mode both are %B, which git has already cleaned.
# PRE_ADOPTION=1 marks a commit at or before the adoption cutoff: the identity rules M2, M5, M7 and
# M8 are skipped for it, and M1, M3, M4 and M6 still run. In a public repository a contributor commit
# is treated the same way.
# SHA names the commit in range mode. The hook passes none, so the message it is about to record is
# always held to the session link rule; in a range, BASE_HAS_RULE or the commit's own tree decides.
check_msg() {
  local label="$1" msg="$2" clean="$3" an="${4:-}" ae="${5:-}" pre="${6:-0}" sha="${7:-}"
  # id_rules: whether the identity rules (M2, M5, M7, M8) judge this commit.
  local id_rules=1
  if [ "$pre" = "1" ]; then
    id_rules=0
  elif is_contributor "$an" "$ae"; then
    id_rules=0; CONTRIB=$((CONTRIB + 1))
  fi

  # M5 runs FIRST, before the empty-message return below. Author identity is a property of the
  # commit, not of its text, so an empty message must not be a way to skip the allowlist.
  if [ "$id_rules" -eq 1 ] && [ -n "$an$ae" ] && ! playbook_is_owner "$an" "$ae"; then
    report WARN "$label M5 commit author outside the allowlist (docs/12 s2)" "$an <$ae>"
  fi

  [ -n "$(printf '%s' "$msg" | tr -d '[:space:]')" ] || return 0
  local subject hits
  subject="$(printf '%s\n' "$clean" | grep -vE '^[[:space:]]*$' | head -1)"

  # M1 forbidden unicode anywhere in the message.
  hits="$(printf '%s\n' "$msg" | grep -nP "$FORBIDDEN" || true)"
  [ -n "$hits" ] && report FAIL "$label M1 forbidden unicode in the commit message (docs/16 s2.1)" "$hits"

  # M2 / M8 every Co-Authored-By trailer must be the sanctioned identity. The superseded one is
  # accepted and reported (M8); anything else FAILs. Both patterns are anchored at each end, so
  # two trailers written onto one line cannot smuggle the second past the negative grep.
  if [ "$id_rules" -eq 1 ]; then
    local trailers legacy_hits
    trailers="$(printf '%s\n' "$msg" | grep -iE '^[[:space:]]*co-authored-by:' || true)"
    hits="$(printf '%s\n' "$trailers" | grep -v '^$' | grep -ivE "$COAUTHOR" | grep -ivE "$COAUTHOR_LEGACY" || true)"
    [ -n "$hits" ] && report FAIL "$label M2 unsanctioned co-author; only mikdren <bot-sidekick@nerd.kim> is allowed (docs/12 s2, D30)" "$hits"
    legacy_hits="$(printf '%s\n' "$trailers" | grep -v '^$' | grep -iE "$COAUTHOR_LEGACY" || true)"
    [ -n "$legacy_hits" ] && advise "$label M8 superseded co-author trailer; the sanctioned identity is now mikdren <bot-sidekick@nerd.kim> (docs/12 s2, D30, advisory)" "$legacy_hits"
    hits="$(printf '%s\n' "$msg" | grep -niE "$GENERATED" || true)"
    [ -n "$hits" ] && report FAIL "$label M2 generated signature in the commit message (docs/12 s2)" "$hits"
    hits="$(printf '%s\n' "$msg" | grep -niE "$SESSION_LINK" || true)"
    if [ -n "$hits" ]; then
      if [ -z "$sha" ] || [ "$BASE_HAS_RULE" -eq 1 ] || session_rule_in_tree "$sha"; then
        report FAIL "$label M2 Claude session link in the commit message; remove it and keep attribution.sessionUrl false (docs/12 s2, docs/22 s2)" "$hits"
      else
        advise "$label M8 Claude session link in a commit written before the rule, checked against a base without it (docs/12 s2, D36, advisory)" "$hits"
      fi
    fi
  fi

  # Subjects git generates itself are exempt from the shape rules. Matched in git's exact forms, so
  # a hand-written subject cannot claim the exemption just by starting with the word "Merge".
  # `Merge <head sha> into <base sha>` is the subject GitHub puts on the synthetic merge ref that
  # actions/checkout resolves for a pull_request event, so it is INSIDE `origin/<base>..HEAD` on
  # every PR run. It matched none of the arms below, which meant a repo with the strict ratchet on
  # (which the installer turns on automatically for a clean history, and which docs/21 s4.1 says a
  # new repo starts with) went red on every pull request for a commit no human wrote.
  case "$subject" in
    "Merge branch "*|"Merge branches "*|"Merge pull request "*|"Merge remote-tracking branch "*|\
    "Merge tag "*|"Merge commit "*|"Merge "*" into "*|Revert\ \"*|"Initial commit") return 0 ;;
  esac

  # M7 the sanctioned trailer must be PRESENT, not merely un-violated. docs/12 s2 states it as a
  # positive obligation and nothing enforced it: a commit with no trailer at all passed, including
  # under the strict ratchet. WARN by default so adoption is not blocked, promoted by
  # harness/commitmsg-strict. It runs after the exemptions above, because nobody can add a trailer
  # to a subject git generated. The legacy identity satisfies presence (M8 already names it).
  if [ "$id_rules" -eq 1 ]; then
    grep -qiE "$COAUTHOR|$COAUTHOR_LEGACY" <<< "$msg" \
      || report WARN "$label M7 no sanctioned co-author trailer; add Co-Authored-By: mikdren <bot-sidekick@nerd.kim> (docs/12 s2, D30)" "$subject"
  fi

  # M3 Conventional Commits subject.
  grep -qE "$CC_RE" <<< "$subject" \
    || report WARN "$label M3 subject is not Conventional Commits type(scope): subject (docs/12 s2.1)" "$subject"

  # M4 no trailing period on the subject.
  grep -qE '\.[[:space:]]*$' <<< "$subject" \
    && report WARN "$label M4 subject ends with a period (docs/16 s4.4)" "$subject"

  # M6 commits are English (docs/16 s4.1). Advisory only, and deliberately NOT promoted by
  # STRICT: a commit that changes a Korean-language rule must be able to quote the Korean form
  # it is changing (for example the honorific particle 께, or a Hangul term the rule renames),
  # so a hard gate here would be unfaithful to the rule it claims to enforce. Human review
  # decides; the checker only surfaces it.
  hits="$(printf '%s\n' "$clean" | grep -nP '[\x{AC00}-\x{D7A3}]' || true)"
  [ -n "$hits" ] && advise "$label M6 Hangul in the commit message; commits are English (docs/16 s4.1, advisory)" "$hits"
  return 0
}

# Resolve the commits to check. Explicit --range wins, then the CI event, then origin's
# mainline, and finally HEAD alone. An unresolvable range is reported, not silently passed
# as "nothing to check" (fail-closed on scope, docs/20 s3).
resolve_range() {
  local r="$1" before
  if [ -n "$r" ]; then printf '%s' "$r"; return 0; fi
  if [ -n "${GITHUB_BASE_REF:-}" ] && git rev-parse --verify -q "origin/$GITHUB_BASE_REF" >/dev/null 2>&1; then
    printf 'origin/%s..HEAD' "$GITHUB_BASE_REF"; return 0
  fi
  before="${GITHUB_EVENT_BEFORE:-}"
  if [ -n "$before" ] && ! grep -qE '^0+$' <<< "$before" \
     && git rev-parse --verify -q "$before" >/dev/null 2>&1; then
    printf '%s..HEAD' "$before"; return 0
  fi
  # main is the trunk of every repository (D44), so it wins even beside a master nobody deleted.
  # origin/master is TEMPORARY: it keeps the scope of a consumer that has not renamed master to
  # main yet, and it goes once every consumer has migrated.
  if git rev-parse --verify -q origin/main   >/dev/null 2>&1; then printf 'origin/main..HEAD';   return 0; fi
  if git rev-parse --verify -q origin/master >/dev/null 2>&1; then printf 'origin/master..HEAD'; return 0; fi
  printf '%s' "-1 HEAD"
}

# ---- pull request text (P1, D48) -------------------------------------------------
# A pull request title and body are the other text a session writes for the owner. Claude Code puts
# its signature and session link into a description unless attribution.pr is empty and
# attribution.sessionUrl false (docs/22 s2), and a squash merge would carry that text into a commit.
# CI passes the text in PR_TITLE and PR_BODY, never on the command line. The rule describes the
# owner's pull requests, so one opened by anyone else (a bot, an outside contributor) is skipped.
if [ "$MODE" = "pr" ]; then
  say "== check-commit-messages --pr-text (P1 = FAIL) =="
  if [ -n "${PR_AUTHOR:-}" ] && [ -n "${REPO_OWNER:-}" ] && [ "$PR_AUTHOR" != "$REPO_OWNER" ]; then
    say "  opened by $PR_AUTHOR, not the owner $REPO_OWNER: P1 not applied"
    exit 0
  fi
  text="$(printf '%s\n%s\n' "${PR_TITLE:-}" "${PR_BODY:-}")"
  hits="$(printf '%s\n' "$text" | grep -iE '^[[:space:]]*co-authored-by:' | grep -ivE "$COAUTHOR" | grep -ivE "$COAUTHOR_LEGACY" || true)"
  [ -n "$hits" ] && report FAIL "P1 co-author other than mikdren <bot-sidekick@nerd.kim> in the pull request text (docs/12 s2, D30)" "$hits"
  hits="$(printf '%s\n' "$text" | grep -niE "$GENERATED|$SESSION_LINK" || true)"
  [ -n "$hits" ] && report FAIL "P1 generated signature or Claude session link in the pull request title or body; edit the PR text (docs/12 s5.3, D48)" "$hits"
  [ "$FAIL" -eq 0 ] || exit 1
  say "  OK: the pull request text carries no co-author, signature or session link"
  exit 0
fi

say "== check-commit-messages (M1/M2 = FAIL, M3-M5/M7 = $( [ "$STRICT" -eq 1 ] && echo FAIL || echo WARN ), M6/M8 = advisory) =="
# A malformed cutoff is a FAIL, never a silent full-history exemption. The file exists to bound
# the gate, so an unreadable one must not be the thing that decides how much the gate checks.
if [ -n "$CUTOFF_BAD" ]; then
  say "  [FAIL] $CUTOFF_BAD"
  say "         Format: line 1 a commit sha or an ISO date, line 2 the reason it was set."
  FAIL=1
elif [ -n "$CUTOFF" ]; then
  say "  adoption cutoff: $CUTOFF_KIND $CUTOFF (M2, M5, M7 and M8 are not applied at or before it; M1, M3, M4 and M6 are)"
fi
# The public repository marker gets the same treatment as the cutoff: it narrows what the gate
# checks, so an unusable one FAILs and grants nothing, and a valid one is always announced.
if [ -n "$PUBLIC_BAD" ]; then
  say "  [FAIL] $PUBLIC_BAD; public repository mode is OFF, so every rule applies to every author"
  say "         Format: the first non-comment line of harness/public-repo states why the repository is public."
  FAIL=1
elif [ "$PUBLIC" -eq 1 ]; then
  say "  public repository (harness/public-repo): M2, M5, M7 and M8 apply to allowlisted authors only"
fi

if [ "$MODE" = "single" ]; then
  if [ -z "$MSGFILE" ] || [ ! -f "$MSGFILE" ]; then
    say "  no message file at ${MSGFILE:-<unset>}; nothing to check"; exit 0
  fi
  full="$(strip_scissors < "$MSGFILE")"
  # The identity the commit will be recorded under. `git var` sees GIT_AUTHOR_NAME and
  # GIT_AUTHOR_EMAIL as well as user.name and user.email, which is what CI later reads as %an/%ae.
  IFS=$'\t' read -r id_name id_email <<< "$(playbook_git_identity "$root")"
  check_msg "message:" "$full" "$(printf '%s\n' "$full" | strip_comments)" "${id_name:-}" "${id_email:-}"
  [ "$CONTRIB" -gt 0 ] && say "  contributor commit (M2, M5, M7 and M8 not applied): ${id_name:-} <${id_email:-}>"
else
  RANGE="$(resolve_range "$RANGE")"
  say "  range: $RANGE"
  # Merge commits are INCLUDED. `--no-merges` would make a merge commit's message unreachable, and
  # `git merge` runs the commit-msg hook, so a merge is exactly the message a `--no-verify` merge or
  # a title typed into the GitHub merge box would smuggle past. The subject-shape rules already
  # exempt git's own merge subjects, so including them costs nothing and closes the hole.
  # shellcheck disable=SC2086  # RANGE may legitimately be "-1 HEAD" (single-commit fallback)
  if ! shas="$(git rev-list $RANGE 2>/dev/null)"; then
    # Losing scope is itself a fail-open: checking HEAD alone while reporting success would let
    # every earlier commit in the push through unexamined. Say so and fail, rather than pass on a
    # verification that did not happen.
    say "  [FAIL] cannot resolve the commit range '$RANGE'."
    say "         A shallow clone cannot see it: use actions/checkout with fetch-depth: 0."
    say "         Refusing to report a pass over commits that were never read."
    exit 1
  fi
  # A range `A..B` or `A...B` whose base A already enforces the session link rule binds every commit in
  # it, wherever the commit was written. Without `..` there is no base, and only each tree decides.
  case "$RANGE" in
    *..*) range_base="${RANGE%%..*}"
          if [ -n "$range_base" ] && session_rule_in_tree "$range_base"; then BASE_HAS_RULE=1; fi ;;
  esac
  n=0; skipped=0
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    n=$((n + 1))
    pre=0
    if before_cutoff "$sha"; then pre=1; skipped=$((skipped + 1)); fi
    body="$(git log -1 --format=%B "$sha")"
    check_msg "$(printf '%.10s' "$sha"):" "$body" "$body" \
      "$(git log -1 --format=%an "$sha")" \
      "$(git log -1 --format=%ae "$sha")" "$pre" "$sha"
  done <<< "$shas"
  say "  commits checked: $n"
  # Always print what the cutoff removed from scope. A bound nobody can see is a bound nobody
  # reviews, which is how an adoption aid becomes a permanent blanket exemption.
  [ "$skipped" -gt 0 ] && say "  pre-adoption commits (M2, M5, M7 and M8 not applied): $skipped"
  # The same for the public repository split: the number of commits judged as a contributor's.
  [ "$CONTRIB" -gt 0 ] && say "  contributor commits (M2, M5, M7 and M8 not applied): $CONTRIB"
fi

say ""
if [ "$FAIL" -eq 1 ]; then
  say "RESULT: FAIL (commit message conventions). Rewrite the offending messages:"
  say "  tip commit: git commit --amend    earlier: git rebase -i <base> and reword"
  exit 1
fi
if [ "$WARN" -eq 1 ]; then
  say "RESULT: PASS with warnings (promote to FAIL with harness/commitmsg-strict or COMMITMSG_STRICT=1)."
  exit 0
fi
say "RESULT: PASS (commit message conventions)."
exit 0
