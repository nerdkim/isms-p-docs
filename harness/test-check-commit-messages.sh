#!/usr/bin/env bash
# test-check-commit-messages.sh - self-test for the commit-message backstop (docs/00 D6).
#
# Builds throwaway git repos and writes real commits with `--no-verify`, so the local hook
# is bypassed exactly the way an evading commit would bypass it, then asserts the checker's
# exit code in range mode. That is the property that matters: a message that slipped past
# the hook must still fail in CI. Single-message mode (the hook path) is covered too.
#
# 0 = PASS (or PASS with warnings), 1 = FAIL.
set -uo pipefail
CHK="$(cd "$(dirname "$0")" && pwd)/check-commit-messages.sh"
# Every fixture lives under one work root that the EXIT trap removes, so a failing or interrupted
# run leaves nothing behind either (bash runs the EXIT trap on TERM, INT and HUP as well).
WORK="$(mktemp -d)" || { echo "mktemp -d failed" >&2; exit 2; }
tmp=""; cleanup() { rm -rf -- "$WORK"; }; trap cleanup EXIT
fails=0
# An author identity inherited from the environment would override every fixture's own, and the
# owner and contributor cases below are decided by exactly that identity.
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

# An em dash (U+2014) assembled from bytes, so this test file carries no forbidden literal
# and passes check-conventions[1] like every other file.
EMDASH="$(printf '\xe2\x80\x94')"

# A repo with one clean base commit. Identity is set locally so the M5 allowlist behaves
# deterministically regardless of the machine's git config.
mkrepo() {
  # Remove the PREVIOUS fixture before claiming a new one, so the work root holds one at a time.
  [ -n "$tmp" ] && rm -rf "$tmp"
  tmp="$(mktemp -d "$WORK/repo.XXXXXX")"
  (
    cd "$tmp" || exit 1
    git init -q -b main
    git config user.name  nerdkim
    git config user.email me@nerd.kim
    git config commit.gpgsign false
    printf 'base\n' > base.txt
    git add base.txt
    git commit -q --no-verify -m "chore(init): add base"
  )
}

strict_on() { mkdir -p "$tmp/harness"; : > "$tmp/harness/commitmsg-strict"; }

# The sanctioned identity (docs/12 s2, D30) and the one it supersedes.
TRAILER='Co-Authored-By: mikdren <bot-sidekick@nerd.kim>'
TRAILER_LEGACY='Co-Authored-By: nerdkim-sidekick <bot-sidekick@nerd.kim>'

# commit MESSAGE -> one more commit carrying MESSAGE, hook bypassed.
# A message naming no co-author gets the sanctioned trailer appended, so a case written to
# exercise some OTHER rule does not also trip M7 (trailer presence). A case that means to test
# the trailer supplies its own and is left alone.
commit() {
  local msg="$1" n
  n="$RANDOM$RANDOM"
  case "$msg" in *[Cc]o-[Aa]uthored-[Bb]y:*) ;; *) msg="$msg

$TRAILER" ;; esac
  commit_raw "$msg"
}

# commit_raw MESSAGE -> the same, with NOTHING appended. Used by the M7 cases, which are the
# only ones that need a message carrying no trailer at all.
commit_raw() {
  local msg="$1" n
  n="$RANDOM$RANDOM"
  (
    cd "$tmp" || exit 1
    printf '%s\n' "$n" > "f$n.txt"
    git add "f$n.txt"
    printf '%s' "$msg" | git commit -q --no-verify -F -
  )
}

rc() { ( cd "$tmp" && bash "$CHK" --range "$1" >/dev/null 2>&1 ); echo $?; }
expect() { # label range expected-rc
  local got; got="$(rc "$2")"
  if [ "$got" = "$3" ]; then echo "  PASS $1 (rc=$got)"; else echo "  FAIL $1 (rc=$got, expected $3)"; fails=1; fi
}
# expect_says LABEL RANGE EXPECTED_RC SUBSTRING - the exit code AND a line of the report.
expect_says() {
  local got out
  out="$( cd "$tmp" && bash "$CHK" --range "$2" 2>&1 )"; got=$?
  if [ "$got" = "$3" ] && grep -qF -- "$4" <<< "$out"; then
    echo "  PASS $1 (rc=$got)"
  else
    echo "  FAIL $1 (rc=$got, expected $3, wanted \"$4\")"; fails=1
  fi
}

# commit_as NAME EMAIL MESSAGE -> one more commit AUTHORED by NAME <EMAIL>, nothing appended. The
# public repository cases are decided by the author, so they name it explicitly.
commit_as() {
  local an="$1" ae="$2" msg="$3" n
  n="$RANDOM$RANDOM"
  (
    cd "$tmp" || exit 1
    printf '%s\n' "$n" > "f$n.txt"
    git add "f$n.txt"
    printf '%s' "$msg" | git -c user.name="$an" -c user.email="$ae" commit -q --no-verify -F -
  )
}
# public_on [REASON] - mark the fixture as a public repository. An empty REASON writes a marker with
# no reason line, which the checker must refuse.
public_on() {
  mkdir -p "$tmp/harness"
  printf '%s\n' '# public repository marker (test fixture)' "${1-outside contributors commit to this repository}" \
    > "$tmp/harness/public-repo"
}
CONTRIB_NAME='Jane Contributor'; CONTRIB_EMAIL='jane@example.com'
CLAUDE_TRAILER='Co-Authored-By: Claude <noreply@anthropic.com>'
# The trailer a web or Remote Control session appends (D36), with a made-up session id.
SESSION_URL='https://claude.ai/code/session_01ExampleFixture000000000'
SESSION_TRAILER="Claude-Session: $SESSION_URL"
# adopt_rule - commit this checker into the fixture as an install of this release would, so every later
# commit is written in a tree whose own guard carries the session link rule. Before it, the rule is an
# M8 advisory in range mode.
adopt_rule() {
  mkdir -p "$tmp/harness"
  cp "$CHK" "$tmp/harness/check-commit-messages.sh"
  (
    cd "$tmp" || exit 1
    git add harness/check-commit-messages.sh
    printf 'chore(harness): adopt the session link rule\n\n%s\n' "$TRAILER" | git commit -q --no-verify -F -
  )
}

echo "== test-check-commit-messages =="

# --- range mode: the CI backstop ---------------------------------------------
mkrepo; commit "feat(harness): add a gate"
expect "conventional subject -> PASS" "HEAD~1..HEAD" 0

mkrepo; commit "feat(x): a ${EMDASH} b"
expect "forbidden unicode in subject -> FAIL" "HEAD~1..HEAD" 1

mkrepo; commit "$(printf 'feat(x): ok\n\nbody with a %s dash\n' "$EMDASH")"
expect "forbidden unicode in body -> FAIL" "HEAD~1..HEAD" 1

mkrepo; commit "$(printf 'feat(x): ok\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n')"
expect "unsanctioned co-author -> FAIL" "HEAD~1..HEAD" 1

mkrepo; commit "$(printf 'feat(x): ok\n\n%s\n' "$TRAILER")"
expect "sanctioned co-author -> PASS" "HEAD~1..HEAD" 0

# D30 renamed the sanctioned identity. A release that changes an identity may only WIDEN what is
# accepted: this repository alone carries the superseded trailer on 39 commits and every already
# adopted project carries it too, and M2 runs over the whole pull request range, so a hard swap
# would turn every historical sanctioned commit into a merge blocker. The superseded form is
# therefore an advisory (M8) that STRICT never promotes.
mkrepo; commit "$(printf 'feat(x): ok\n\n%s\n' "$TRAILER_LEGACY")"
expect "superseded co-author -> PASS (advisory M8)" "HEAD~1..HEAD" 0

mkrepo; strict_on; commit "$(printf 'feat(x): ok\n\n%s\n' "$TRAILER_LEGACY")"
expect "superseded co-author under strict -> still PASS (M8 is never promoted)" "HEAD~1..HEAD" 0

mkrepo; commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER_LEGACY" "$TRAILER")"
expect "both the superseded and the sanctioned trailer -> PASS" "HEAD~1..HEAD" 0

# M7: the trailer is a positive obligation (docs/12 s2) and nothing used to require it, so a
# commit with no trailer at all passed even under the strict ratchet.
mkrepo; commit_raw "feat(x): no trailer at all"
expect "no co-author trailer -> WARN only, PASS" "HEAD~1..HEAD" 0

mkrepo; strict_on; commit_raw "feat(x): no trailer at all"
expect "no co-author trailer under strict -> FAIL (M7)" "HEAD~1..HEAD" 1

mkrepo; commit "$(printf 'feat(x): ok\n\nGenerated with some tool\n')"
expect "generated signature -> FAIL" "HEAD~1..HEAD" 1

mkrepo; commit "made some changes"
expect "non-conventional subject -> WARN only, PASS" "HEAD~1..HEAD" 0

mkrepo; strict_on; commit "made some changes"
expect "non-conventional subject under commitmsg-strict -> FAIL" "HEAD~1..HEAD" 1

mkrepo; strict_on; commit "feat(x): trailing period."
expect "trailing period under strict -> FAIL" "HEAD~1..HEAD" 1

# M6 is advisory on purpose: a commit that changes a Korean-language rule must be able to
# quote the Korean form it changes, so STRICT must NOT promote it to a FAIL.
mkrepo; strict_on; commit "feat(x): add a Korean word 기능"
expect "Hangul stays advisory even under strict -> PASS" "HEAD~1..HEAD" 0

mkrepo; commit "feat(x): add a Korean word 기능"
expect "Hangul without strict -> WARN only, PASS" "HEAD~1..HEAD" 0

# A merge commit subject is generated by git, so the subject-shape rules must not fire on it.
# Note the range: past a merge, HEAD~3 does not resolve (HEAD~n follows first parent only), and an
# unresolvable range is a hard failure rather than a silent HEAD-only pass.
mkmerge() { # MERGE_SUBJECT [adopt]
  mkrepo; strict_on
  [ "${2:-}" = adopt ] && adopt_rule
  (
    cd "$tmp" || exit 1
    git checkout -q -b side
    printf 'side\n' > side.txt; git add side.txt
    printf 'feat(side): add side\n\n%s\n' "$TRAILER" | git commit -q --no-verify -F -
    git checkout -q main
    printf 'main\n' > main.txt; git add main.txt
    printf 'feat(main): add main\n\n%s\n' "$TRAILER" | git commit -q --no-verify -F -
    git merge -q --no-ff -m "$1" side >/dev/null 2>&1
  )
}
mkmerge "Merge branch 'side' into main"
expect "merge commit exempt from subject shape -> PASS" "HEAD~2..HEAD" 0

# But a merge commit's message is still read for the FAIL rules. `--no-merges` used to make merge
# messages unreachable, so a merge was the one message that could carry anything at all.
mkmerge "$(printf "Merge branch 'side' into main\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n")"
expect "merge commit carrying an unsanctioned co-author -> FAIL" "HEAD~2..HEAD" 1

mkmerge "Merge branch 'side' with a ${EMDASH} dash"
expect "merge commit carrying forbidden unicode -> FAIL" "HEAD~2..HEAD" 1

# The git-generated exemption must be claimable only in git's own subject forms, not by any subject
# that merely starts with the word Merge.
mkrepo; strict_on; commit "Merge the config files together"
expect "hand-written subject starting with Merge is NOT exempt -> FAIL" "HEAD~1..HEAD" 1

mkrepo; strict_on; commit "Revert something informally"
expect "hand-written subject starting with Revert is NOT exempt -> FAIL" "HEAD~1..HEAD" 1

# A second co-author smuggled onto the same line as the sanctioned trailer must not pass.
mkrepo
commit "$(printf 'feat(x): ok\n\nCo-Authored-By: Claude <x@y.z> %s\n' "$TRAILER")"
expect "two co-authors on one line -> FAIL" "HEAD~1..HEAD" 1

# A lowercase generated signature must be caught like the capitalised one.
mkrepo; commit "$(printf 'feat(x): ok\n\ngenerated with some tool\n')"
expect "lowercase generated signature -> FAIL" "HEAD~1..HEAD" 1

# D48: the signature in its other forms. A prose mention of Claude Code is not a signature.
mkrepo; commit "$(printf 'feat(x): ok\n\nAssisted-by: Claude Code\n')"
expect_says "an Assisted-by trailer naming Claude -> FAIL (M2)" "HEAD~1..HEAD" 1 " M2 generated signature"

mkrepo; commit "$(printf 'feat(x): ok\n\nSee [Claude Code](https://claude.com/claude-code)\n')"
expect "the Claude Code link without the usual wording -> FAIL (M2)" "HEAD~1..HEAD" 1

mkrepo; strict_on; commit "$(printf 'docs(x): describe the Claude Code attribution setting\n\nClaude Code reads its attribution from the settings.\n')"
expect "prose that only mentions Claude Code under strict -> PASS" "HEAD~1..HEAD" 0

# D36: a web or Remote Control session adds `Claude-Session: <url>` beside the sanctioned trailer, so
# the sanctioned trailer being present must not let it through. A prose mention of the trailer is fine.
mkrepo; adopt_rule; commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
expect_says "Claude-Session trailer beside the sanctioned one -> FAIL (M2)" "HEAD~1..HEAD" 1 " M2 Claude session link"

mkrepo; adopt_rule; commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER" 'claude-session:https://example.invalid/s/1')"
expect "lowercase claude-session trailer with another URL and no space -> FAIL" "HEAD~1..HEAD" 1

mkrepo; adopt_rule; commit "$(printf 'feat(x): ok\n\nWritten in %s\n' "$SESSION_URL")"
expect "a claude.ai session URL anywhere in the body -> FAIL" "HEAD~1..HEAD" 1

mkrepo; strict_on; adopt_rule
commit "$(printf 'feat(harness): reject the Claude-Session trailer\n\nThe Claude-Session trailer names the session.\n')"
expect "the trailer named in prose under strict -> PASS" "HEAD~1..HEAD" 0

# Only a trailer at the start of a line is the trailer; quoting its key mid-line is prose.
mkrepo; strict_on; adopt_rule
commit "$(printf 'feat(harness): reject the Claude-Session: trailer\n\nDrop any line that starts with Claude-Session: from the message.\n')"
expect "the trailer key quoted mid-line under strict -> PASS" "HEAD~1..HEAD" 0

mkmerge "$(printf "Merge branch 'side' into main\n\n%s\n" "$SESSION_TRAILER")" adopt
expect "merge commit carrying a Claude-Session trailer -> FAIL" "HEAD~2..HEAD" 1

# docs/21 s4.3 does not rewrite history for a new rule. A commit written before the rule reached the
# repository's own tree is reported, never failed, even under strict; the commit that installs the rule
# and every later one are held to it.
mkrepo; strict_on; commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
expect_says "Claude-Session trailer written before the rule reached the tree -> PASS (advisory M8)" "HEAD~1..HEAD" 0 \
  " M8 Claude session link in a commit written before the rule"

mkrepo; commit "$(printf 'feat(old): before the rule\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
adopt_rule; commit "feat(new): after the rule"
expect "an old trailer below the adoption commit in the same range -> PASS" "HEAD~3..HEAD" 0
commit "$(printf 'feat(newer): signed again\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
expect "the same trailer once the rule is in the tree -> FAIL" "HEAD~4..HEAD" 1

# The common real input: the tree holds an older checker that predates the rule, so "before the rule"
# must be read through the mark, not only through a missing file.
mkrepo; mkdir -p "$tmp/harness"
grep -v '^SESSION_RULE_MARK=' "$CHK" > "$tmp/harness/check-commit-messages.sh"
(
  cd "$tmp" || exit 1
  git add harness/check-commit-messages.sh
  printf 'chore(harness): install an older checker\n\n%s\n' "$TRAILER" | git commit -q --no-verify -F -
)
commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
expect_says "a tree holding an older checker without the rule -> PASS (advisory M8)" "HEAD~1..HEAD" 0 " M8 Claude session link"

# A branch cut before the rule cannot bring the link in afterwards: its commits are new to a base that
# enforces the rule, so the base binds them whatever their own tree says.
mkrepo
( cd "$tmp" && git checkout -q -b stale && git checkout -q main )
adopt_rule
( cd "$tmp" && git checkout -q stale )
commit "$(printf 'feat(x): signed on a stale branch\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
expect "a stale branch's link against a base that has the rule -> FAIL" "main..stale" 1
expect "the same commit against a base without the rule -> PASS (advisory M8)" "main~1..stale" 0

# A checker blob git cannot read must not excuse the link: the read fails closed.
mkrepo; adopt_rule
commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
blob="$( cd "$tmp" && git rev-parse HEAD:harness/check-commit-messages.sh )"
rm -f "$tmp/.git/objects/${blob:0:2}/${blob:2}"
expect "an unreadable checker blob in the tree -> FAIL (fails closed)" "HEAD~1..HEAD" 1

# Losing range scope must fail, not silently degrade to checking HEAD alone.
mkrepo; commit "feat(x): ok"
expect "unresolvable range -> FAIL (never a silent HEAD-only pass)" "nosuchref..HEAD" 1

# With no --range and no CI event, the range falls back to origin's trunk. main is the trunk of
# every repository (D44), so it wins over a master that was never deleted. origin/master alone still
# resolves, but only so that a consumer which has not renamed it yet keeps its scope (temporary).
fallback_says() { # LABEL SUBSTRING - run with no range and no CI event; the report must name SUBSTRING
  local out
  out="$( cd "$tmp" && env -u GITHUB_BASE_REF -u GITHUB_EVENT_BEFORE bash "$CHK" 2>&1 )"
  if grep -qF -- "$2" <<< "$out"; then echo "  PASS $1"
  else echo "  FAIL $1 (the report does not say \"$2\")"; fails=1; fi
}
mkrepo; commit "feat(x): ok"
( cd "$tmp" && git update-ref refs/remotes/origin/master HEAD~1 && git update-ref refs/remotes/origin/main HEAD~1 )
fallback_says "no range: origin/main is the trunk even beside a leftover origin/master" "range: origin/main..HEAD"
mkrepo; commit "feat(x): ok"
( cd "$tmp" && git update-ref refs/remotes/origin/master HEAD~1 )
fallback_says "no range: origin/master alone still resolves until the rename (temporary)" "range: origin/master..HEAD"

# One bad commit anywhere in a range must fail the whole range.
mkrepo
commit "feat(a): fine"
commit "feat(b): bad ${EMDASH} here"
commit "feat(c): fine"
expect "one bad commit inside a 3-commit range -> FAIL" "HEAD~3..HEAD" 1

# GitHub's synthetic pull-request merge ref carries the subject `Merge <head sha> into <base sha>`,
# and actions/checkout resolves HEAD to it on a pull_request event, so it sits INSIDE
# `origin/<base>..HEAD` on every PR run. It matched none of git's own merge forms, so a repo with
# the strict ratchet on (which the installer turns on for a clean history) went red on every pull
# request for a commit no human wrote.
mkrepo; strict_on
commit_raw "Merge 8f9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a into 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b"
expect "GitHub PR merge-ref subject under strict -> PASS" "HEAD~1..HEAD" 0

# --- adoption cutoff (harness/commit-gate-since) ------------------------------
# A brownfield repo is judged on the identity of the commits it writes after adoption, not of
# everything it ever wrote. The cutoff bounds the identity rules M2, M5, M7 and M8 only; M1 and the
# shape rules M3 and M4 judge every commit in the range.
cutoff() { mkdir -p "$tmp/harness"; printf '%s\n%s\n' "$1" "${2-adopted the standard on this commit}" > "$tmp/harness/commit-gate-since"; }

mkrepo
commit "$(printf 'feat(old): pre-adoption\n\nCo-Authored-By: Someone Else <x@y.z>\n')"
cut_sha="$( cd "$tmp" && git rev-parse HEAD )"
commit "feat(new): post-adoption"
cutoff "$cut_sha"
expect "unsanctioned co-author BEFORE the cutoff -> PASS" "HEAD~2..HEAD" 0

mkrepo
commit "feat(old): pre-adoption"
cut_sha="$( cd "$tmp" && git rev-parse HEAD )"
commit "$(printf 'feat(new): post-adoption\n\nCo-Authored-By: Someone Else <x@y.z>\n')"
cutoff "$cut_sha"
expect "unsanctioned co-author AFTER the cutoff -> FAIL" "HEAD~2..HEAD" 1

# M1 is deliberately outside the cutoff: a forbidden character in an old message is still a
# defect worth naming, and the range is bounded by the base ref anyway.
mkrepo
commit "feat(old): pre-adoption ${EMDASH} dash"
cut_sha="$( cd "$tmp" && git rev-parse HEAD )"
commit "feat(new): clean"
cutoff "$cut_sha"
expect "forbidden unicode BEFORE the cutoff is still caught -> FAIL" "HEAD~2..HEAD" 1

# The shape rules are not bounded either (harness/install.sh probes the real history the same way).
# A repository that turned strict on by hand while a release range still reached such a commit
# failed its release PR, because the report claimed the cutoff skipped "M2 to M8".
mkrepo; strict_on
commit "made some changes before adoption"
cut_sha="$( cd "$tmp" && git rev-parse HEAD )"
commit "feat(new): post-adoption"
cutoff "$cut_sha"
expect_says "non-conventional subject BEFORE the cutoff under strict -> FAIL (M3 is not bounded)" "HEAD~2..HEAD" 1 \
  "M3 subject is not Conventional Commits"

# The report names exactly the rules the cutoff skips.
mkrepo
commit "feat(old): pre-adoption"
cut_sha="$( cd "$tmp" && git rev-parse HEAD )"
commit "feat(new): post-adoption"
cutoff "$cut_sha"
out="$( cd "$tmp" && bash "$CHK" --range HEAD~2..HEAD 2>&1 )"; got=$?
if [ "$got" = 0 ] && grep -qF "pre-adoption commits (M2, M5, M7 and M8 not applied): 1" <<< "$out" \
   && grep -qF "M1, M3, M4 and M6 are)" <<< "$out" && ! grep -qF "M2 to M8" <<< "$out"; then
  echo "  PASS the cutoff report names the identity rules it skips and the rules it keeps (rc=$got)"
else
  echo "  FAIL the cutoff report names the identity rules it skips and the rules it keeps (rc=$got)"; fails=1
fi

# The cutoff is the cheapest way to switch the identity rules off across a whole history, so it defends
# itself the way conventions-allow does: no stated reason suppresses nothing, and an
# unresolvable value is a failure rather than a silent full-history exemption.
mkrepo; commit "feat(x): ok"; cutoff "$( cd "$tmp" && git rev-parse HEAD )" ""
expect "cutoff with no stated reason -> FAIL" "HEAD~1..HEAD" 1

mkrepo; commit "feat(x): ok"; cutoff "not-a-sha-or-a-date"
expect "cutoff that resolves to nothing -> FAIL" "HEAD~1..HEAD" 1

# --- public repository (harness/public-repo) --------------------------------
# Outside contributors commit to a public repository. The identity rules M2, M5, M7 and M8 describe
# the OWNER's commits, so they must neither fail nor warn on anybody else's, while M1 and the shape
# rules keep applying to everyone. Every case runs under the strict ratchet, so a rule that still
# fired on a contributor would show up as a FAIL rather than hide as a warning.
mkrepo; strict_on; public_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(x): add a thing\n\n%s\n' "$CLAUDE_TRAILER")"
expect_says "public: a contributor's own co-author trailer -> PASS (M2 not applied)" "HEAD~1..HEAD" 0 \
  "contributor commits (M2, M5, M7 and M8 not applied): 1"

mkrepo; strict_on; public_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(x): add a thing\n\nGenerated with some tool\n')"
expect "public: a contributor's generated signature -> PASS (M2 not applied)" "HEAD~1..HEAD" 0

mkrepo; strict_on; public_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "feat(x): no trailer at all"
out="$( cd "$tmp" && bash "$CHK" --range HEAD~1..HEAD 2>&1 )"; got=$?
if [ "$got" = 0 ] && ! grep -qE '\] [0-9a-f]+: M[578] ' <<< "$out"; then
  echo "  PASS public: a contributor commit without the owner's trailer -> PASS, no M5/M7/M8 line (rc=$got)"
else
  echo "  FAIL public: a contributor commit without the owner's trailer (rc=$got, or an M5/M7/M8 line was printed)"; fails=1
fi

mkrepo; strict_on; public_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "made some changes"
expect "public: a contributor's non-conventional subject under strict -> FAIL (M3 applies to everyone)" "HEAD~1..HEAD" 1

mkrepo; strict_on; public_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "feat(x): trailing period."
expect "public: a contributor's trailing period under strict -> FAIL (M4 applies to everyone)" "HEAD~1..HEAD" 1

mkrepo; public_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "feat(x): a ${EMDASH} b"
expect "public: forbidden unicode in a contributor's message -> FAIL (M1 applies to everyone)" "HEAD~1..HEAD" 1

# The owner's own commits keep every rule in a public repository.
mkrepo; strict_on; public_on
commit "$(printf 'feat(x): ok\n\n%s\n' "$CLAUDE_TRAILER")"
expect "public: the owner's commit with another co-author -> FAIL (M2)" "HEAD~1..HEAD" 1

mkrepo; strict_on; public_on
commit "$(printf 'feat(x): ok\n\nGenerated with some tool\n')"
expect "public: the owner's commit with a generated signature -> FAIL (M2)" "HEAD~1..HEAD" 1

mkrepo; strict_on; public_on; adopt_rule
commit "$(printf 'feat(x): ok\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER")"
expect "public: the owner's commit with a Claude-Session trailer -> FAIL (M2)" "HEAD~1..HEAD" 1

mkrepo; strict_on; public_on; adopt_rule
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(x): add a thing\n\n%s\n' "$SESSION_TRAILER")"
expect "public: a contributor's Claude-Session trailer -> PASS (M2 not applied)" "HEAD~1..HEAD" 0

mkrepo; strict_on; public_on; commit_raw "feat(x): no trailer at all"
expect "public: the owner's commit without the trailer under strict -> FAIL (M7)" "HEAD~1..HEAD" 1

mkrepo; strict_on; public_on; commit "$(printf 'feat(x): ok\n\n%s\n' "$TRAILER_LEGACY")"
expect_says "public: the owner's superseded trailer -> PASS with the M8 advisory" "HEAD~1..HEAD" 0 " M8 superseded co-author"

# The split follows the allowlist M5 uses, so a contributor who writes the owner's name gets the
# owner's rules: claiming the identity can only add rules, never remove one.
mkrepo; strict_on; public_on
commit_as nerdkim nerdkim@example.com "$(printf 'feat(x): ok\n\n%s\n' "$CLAUDE_TRAILER")"
expect "public: a commit claiming the owner's name is judged as the owner's -> FAIL (M2)" "HEAD~1..HEAD" 1

# Commits are classified one by one, across a range that mixes both.
mkrepo; strict_on; public_on
commit "feat(a): the owner's commit"
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(b): a contribution\n\n%s\n' "$CLAUDE_TRAILER")"
expect_says "public: a compliant owner commit beside a contribution -> PASS" "HEAD~2..HEAD" 0 \
  "contributor commits (M2, M5, M7 and M8 not applied): 1"

mkrepo; strict_on; public_on
commit "$(printf 'feat(a): the owner smuggles a co-author\n\n%s\n' "$CLAUDE_TRAILER")"
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "feat(b): a contribution"
expect "public: an owner commit with another co-author beside a contribution -> FAIL" "HEAD~2..HEAD" 1

# GitHub authors the synthetic pull request merge commit itself (noreply@github.com, allowlisted),
# so it is judged as the owner's and its generated subject stays exempt from the shape rules.
mkrepo; strict_on; public_on
commit_as GitHub noreply@github.com "Merge 8f9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a into 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b"
expect "public: GitHub's pull request merge-ref commit under strict -> PASS" "HEAD~1..HEAD" 0

# The adoption cutoff still bounds the range in a public repository.
mkrepo; strict_on; public_on
commit "$(printf 'feat(old): pre-adoption\n\n%s\n' "$CLAUDE_TRAILER")"
cutoff "$( cd "$tmp" && git rev-parse HEAD )"
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "feat(new): a contribution"
expect "public: an owner commit BEFORE the cutoff beside a contribution -> PASS" "HEAD~2..HEAD" 0

# Without the marker nothing changes: the identity rules judge every author, as before.
mkrepo
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(x): add a thing\n\n%s\n' "$CLAUDE_TRAILER")"
expect "private: a non-owner's other co-author -> FAIL (M2 applies to everyone)" "HEAD~1..HEAD" 1

mkrepo; strict_on
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(x): add a thing\n\n%s\n' "$TRAILER")"
expect "private: a non-owner author under strict -> FAIL (M5)" "HEAD~1..HEAD" 1

# The marker narrows the gate, so it defends itself like the cutoff: no stated reason, or a marker
# that is not a regular file, FAILs and grants nothing.
mkrepo; public_on ""
commit "feat(x): a clean owner commit"
expect_says "public marker with no reason line -> FAIL" "HEAD~1..HEAD" 1 "harness/public-repo states no reason"

mkrepo; public_on "short"
commit_as "$CONTRIB_NAME" "$CONTRIB_EMAIL" "$(printf 'feat(x): add a thing\n\n%s\n' "$CLAUDE_TRAILER")"
expect_says "public marker with a too-short reason grants nothing -> FAIL (M2 applies)" "HEAD~1..HEAD" 1 " M2 unsanctioned co-author"

mkrepo; mkdir -p "$tmp/harness/public-repo"
commit "feat(x): a clean owner commit"
expect "public marker that is a directory -> FAIL" "HEAD~1..HEAD" 1

# --- single-message mode: the hook path ---------------------------------------
mkrepo
msgf="$tmp/msg.txt"
single() { ( cd "$tmp" && bash "$CHK" --msg-file "$msgf" >/dev/null 2>&1 ); echo $?; }
expect_single() { # label expected-rc
  local got; got="$(single)"
  if [ "$got" = "$2" ]; then echo "  PASS $1 (rc=$got)"; else echo "  FAIL $1 (rc=$got, expected $2)"; fails=1; fi
}

printf 'feat(harness): add a gate\n\n%s\n' "$TRAILER" > "$msgf"
expect_single "single mode clean message -> PASS" 0

printf 'feat(harness): a %s b\n' "$EMDASH" > "$msgf"
expect_single "single mode forbidden unicode -> FAIL" 1

printf 'feat(harness): ok\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' > "$msgf"
expect_single "single mode unsanctioned co-author -> FAIL" 1

# The hook is where Claude Code's own commit meets the rule first, so it must refuse the trailer too.
printf 'feat(harness): ok\n\n%s\n%s\n' "$TRAILER" "$SESSION_TRAILER" > "$msgf"
expect_single "single mode Claude-Session trailer -> FAIL" 1

# The `git commit -v` scissors diff must be ignored: a forbidden char below the scissors
# line comes from the diff, not from the message.
printf 'feat(harness): clean subject\n# ------------------------ >8 ------------------------\ndiff has a %s dash\n' "$EMDASH" > "$msgf"
expect_single "single mode ignores the scissors diff -> PASS" 0

printf '# only comments\n' > "$msgf"
expect_single "single mode comment-only message -> PASS" 0

# The hook must not be laxer than CI. git keeps `#` lines for -m and -F (cleanup=whitespace), so a
# forbidden character on such a line IS stored in the message and CI reads it back out of %B.
# Stripping comments before the FAIL rules made the hook pass what CI then failed.
printf 'feat(harness): clean subject\n\n# note: a %s dash lives here\n' "$EMDASH" > "$msgf"
expect_single "forbidden unicode on a comment line is still caught -> FAIL" 1

# But the template's own comment lines must not be read as the subject.
mkdir -p "$tmp/harness"; : > "$tmp/harness/commitmsg-strict"
printf '\n# --- playbook commit template ---\n# type: feat | fix | chore\nfeat(harness): real subject\n\n%s\n' "$TRAILER" > "$msgf"
expect_single "template comments do not masquerade as the subject under strict -> PASS" 0
rm -f "$tmp/harness/commitmsg-strict"

# A non-default core.commentChar must still delimit the scissors diff.
( cd "$tmp" && git config core.commentChar ';' )
printf 'feat(harness): clean subject\n; ----------------------- >8 -----------------------\ndiff has a %s dash\n' "$EMDASH" > "$msgf"
expect_single "scissors recognised under a custom core.commentChar -> PASS" 0
( cd "$tmp" && git config --unset core.commentChar )

# An empty message must not be a way to skip the author allowlist.
mkrepo
( cd "$tmp" && git config user.name outsider && git config user.email outsider@example.com )
mkdir -p "$tmp/harness"; : > "$tmp/harness/commitmsg-strict"
msgf="$tmp/msg.txt"; printf '\n' > "$msgf"
expect_single "empty message still checks the author allowlist under strict -> FAIL" 1

# --- single-message mode in a public repository -------------------------------
# The hook judges the identity the commit will be recorded under. A contributor's clone runs the
# same hook, so it must accept the contributor's own trailers while the owner's clone keeps them out.
mkrepo; strict_on; public_on
msgf="$tmp/msg.txt"
( cd "$tmp" && git config user.name "$CONTRIB_NAME" && git config user.email "$CONTRIB_EMAIL" )
printf 'feat(x): add a thing\n\n%s\n' "$CLAUDE_TRAILER" > "$msgf"
expect_single "public single mode: a contributor's own co-author -> PASS" 0

printf 'feat(x): a %s b\n' "$EMDASH" > "$msgf"
expect_single "public single mode: forbidden unicode from a contributor -> FAIL" 1

( cd "$tmp" && git config user.name nerdkim && git config user.email me@nerd.kim )
printf 'feat(x): add a thing\n\n%s\n' "$CLAUDE_TRAILER" > "$msgf"
expect_single "public single mode: the owner's other co-author -> FAIL" 1

# `git var` reads GIT_AUTHOR_NAME and GIT_AUTHOR_EMAIL too, so the verdict follows the identity the
# commit really carries rather than user.name alone.
got="$( cd "$tmp" && GIT_AUTHOR_NAME="$CONTRIB_NAME" GIT_AUTHOR_EMAIL="$CONTRIB_EMAIL" \
          bash "$CHK" --msg-file "$msgf" >/dev/null 2>&1; echo $? )"
if [ "$got" = 0 ]; then echo "  PASS public single mode: the author from GIT_AUTHOR_* decides (rc=$got)"
else echo "  FAIL public single mode: the author from GIT_AUTHOR_* decides (rc=$got, expected 0)"; fails=1; fi

# An identity git cannot tell is not a contributor: the unknown author gets every rule. The fixture
# hides every config file and forbids git from guessing, so `git var` has nothing to report.
mkdir -p "$tmp/nohome"
( cd "$tmp" && git config --unset user.name && git config --unset user.email && git config user.useConfigOnly true )
got="$( cd "$tmp" && HOME="$tmp/nohome" XDG_CONFIG_HOME="$tmp/nohome" GIT_CONFIG_NOSYSTEM=1 \
          bash "$CHK" --msg-file "$msgf" >/dev/null 2>&1; echo $? )"
if [ "$got" = 1 ]; then echo "  PASS public single mode: an unknown author keeps every rule -> FAIL (rc=$got)"
else echo "  FAIL public single mode: an unknown author keeps every rule (rc=$got, expected 1)"; fails=1; fi

# --- pull request text (P1, D48) ----------------------------------------------
# CI hands the title and body over in the environment. The owner's pull request must carry no
# co-author but mikdren, no signature and no session link; GitHub stores an edited body with CRLF.
pr_rc() { ( cd "$tmp" && PR_TITLE="$1" PR_BODY="$2" PR_AUTHOR="$3" REPO_OWNER=nerdkim bash "$CHK" --pr-text >/dev/null 2>&1 ); echo $?; }
expect_pr() { # label title body author expected-rc
  local got; got="$(pr_rc "$2" "$3" "$4")"
  if [ "$got" = "$5" ]; then echo "  PASS $1 (rc=$got)"; else echo "  FAIL $1 (rc=$got, expected $5)"; fails=1; fi
}
mkrepo
expect_pr "pr text: a clean description -> PASS" "feat: add a gate" "$(printf 'Adds a gate.\n\n%s\n' "$TRAILER")" nerdkim 0
expect_pr "pr text: CRLF around the sanctioned trailer -> PASS" "feat: add a gate" "$(printf 'Adds a gate.\r\n\r\n%s\r\n' "$TRAILER")" nerdkim 0
expect_pr "pr text: an empty description -> PASS" "feat: add a gate" "" nerdkim 0
expect_pr "pr text: the generated line -> FAIL (P1)" "feat: add a gate" "$(printf 'Adds a gate.\n\nGenerated with [Claude Code](https://claude.com/claude-code)\n')" nerdkim 1
expect_pr "pr text: a session link -> FAIL (P1)" "feat: add a gate" "$(printf 'Adds a gate.\n\n%s\n' "$SESSION_URL")" nerdkim 1
expect_pr "pr text: a Claude co-author -> FAIL (P1)" "feat: add a gate" "$(printf 'Adds a gate.\n\n%s\n' "$CLAUDE_TRAILER")" nerdkim 1
expect_pr "pr text: another human co-author -> FAIL (P1)" "feat: add a gate" "$(printf 'Adds a gate.\n\nCo-authored-by: Someone <someone@example.com>\n')" nerdkim 1
expect_pr "pr text: the signature in the title -> FAIL (P1)" "feat: add a gate (Generated with Claude Code)" "" nerdkim 1
expect_pr "pr text: a bot's description is not the owner's -> PASS" "Bump x" "$(printf 'Generated with some tool\n')" 'dependabot[bot]' 0

echo ""
if [ "$fails" = 0 ]; then echo "ALL TESTS PASSED"; exit 0; else echo "SOME TESTS FAILED"; exit 1; fi
