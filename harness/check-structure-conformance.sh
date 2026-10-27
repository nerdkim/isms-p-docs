#!/usr/bin/env bash
# check-structure-conformance.sh - the guard-set INTEGRITY and WIRING gate.
#
# The other checkers verify repository CONTENT. This one verifies that the guard itself is
# present, complete, unmodified, and actually wired, because every content rule is only as
# strong as the guard that runs it. Deleting a checker, weakening the CI workflow, or
# dropping the CLAUDE.md standard pointer are one-line evasions that no content check sees.
#
# Rules (source doc in parentheses):
#   FAIL T1 .gitignore is missing a secret-risk entry (.env, .env.*, _handoff/) (docs/12 s5.1)
#   FAIL T2 a git hook is missing or not executable (docs/10 s12.2)
#   FAIL T3 CLAUDE.md is not a non-empty regular file, or AGENTS.md is not a symlink to it (docs/10 s13)
#   FAIL T4 CLAUDE.md is missing or has no playbook managed block (docs/13 A-0); in a public
#           repository the block lives in the gitignored CLAUDE.local.md and CLAUDE.md must not carry it
#   FAIL T5 a guard file's hash differs from harness/MANIFEST.sha256 (guard tampered)
#   FAIL T6 the conventions CI workflow is missing or neutered, or skips or discards a checker,
#           the infra checker included where it is installed (docs/20 s2)
#   FAIL T7 a required guard file is missing from the guard set (docs/13 B-0)
#   FAIL T8 /playbook/ is not gitignored, or a playbook clone is tracked
#   WARN T9  no playbook version marker in CLAUDE.md (docs/13 A-0)
#   WARN T10 build-artifact or terraform-cache .gitignore entries missing (profile-aware)
#   WARN T11 core.hooksPath is not wired in this working copy (local only, not CI)
#   WARN T12 app repo has no verify script covering typecheck+lint+test, or no test file (docs/10 s12.1, D6)
#   FAIL T13 the conventions workflow never triggers on a branch this repo uses (docs/21 s2.2)
#   FAIL T14 the live workflow diverged from harness/conventions.yml, the template it ships (playbook only)
#   WARN T15 a guard file exists but is untracked, so it does not travel and CI never runs it
#   WARN T16 the Korean writing style is not installed, or its scripts or hooks are missing locally (docs/22 s6)
#   FAIL T17 public repository: the marker is unusable, or a personal file or setting is published (docs/22 s7)
#   WARN T18 a Linux job names a GitHub-hosted runner label instead of the standard expression (D50, docs/04 4.7)
#
# Scope note: T11 reads .git/config, which is not committed, so it is skipped under CI (a
# fresh checkout never has it). The committed half of the hook wiring is T2 plus the root
# package.json prepare script, which T11 reports on when present.
#
# Self mode: inside the playbook repo itself, T4 and T9 are skipped (playbook is the source
# of the standard, not a consumer of it) and the playbook-clone checks (T8) do not apply.
#
# Public repository mode (harness/public-repo, docs/22 s7): the personal managed block and the
# personal Claude Code settings live in the gitignored CLAUDE.local.md and
# .claude/settings.local.json, which CI and a contributor's clone never have. So CI checks only
# that nothing personal is COMMITTED (T4, T17), and the local reminders about the owner's own tooling
# (T4, T16) fire only in a working copy whose git identity is on the owner allowlist. A contributor
# therefore sees neither, and the owner's fresh clone still hears that its local files are missing.
#
# Usage: bash check-structure-conformance.sh [ROOT]   (ROOT default = git root, else cwd)
# Requires GNU grep. Exit 1 on any FAIL, else 0.
set -uo pipefail
# Never pipe into `grep -q` in the guards: grep stops at its first match, a writer still writing
# then dies of SIGPIPE, and pipefail turns that match into a failure. It failed T5 and T6 at
# random on a loaded machine. Feed a variable with a here-string (`grep -q RE <<< "$var"`) and
# test command output with [ -n "$(...)" ]; test-lib.sh fails on any new pipe into grep -q.

if ! grep -qP x <<< x 2>/dev/null; then
  echo "error: GNU grep -P (PCRE) required" >&2; exit 2
fi

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd $ROOT" >&2; exit 2; }

FAIL=0; WARN=0
say() { printf '%s\n' "$*"; }
report() { # SEV LABEL [DETAIL]
  local sev="$1" label="$2" detail="${3:-}"
  say "  [$sev] $label"
  [ -n "$detail" ] && printf '%s\n' "$detail" | sed 's/^/    /'
  if [ "$sev" = "FAIL" ]; then FAIL=1; else WARN=1; fi
  return 0
}

# ---- context -----------------------------------------------------------------
# Self-detection gates T4/T8/T9 off, so it must not be spoofable: three empty files with the
# right names would otherwise disable the "is this repo still connected to the standard" checks in
# a consumer repo. Require real playbook content, not merely the paths.
#
# The marker literal keys three gates in this file: the T7 installer pairing and the T5 coverage
# below, both through $PB_INSTALLER, and the self-detection. $PB_INSTALLER only ever makes a rule
# STRICTER (it demands the installer's self-test and its manifest line), so it is resolved here
# directly and cannot be lost together with harness/lib.sh.
PB_INSTALLER=""
grep -q 'playbook guard-set install' harness/install.sh 2>/dev/null && PB_INSTALLER="harness/install.sh"
# Self-detection gates T4, T8, T9 and T14, so it must be neither spoofable nor brittle.
# Spoofing is handled by requiring real content, not merely the paths: the installer must carry
# its own marker string. Brittleness was the other half: keying on the exact filename
# docs/00-overview.md and on VERSION carrying a leading `v` meant that renaming the overview or
# dropping the `v` would turn self-mode OFF in the playbook repo, and the consumer-only rules
# would start failing here for a reason with nothing to do with the guard. So any docs/00-*.md
# counts, and a version with or without the prefix.
#
# The test itself lives in harness/lib.sh (playbook_is_self), because check-infra-conformance.sh
# keys its module-code rule [9] on the same answer and the two must not drift apart. Self mode
# makes rules LAXER, so it fails closed: without lib.sh, which T7 then reports, the repository is
# read as a consumer.
IS_SELF=0
if [ -f harness/lib.sh ]; then
  # shellcheck source=/dev/null
  . harness/lib.sh
  if command -v playbook_is_self >/dev/null 2>&1 && playbook_is_self .; then IS_SELF=1; fi
fi
IS_CI=0
[ -n "${CI:-}${GITHUB_ACTIONS:-}" ] && IS_CI=1
HAS_NODE=0; [ -f package.json ] && HAS_NODE=1
HAS_INFRA=0
if [ -d infra ] || [ -f wrangler.toml ] \
   || [ -n "$(find . -maxdepth 3 -not -path './playbook/*' -not -path '*/.git/*' -not -path '*/node_modules/*' \
        \( -name '*.tf' -o -name '*.hcl' \) -print -quit 2>/dev/null)" ]; then
  HAS_INFRA=1
fi
CI_OPTOUT=0; [ -f harness/ci-optout ] && CI_OPTOUT=1

# Public repository mode. harness/lib.sh is the one reader of the marker and of the owner allowlist.
# Without it (T7 then FAILs) the mode reads as OFF, which can only make T4 stricter. OWNER_LOCAL is
# whether this working copy commits as the owner; it only ever gates local WARN reminders.
PUBLIC=0; PUBLIC_BAD=""; OWNER_LOCAL=0
if [ -f harness/lib.sh ]; then
  # shellcheck source=/dev/null
  . harness/lib.sh
  if command -v playbook_public_repo >/dev/null 2>&1; then
    _pstate="$(playbook_public_repo .)"
    case "$_pstate" in
      on)    PUBLIC=1 ;;
      bad:*) PUBLIC_BAD="${_pstate#bad:}" ;;
    esac
    if [ "$IS_CI" -eq 0 ]; then
      IFS=$'\t' read -r _idn _ide <<< "$(playbook_git_identity .)"
      if [ -n "${_idn:-}${_ide:-}" ] && playbook_is_owner "${_idn:-}" "${_ide:-}"; then OWNER_LOCAL=1; fi
    fi
  fi
fi

say "== check-structure-conformance (guard integrity + wiring) =="
say "  mode: $( [ "$IS_SELF" -eq 1 ] && echo 'playbook self' || echo consumer )$( [ "$PUBLIC" -eq 1 ] && echo ' public' )$( [ "$IS_CI" -eq 1 ] && echo ' (CI)' )  profile:$( [ "$HAS_NODE" -eq 1 ] && echo ' node' )$( [ "$HAS_INFRA" -eq 1 ] && echo ' infra' )"

# ---- T1 / T8 / T10 .gitignore ------------------------------------------------
# `tr -d '\r'` so a .gitignore with CRLF line endings is read correctly: otherwise `$` cannot match
# before the carriage return and every anchored test below fails on an otherwise conformant file.
gi_has() { [ -f .gitignore ] && grep -qE "$1" <<< "$(tr -d '\r' < .gitignore)"; }
if [ ! -f .gitignore ]; then
  report FAIL "T1 no .gitignore; secrets and session notes can be committed (docs/12 s5.1)"
else
  miss=""
  # `(^|/)` rather than `^/?` so the stricter `**/.env` spelling also satisfies the rule.
  gi_has '(^|/)\.env$'      || miss="${miss}.env"$'\n'
  # Require a real WILDCARD after `.env.`. A prefix test was satisfied by a narrower pre-existing
  # line such as `.env.local`, which left `.env.production` committable while this gate said PASS.
  gi_has '\.env\.\*'        || miss="${miss}.env.* (a wildcard; .env.local alone does not cover .env.production)"$'\n'
  gi_has '(^|/)_handoff/?$' || miss="${miss}_handoff/"$'\n'
  [ -n "$miss" ] && report FAIL "T1 .gitignore is missing a secret-risk entry (docs/12 s5.1)" "$miss"

  amiss=""
  if [ "$HAS_NODE" -eq 1 ]; then
    gi_has 'node_modules' || amiss="${amiss}node_modules"$'\n'
    gi_has '(^|/)dist'    || amiss="${amiss}dist"$'\n'
  fi
  if [ "$HAS_INFRA" -eq 1 ]; then
    gi_has '\.terraform'  || amiss="${amiss}.terraform / .terragrunt-cache"$'\n'
    gi_has 'tfstate'      || amiss="${amiss}*.tfstate"$'\n'
  fi
  [ -n "$amiss" ] && report WARN "T10 .gitignore is missing a build-artifact entry for this profile (docs/12 s5.1)" "$amiss"
fi

# T8 the playbook clone must never be committed into a consumer repo.
if [ "$IS_SELF" -eq 0 ]; then
  gi_has '(^|/)playbook/?$' || report FAIL "T8 /playbook/ is not in .gitignore; the standard clone must never be committed"
  # Two shapes to catch. A plain directory appears as tracked files under playbook/, but a clone
  # committed as a submodule is a single gitlink entry (mode 160000) with NO files beneath it, so
  # globbing 'playbook/*' alone missed it entirely.
  tracked_pb="$(git ls-files 'playbook/*' 2>/dev/null | head -3)"
  gitlink_pb="$(git ls-files -s playbook 2>/dev/null | awk '$1 == "160000" {print $4 " (submodule gitlink)"}')"
  [ -n "$tracked_pb$gitlink_pb" ] && report FAIL "T8 a playbook clone is tracked in git" "$tracked_pb$gitlink_pb"
fi

# ---- T2 git hooks present and executable -------------------------------------
hmiss=""
for h in pre-commit commit-msg pre-push; do
  if [ ! -f "harness/githooks/$h" ]; then hmiss="${hmiss}harness/githooks/$h missing"$'\n'
  elif [ ! -x "harness/githooks/$h" ]; then hmiss="${hmiss}harness/githooks/$h not executable"$'\n'
  fi
done
[ -n "$hmiss" ] && report FAIL "T2 git hook missing or not executable (docs/10 s12.2)" "$hmiss"

# ---- T3 CLAUDE.md is the real entry and AGENTS.md its alias -----------------
# Claude Code loads CLAUDE.md and other coding agents read AGENTS.md, so the standard keeps ONE file
# under both names: a regular CLAUDE.md, and AGENTS.md as a relative symlink to it. Two regular
# files drift apart, and a CLAUDE.md that is itself a link is a file Claude Code's editing tools
# refuse to write through. install-playbook.sh migrates every earlier layout into this one and
# refuses, rather than guesses, when the two names hold different instructions.
# `./CLAUDE.md` and `CLAUDE.md` are the same target, so a leading `./` is normalised.
link_of() { local t; t="$(readlink "$1" 2>/dev/null)"; printf '%s' "${t#./}"; }
if [ -L CLAUDE.md ] || [ ! -s CLAUDE.md ] || [ ! -f CLAUDE.md ]; then
  report FAIL "T3 CLAUDE.md must be a non-empty regular file (docs/10 s13)" \
    "fix: re-run bash playbook/install-playbook.sh and review the migrated instructions"
fi
if [ ! -L AGENTS.md ] || [ "$(link_of AGENTS.md)" != "CLAUDE.md" ]; then
  if [ -L AGENTS.md ]; then t3_state="AGENTS.md points at $(readlink AGENTS.md)"
  elif [ -e AGENTS.md ]; then t3_state="AGENTS.md is a regular file, a second copy that will drift"
  else t3_state="AGENTS.md is missing, so other coding agents find no instructions"; fi
  report FAIL "T3 AGENTS.md must be a symlink to CLAUDE.md (docs/10 s13)" \
    "${t3_state}
fix: re-run bash playbook/install-playbook.sh (it asks for a merge when the two files differ)"
fi

# ---- T4 CLAUDE.md standard pointer / T9 version marker -----------------------
# Marker presence alone used to satisfy T4, so emptying the block between the two markers
# passed. That matters now that the block CARRIES the rules instead of pointing at them:
# deleting its body silently removes every rule an agent would have loaded, and the guard
# reported PASS. The threshold is a line count rather than a content match, so the block can
# be rewritten freely without this check pinning any particular wording.
t4_thin() { # FILE -> FAIL when the managed block in FILE carries fewer than 20 lines
  local n
  n="$(awk '/playbook-standard:start/{p=1;next} /playbook-standard:end/{p=0} p' "$1" | grep -c .)"
  if [ "${n:-0}" -lt 20 ]; then
    report FAIL "T4 the managed block in $1 carries only $n lines; the standard rules are missing from it (docs/13 A-0)" \
      "The block states the rules, it does not merely point at them. Emptying it removes them.
fix: re-run bash playbook/install-playbook.sh"
  fi
}
has_block() { [ -f "$1" ] && grep -q 'playbook-standard:start' "$1"; }
if [ ! -f CLAUDE.md ]; then
  report FAIL "T4 no CLAUDE.md; the repo has no work entry file (docs/13 A-0)"
elif [ "$IS_SELF" -eq 1 ]; then
  :
elif [ "$PUBLIC" -eq 1 ]; then
  # A public repository publishes CLAUDE.md, so the personal block must not be in it. The block
  # lives in the gitignored CLAUDE.local.md, which CI and a contributor's clone never have: its
  # absence is only worth a word in the owner's own working copy.
  if has_block CLAUDE.md; then
    report FAIL "T4 public repository: CLAUDE.md carries the personal managed block, which belongs in the gitignored CLAUDE.local.md (docs/22 s7)" \
      "fix: re-run bash playbook/install-playbook.sh, which moves the block and keeps the rest of CLAUDE.md"
  fi
  if has_block CLAUDE.local.md; then
    t4_thin CLAUDE.local.md
  elif [ "$IS_CI" -eq 0 ] && [ "$OWNER_LOCAL" -eq 1 ]; then
    report WARN "T4 public repository: no managed block in CLAUDE.local.md in this working copy, so Claude Code loads none of the standard rules here (docs/22 s7)" \
      "fix: re-run bash playbook/install-playbook.sh"
  fi
elif ! has_block CLAUDE.md; then
  report FAIL "T4 CLAUDE.md has no playbook managed block; the repo is disconnected from the standard (docs/13 A-0)" \
    "fix: re-run bash playbook/install-playbook.sh"
else
  t4_thin CLAUDE.md
  # Left behind by a repository that was public and is not any more. Claude Code loads both files.
  if [ "$IS_CI" -eq 0 ] && has_block CLAUDE.local.md; then
    report WARN "T4 CLAUDE.local.md still carries a managed block although the repository is not public, so Claude Code loads the rules twice (docs/22 s7)" \
      "fix: delete the block from CLAUDE.local.md; CLAUDE.md carries it"
  fi
fi
if [ "$IS_SELF" -eq 0 ]; then
  # Only pass files that exist. Naming a missing CLAUDE.md makes grep exit 2, and under `pipefail`
  # that error propagates and the marker is reported missing even when CLAUDE.md carries it.
  # One shared reader (harness/lib.sh), so this gate, the installer, the entrypoint and the
  # infra checker cannot drift into three different patterns again. It tolerates the bolded
  # form, which every earlier reader missed and which the legacy population actually uses, and
  # it prefers harness/ADOPTED over prose.
  t9_adopted=""
  if [ -f harness/lib.sh ]; then
    # shellcheck source=/dev/null
    . harness/lib.sh
    t9_adopted="$(playbook_read_adopted .)"
  else
    t9_adopted="$(grep -hoP 'playbook[[:space:]]*[*_]*[[:space:]]*(버전|version)[[:space:]]*[*_]*[[:space:]]*:[[:space:]]*[*_]*[[:space:]]*\Kv[0-9]+\.[0-9]+\.[0-9]+' CLAUDE.md 2>/dev/null | head -1 || true)"
  fi
  if [ -z "$t9_adopted" ]; then
    report WARN "T9 no playbook version marker in CLAUDE.md or harness/ADOPTED; conformance version undeclared (docs/13 A-0)"
  elif [ -f playbook/VERSION ]; then
    # A marker that merely EXISTS says nothing about currency: a repo adopted at v0.1.0 passed
    # a presence-only check forever. When a clone is reachable, compare against it.
    t9_canon="$(tr -d ' \t\n\r' < playbook/VERSION)"
    case "$(playbook_version_cmp "$t9_adopted" "$t9_canon")" in
      behind|pre-reset)
        report WARN "T9 $(playbook_describe_delta "$t9_adopted" "$t9_canon")" ;;
    esac
  fi
fi

# ---- T7 guard-set completeness ----------------------------------------------
# A deleted checker is the cheapest possible evasion, so absence is a FAIL, never a skip.
REQUIRED_GUARD="harness/lib.sh
harness/verify.sh
harness/test-lib.sh
harness/bootstrap-hooks.sh
harness/check-conventions.sh
harness/test-check-conventions.sh
harness/check-standard-conformance.sh
harness/test-check-standard-conformance.sh
harness/check-commit-messages.sh
harness/test-check-commit-messages.sh
harness/check-structure-conformance.sh
harness/test-check-structure-conformance.sh
harness/make-manifest.sh
harness/gitmessage
harness/githooks/pre-commit
harness/githooks/commit-msg
harness/githooks/pre-push"
gmiss=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || gmiss="${gmiss}${f}"$'\n'
done <<< "$REQUIRED_GUARD"
if [ "$HAS_INFRA" -eq 1 ] && [ ! -f harness/check-infra-conformance.sh ]; then
  gmiss="${gmiss}harness/check-infra-conformance.sh (infra profile)"$'\n'
fi
# Every checker ships with its self-test (docs/00 D6), the report-only one included. Requiring the
# test only when its checker is present keeps a non-infra repo from failing over a file it should
# never have, while making "a checker with no test" impossible in a repo that does have it.
if [ -f harness/check-infra-conformance.sh ] && [ ! -f harness/test-check-infra-conformance.sh ]; then
  gmiss="${gmiss}harness/test-check-infra-conformance.sh (self-test for the infra checker, docs/00 D6)"$'\n'
fi
# The installer gets the same pairing, and for the same reason. It is the one script that writes
# into ANOTHER repository, and it is not distributed (a consumer runs the playbook clone's copy),
# so it cannot sit in REQUIRED_GUARD: a consumer has neither file and must not be asked for either.
# Where it IS present its self-test must be too, otherwise deleting harness/test-install.sh together
# with its manifest line leaves nothing at this layer to notice. Keyed on the file's CONTENT rather
# than its name, so a consumer's own unrelated harness/install.sh is never asked for a playbook
# self-test it never received.
if [ -n "$PB_INSTALLER" ] && [ ! -f harness/test-install.sh ]; then
  gmiss="${gmiss}harness/test-install.sh (self-test for the installer, docs/00 D6)"$'\n'
fi
[ -n "$gmiss" ] && report FAIL "T7 guard file missing from the guard set (docs/13 B-0)" "${gmiss}fix: re-run bash playbook/install-playbook.sh"

# ---- T5 guard integrity vs the manifest --------------------------------------
# The manifest records the hash of each guard file as installed. A mismatch means a guard
# was edited locally, which is how a checker gets quietly weakened. This detects drift and
# casual tampering; it is not cryptographic (an editor can regenerate the manifest), but the
# regeneration then shows up as its own reviewable diff in the PR.
if [ -f harness/MANIFEST.sha256 ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    bad=""; listed=""
    # `|| [ -n "$line" ]` so a manifest with no trailing newline does not drop its last entry,
    # which would silently exempt whichever guard file happens to be listed last.
    while IFS= read -r line || [ -n "$line" ]; do
      [ -n "$line" ] || continue
      case "$line" in \#*) continue ;; esac
      want="${line%% *}"; file="${line#* }"
      while [ "${file# }" != "$file" ]; do file="${file# }"; done
      [ -n "$want" ] && [ -n "$file" ] || continue
      listed="${listed}${file}"$'\n'
      if [ ! -f "$file" ]; then bad="${bad}${file}: missing"$'\n'; continue; fi
      got="$(sha256sum "$file" | cut -d' ' -f1)"
      [ "$got" = "$want" ] || bad="${bad}${file}: hash mismatch (installed ${want:0:12}, now ${got:0:12})"$'\n'
    done < harness/MANIFEST.sha256
    [ -n "$bad" ] && report FAIL "T5 guard file changed after install (guard tampered or stale)" \
      "${bad}fix: re-run bash playbook/install-playbook.sh to restore the canon, or regenerate deliberately with bash harness/make-manifest.sh"

    # COVERAGE. Verifying only what the manifest lists is fail-open: deleting one line exempts
    # that guard file from integrity checking forever, and every later edit to it produces no
    # signal at all. So assert the converse too, the same way T7 treats a missing checker as a
    # failure rather than a skip: every guard file that exists must be covered.
    uncovered=""
    while IFS= read -r g; do
      [ -n "$g" ] || continue
      [ -f "$g" ] || continue
      grep -qxF -- "$g" <<< "$listed" || uncovered="${uncovered}${g}"$'\n'
    # The extras beyond REQUIRED_GUARD are conditional guards: the infra checker exists only on
    # an infra profile, and conventions.yml plus the installer pair only in the playbook repo
    # (a consumer receives the workflow at .github/workflows/ and never receives the installer,
    # so it never receives the installer's self-test either). The `[ -f "$g" ]` skip above makes
    # each a no-op wherever the file legitimately does not exist, and $PB_INSTALLER is empty
    # unless harness/install.sh really is the playbook one, so a consumer that happens to keep
    # its own harness/install.sh is asked for nothing.
    done <<< "$REQUIRED_GUARD
harness/check-infra-conformance.sh
harness/test-check-infra-conformance.sh
harness/conventions-terms
harness/conventions.yml
harness/test-install.sh
$PB_INSTALLER
.github/workflows/conventions.yml"
    [ -n "$uncovered" ] && report FAIL "T5 guard file is not covered by MANIFEST.sha256 (integrity unverifiable for it)" \
      "${uncovered}A deleted manifest line exempts that file from tamper detection.
fix: bash harness/make-manifest.sh (then review the diff)"
  else
    report WARN "T5 sha256sum unavailable; guard integrity not verified"
  fi
else
  report WARN "T5 no harness/MANIFEST.sha256; guard integrity is unverifiable (re-run install-playbook.sh to add it)"
fi

# ---- T6 conventions CI workflow integrity ------------------------------------
WF=".github/workflows/conventions.yml"
[ -f "$WF" ] || WF=".github/workflows/conventions.yaml"
if [ ! -f "$WF" ]; then
  if [ "$CI_OPTOUT" -eq 1 ]; then
    report WARN "T6 no conventions CI workflow (harness/ci-optout present). Local hooks only, so --no-verify bypasses every rule (docs/20 s2)"
  else
    report FAIL "T6 no conventions CI workflow; local hooks only, so --no-verify bypasses every rule (docs/20 s2)" \
      "fix: re-run bash playbook/install-playbook.sh (CI is installed by default)"
  fi
else
  wf_bad=""
  if ! grep -qE '^[[:space:]]+docs-conventions:' "$WF"; then
    wf_bad="${wf_bad}job is not named docs-conventions, so the required-check context would not match"$'\n'
    JOB=""
  else
    # Scope every following check to the docs-conventions JOB, not the whole file. A file-wide
    # grep is fail-open here: a second, unrelated job carrying `runs-on: ubuntu-latest` would
    # satisfy the runner check while docs-conventions itself ran on a self-hosted runner that can
    # always report green. Extract from the job id to the next job at the same indent; a comment
    # may follow either line.
    JOB="$(awk '
      /^[[:space:]]+docs-conventions:[[:space:]]*(#.*)?$/ { inj=1; ind=match($0,/[^ ]/); print; next }
      inj && /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*(#.*)?$/ && match($0,/[^ ]/) <= ind { inj=0 }
      inj { print }
    ' "$WF")"
    # Every check below reads JOB, so a job the extraction cannot read (a flow mapping, or a second
    # key of the same name) fails here instead of passing with nothing checked.
    if [ -z "$JOB" ] || [ "$(grep -cE '^[[:space:]]+docs-conventions:' "$WF")" -ne 1 ]; then
      wf_bad="${wf_bad}the docs-conventions job cannot be read: write it once, as a block mapping (\`docs-conventions:\` on its own line)"$'\n'
      JOB=""
    fi
  fi

  jobhas() { grep -qE -- "$1" <<< "$JOB"; }
  # D50: a private repository runs the job on the owner's local runner through this one expression,
  # which sends a public repository to GitHub-hosted ubuntu-latest. Any other self-hosted label could
  # be a runner that always reports green, so the job passes only with this or an ubuntu label.
  # Only the job's own runs-on key counts, and its whole value must match: a substring test passed
  # a comment carrying the expression next to `runs-on: [self-hosted]`. A GitHub-hosted label is
  # ubuntu-latest or ubuntu-<YY.MM>(-arm), not any ubuntu-*, which a self-hosted runner can carry.
  runner_expr="\${{ github.event.repository.private && fromJSON('[\"self-hosted\",\"linux\",\"x64\"]') || 'ubuntu-latest' }}"
  runner_ok() {
    local keys child value
    # Every spelling of the key counts (`runs-on :`, a quoted key), wherever it sits in the job, so
    # a line inside a block scalar cannot pose as the key while the real one is spelled otherwise.
    keys="$(grep -E "^[[:space:]]*[\"']?runs-on[\"']?[[:space:]]*:" <<< "$JOB" || true)"
    [ -n "$keys" ] && [ "$(grep -c '' <<< "$keys")" -eq 1 ] || return 1
    # The one key is a plain `runs-on:` directly under the job id.
    [[ "$keys" =~ ^[[:space:]]+runs-on: ]] || return 1
    child="$(awk 'NR > 1 && !/^[[:space:]]*(#.*)?$/ { print match($0, /[^ ]/); exit }' <<< "$JOB")"
    [ "$(awk '{ print match($0, /[^ ]/) }' <<< "$keys")" = "$child" ] || return 1
    value="$(sed -E 's/^[[:space:]]+runs-on:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//' <<< "$keys")"
    [[ "$value" =~ ^ubuntu-(latest|[0-9]{2}\.[0-9]{2})(-arm)?$ ]] || [ "$value" = "$runner_expr" ]
  }

  if [ -n "$JOB" ]; then
    runner_ok \
      || wf_bad="${wf_bad}the docs-conventions job runs neither on a GitHub-hosted ubuntu runner nor through the standard private-repository runner expression (another self-hosted runner can always report green)"$'\n'
    jobhas 'continue-on-error:[[:space:]]*true' \
      && wf_bad="${wf_bad}continue-on-error: true makes the gate advisory"$'\n'
    # Each checker must be actually INVOKED, not merely mentioned: a bare substring match is
    # satisfied by a comment naming the checker while the job runs nothing.
    # The infra checker blocks like the rest since v0.7.0 (module code, module sources and PAT access
    # are FAIL rules), so an infra repo, the only kind that receives it, must run it as well.
    infra_need=""; [ -f harness/check-infra-conformance.sh ] && infra_need=check-infra-conformance
    for need in check-conventions check-standard-conformance check-commit-messages check-structure-conformance $infra_need; do
      jobhas "(bash|sh)[[:space:]]+[^[:space:]]*harness/${need}\.sh" \
        || wf_bad="${wf_bad}the docs-conventions job never invokes harness/${need}.sh"$'\n'
    done
    # Result discard. `|| true` alone was too narrow: `|| echo advisory` discards the result just as
    # well, and `[^|]*` cannot cross a pipe. So flag any `||` fallback on an INVOCATION line. Match
    # the invocation form specifically, since a `test -f ... || { exit 1; }` presence assert also
    # contains `||` but is fail-closed, the opposite of a discard. The infra checker is on this list
    # wherever an invocation of it appears: it was report-only until v0.7.0, and the old
    # `|| echo ::warning` shape is exactly what this catches.
    for need in check-conventions check-standard-conformance check-commit-messages check-structure-conformance check-infra-conformance; do
      inv="$(grep -E "(bash|sh)[[:space:]]+[^[:space:]]*harness/${need}\.sh" <<< "$JOB")"
      grep -qE '\|\||;[[:space:]]*true' <<< "$inv" \
        && wf_bad="${wf_bad}harness/${need}.sh result is discarded (a fallback after the invocation)"$'\n'
    done
  fi

  grep -qE '^[[:space:]]*paths(-ignore)?:' "$WF" \
    && wf_bad="${wf_bad}a paths / paths-ignore filter can skip the check, and a skipped required workflow stays Pending and blocks merging"$'\n'
  grep -q 'pull_request' "$WF" || wf_bad="${wf_bad}workflow has no pull_request trigger"$'\n'
  [ -n "$wf_bad" ] && report FAIL "T6 conventions CI workflow is neutered (docs/20 s2)" "$wf_bad"

  # A decoy workflow can emit the same check name and satisfy the required check instead. The
  # emitted context comes from `name:` when present, else the job id, so look for both, a trailing
  # comment allowed, in the other workflows and in the other jobs of this one.
  name_re="name:[[:space:]]*['\"]?docs-conventions['\"]?[[:space:]]*(#.*)?$"
  if [ "$(grep -cE "$name_re" "$WF")" -gt "$(grep -cE "$name_re" <<< "$JOB")" ]; then
    report FAIL "T6 another job in ${WF} is named docs-conventions; a decoy can satisfy the required context" \
      "$(grep -nE "$name_re" "$WF")"
  fi
  decoy="$(grep -lE "^[[:space:]]+docs-conventions:|${name_re}" \
             .github/workflows/* 2>/dev/null | grep -v "^${WF}$" || true)"
  [ -n "$decoy" ] && report FAIL "T6 another workflow declares a docs-conventions check; a decoy can satisfy the required context" "$decoy"
fi

# ---- T11 local hook wiring (skipped under CI) --------------------------------
if [ "$IS_CI" -eq 0 ]; then
  hp="$(git config --get core.hooksPath 2>/dev/null || true)"
  [ "$hp" = "harness/githooks" ] \
    || report WARN "T11 core.hooksPath is '${hp:-unset}', expected harness/githooks; local hooks do not run in this working copy" \
        "fix: git config core.hooksPath harness/githooks"
fi
# install-playbook.sh [4b] chains `bash harness/bootstrap-hooks.sh` onto prepare, and that script
# sets core.hooksPath itself, so either form wires the hooks of a fresh clone.
if [ "$HAS_NODE" -eq 1 ] && ! grep -qE 'core\.hooksPath|harness/bootstrap-hooks\.sh' package.json 2>/dev/null; then
  report WARN "T11 package.json has no prepare script wiring core.hooksPath (directly or through harness/bootstrap-hooks.sh); a fresh clone starts with no hooks (docs/10 s12.2)"
fi

# ---- T12 test gate (app repo) -------------------------------------------------
if [ "$HAS_NODE" -eq 1 ]; then
  grep -qE '"verify"[[:space:]]*:' package.json \
    || report WARN "T12 root package.json has no verify script (typecheck + lint + test), the single CI gate (docs/10 s12.1, D6)"
  if [ -z "$(find . -path ./node_modules -prune -o -path ./playbook -prune -o \
        \( -name '*.test.ts' -o -name '*.test.tsx' -o -name '*.spec.ts' -o -name '*_test.py' -o -name 'test_*.py' \) \
        -print -quit 2>/dev/null)" ]; then
    report WARN "T12 no test file found; every project must ship test code (docs/00 D6, docs/20 s5)"
  fi
fi

# ---- T13 the workflow actually triggers on this repo's branches ---------------
# T6 checks that the workflow is not neutered, and every one of its tests passed on a repo
# where the workflow never ran at all: the trigger list was [develop, master] and the repo's
# trunk was `main`. No run means no check to require, which means no gate, and the guard
# reported PASS the whole time. Checking the file's CONTENT while never asking whether it
# fires is the blind spot, so T13 asks.
#
# main is the expected trunk (D44): the default and prod branch of every repository, so it must be
# on the push list even where the branch does not exist yet. Renaming master to main on GitHub is a
# single step, and a list without main would leave the repository with no gate from that moment.
# develop and master are required where the repo has them. master is accepted only until the repo
# renames it, and a repo that still has it is told so.
#
# Only the push list is checked. The pull_request trigger deliberately carries no branch
# filter (a PR into any branch should be checked), so an absent filter there is correct.
WF=".github/workflows/conventions.yml"
[ -f "$WF" ] || WF=".github/workflows/conventions.yaml"
if [ -f "$WF" ] && [ "$CI_OPTOUT" -eq 0 ]; then
  # The branch list under `push:`, in EITHER YAML spelling. Reading only the `branches:` line
  # caught the flow form `branches: [develop, master]` and saw nothing at all in the equivalent
  # block sequence, where the names sit on the following lines. That made T13 FAIL a consumer
  # whose workflow was hand-written or pre-existing, for a trigger list that is in fact correct.
  push_branches="$(awk '
    /^[[:space:]]*push:/{p=1; next}
    /^[[:space:]]*(pull_request|workflow_dispatch|schedule|jobs):/{p=0}
    p && /^[[:space:]]*branches:/{
      line=$0; sub(/^[[:space:]]*branches:[[:space:]]*/,"",line)
      if (line ~ /\[/) { print line; exit }          # flow form, names are on this line
      seq=1; next                                    # block form, names follow
    }
    seq {
      if ($0 ~ /^[[:space:]]*-[[:space:]]*[^[:space:]]/) { n=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",n); acc=acc " " n; next }
      if ($0 ~ /^[[:space:]]*$/) next
      print acc; exit
    }
    END { if (seq && acc != "") print acc }
  ' "$WF")"
  # The trunk is the branch origin names as its default. Only a repository with no remote default
  # falls back to the branch checked out now. Counting the checked-out branch everywhere made
  # every short-lived work branch a FAIL, locally and in the pre-commit hook, although its pull
  # requests are checked anyway: the pull_request trigger carries no branch filter. That blocked
  # feature branches, which docs/12 s1 allows, and every contributor's branch in a fork.
  cur="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  cur="${cur#origin/}"; cur_why="origin's default branch"
  if [ -z "$cur" ]; then
    cur="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"; cur_why="checked out now"
  fi
  if [ -z "$push_branches" ]; then
    report FAIL "T13 the conventions workflow has no push branch list; it cannot be reasoned about (docs/21 s2.2)"
  else
    uncovered=""
    # main always; develop and the temporary master where this repo or its origin has them. A
    # detached HEAD (the normal CI shape) has no checked-out branch and is simply skipped below.
    for b in main develop master; do
      why="this repo has it"
      if [ "$b" = main ]; then
        why="the trunk of every repository, D44"
      elif ! git show-ref --verify --quiet "refs/heads/$b" 2>/dev/null \
           && ! git show-ref --verify --quiet "refs/remotes/origin/$b" 2>/dev/null; then
        continue
      fi
      grep -qE "[][, ]${b}[],  ]|[][, ]${b}\$" <<< "$push_branches" \
        || uncovered="${uncovered}$b ($why, the workflow ignores it)"$'\n'
    done
    if [ -n "$cur" ] && ! grep -qE "[][, ]${cur}[],  ]|[][, ]${cur}\$" <<< "$push_branches"; then
      case "$uncovered" in *"$cur "*) ;; *) uncovered="${uncovered}$cur ($cur_why, the workflow ignores it)"$'\n';; esac
    fi
    [ -n "$uncovered" ] && report FAIL \
      "T13 the conventions workflow never runs on a branch this repo uses, so there is no gate (docs/21 s2.2)" \
      "${uncovered}workflow has: ${push_branches}
fix: add the branch to the push trigger list in $WF"
  fi
  # master is retired (D44). The push list still carries it so that a repo which has not renamed it
  # keeps its gate, and that is exactly what makes the leftover easy to miss, so it is reported. A
  # local master left in a clone counts too: that clone has not followed the rename yet.
  if [ "$cur" = master ] || git show-ref --verify --quiet refs/heads/master 2>/dev/null \
     || git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
    report WARN "T13 this repo still has a master branch; main is the default and prod branch (D44), and the workflow keeps master only until the rename" \
      "owner step: gh api -X POST repos/<owner>/<repo>/branches/master/rename -f new_name=main
then make main the default (gh repo edit <owner>/<repo> --default-branch main), and in each clone:
git branch -m master main && git fetch origin && git branch -u origin/main main && git remote set-head origin -a"
  fi
fi

# ---- T14 the live workflow must match the template it ships -------------------
# Playbook only, because only the playbook repo holds both files: a consumer receives the
# workflow at .github/workflows/ and never receives harness/conventions.yml, and T5 already
# hashes the installed copy there.
#
# This exists because the two silently diverged. Commit 636d9ed fixed the trigger list so the
# workflow would run on a `main`-trunk repo, and fixed it in the TEMPLATE only. The live
# workflow kept `branches: [develop, master]` and kept a `pull_request` branch filter the
# template had deliberately dropped, so in this repository a pull request into any branch
# other than those two skipped the whole gate, and a skipped required workflow stays Pending and blocks merging
# rather than red. No rule saw it: T13 only cross-checks the push list against the branches
# this repo has (both listed, so PASS), and T5 hashes the live file against ITSELF. A
# template-only fix was invisible to every gate, which is the failure this rule closes.
if [ "$IS_SELF" -eq 1 ] && [ -f harness/conventions.yml ] && [ -f .github/workflows/conventions.yml ]; then
  if ! cmp -s harness/conventions.yml .github/workflows/conventions.yml; then
    report FAIL "T14 .github/workflows/conventions.yml diverged from harness/conventions.yml (the template it ships)" \
      "$(diff -u harness/conventions.yml .github/workflows/conventions.yml | head -20)
The playbook's own CI must be the file it distributes, or a template-only fix never runs here.
fix: cp harness/conventions.yml .github/workflows/conventions.yml && bash harness/make-manifest.sh"
  fi
fi

# ---- T15 the guard must be COMMITTED, not merely present ---------------------
# An untracked workflow never runs. GitHub reads workflows from the repository, so a
# conventions.yml sitting in the working tree is a file, not a gate, and every document that
# says "after the workflow has reported once" is unreachable until it is committed. The same
# is true of the checkers: a fresh clone of a repo whose guard was never committed has no
# guard at all, while the local working copy looks fully installed.
#
# Nothing detected this. The installer wrote the files and reported done, and this checker
# reported PASS with warnings, because presence and tracking are different questions and only
# presence was ever asked.
# Only once the repo has a commit. A repository with no HEAD is mid-adoption by definition:
# the greenfield path installs the guard and then makes the scaffold commit, so everything is
# legitimately untracked in between, and firing here would make the installer report a failure
# it is three lines away from fixing.
if git rev-parse --git-dir >/dev/null 2>&1 && git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  untracked=""
  for g in .github/workflows/conventions.yml .github/workflows/conventions.yaml \
           harness/check-conventions.sh harness/check-structure-conformance.sh \
           harness/check-standard-conformance.sh harness/check-commit-messages.sh \
           harness/lib.sh harness/MANIFEST.sha256 harness/githooks/pre-commit harness/public-repo; do
    [ -f "$g" ] || continue
    git ls-files --error-unmatch "$g" >/dev/null 2>&1 || untracked="${untracked}${g}"$'\n'
  done
  if [ -n "$untracked" ]; then
    # WARN, not FAIL, and the reason is what the rule can actually observe. In CI every file is
    # tracked by construction (CI runs on a checkout), so this condition is unobservable there
    # and a FAIL would only ever fire locally, in the window between installing the guard and
    # committing it, on the run the installer itself performs. That is noise, not a gate. It is
    # a local signal like T11, and the installer prints the exact commit command beside it.
    report WARN "T15 a guard file exists but is not tracked by git, so it never travels and CI never runs it" \
      "${untracked}fix: git add harness .github && git commit -m \"chore: adopt the playbook guard set\""
  fi
fi

# ---- T16 the Korean writing style is installed --------------------------------
# The playbook installs one pinned release of im-a-korean-ai-in-seoul into every repository
# (docs/22 s6). Its rule file is committed, so a repository without it never received the style. A
# working copy that has the rule file but not the scripts is a fresh clone whose settings.json hooks
# point at nothing. Both are local signals like T11: Claude Code hooks are feedback, not the gate.
# Scripts with no hook wired to them never run either. Claude Code reads hooks from the shared
# .claude/settings.json and the personal .claude/settings.local.json alike, so either file counts.
#
# In a public repository the style is the owner's personal tooling: its hooks, output style and
# scripts live in gitignored files, so nothing of it is required in CI or in a contributor's clone,
# and the local reminders fire only in the owner's own working copy.
ks_hooked() { # FILE -> 0 when FILE wires both hooks of the Korean writing style
  [ -f "$1" ] && grep -qF '.korean-style/scripts/hooks/pretooluse.mjs' "$1" \
    && grep -qF '.korean-style/scripts/hooks/stop.mjs' "$1"
}
if [ "$PUBLIC" -eq 1 ]; then
  if [ "$IS_CI" -eq 0 ] && [ "$OWNER_LOCAL" -eq 1 ]; then
    if [ ! -f .korean-style/scripts/hooks/pretooluse.mjs ]; then
      report WARN "T16 public repository: the Korean writing style is not installed in this working copy (docs/22 s7)" \
        "fix: re-run bash playbook/install-playbook.sh (it needs Node.js 20 or later)"
    elif ! ks_hooked .claude/settings.local.json; then
      report WARN "T16 public repository: the Korean writing style hooks are not in .claude/settings.local.json, so they do not run for the owner (docs/22 s7)" \
        "fix: re-run bash playbook/install-playbook.sh"
    fi
  fi
elif [ ! -f .korean-style/rules.md ]; then
  report WARN "T16 the Korean writing style is not installed (no .korean-style/rules.md), so Claude Code gets no Korean style checks (docs/22 s6)" \
    "fix: re-run bash playbook/install-playbook.sh (it needs Node.js 20 or later)"
elif [ "$IS_CI" -eq 0 ] && [ ! -f .korean-style/scripts/hooks/pretooluse.mjs ]; then
  report WARN "T16 the Korean writing style scripts are missing in this working copy, so its hooks point at nothing (docs/22 s6)" \
    "fix: re-run bash playbook/install-playbook.sh"
elif [ "$IS_CI" -eq 0 ] && ! ks_hooked .claude/settings.json && ! ks_hooked .claude/settings.local.json; then
  report WARN "T16 the Korean writing style hooks are wired in neither .claude/settings.json nor .claude/settings.local.json, so they never run (docs/22 s6)" \
    "fix: re-run bash playbook/install-playbook.sh"
fi

# ---- T17 a public repository publishes nothing personal -----------------------
# harness/public-repo moves the owner's personal instructions and Claude Code settings out of the
# committed files (docs/22 s7). What CI can see is the committed half, so that is what this checks:
# the two personal files are ignored and untracked, and the shared settings carry none of the
# owner's hooks, output style or co-author. A marker that cannot be read is itself a FAIL, because it
# silently turns the mode off and every contributor's commit then fails the owner-only rules.
if [ -n "$PUBLIC_BAD" ]; then
  report FAIL "T17 $PUBLIC_BAD; public repository mode is OFF, so the owner-only rules apply to every commit (docs/22 s7)" \
    "fix: state why the repository is public on the first non-comment line, or delete the marker"
fi
if [ "$PUBLIC" -eq 1 ]; then
  leak=""
  for f in CLAUDE.local.md .claude/settings.local.json; do
    if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
      leak="${leak}$f is tracked by git, so every clone and fork receives it"$'\n'
    elif git rev-parse --git-dir >/dev/null 2>&1 && ! git check-ignore -q --no-index -- "$f" 2>/dev/null; then
      leak="${leak}$f is not gitignored, so a single git add publishes it"$'\n'
    fi
  done
  if [ -f .claude/settings.json ]; then
    grep -qF '.korean-style/scripts/hooks/' .claude/settings.json \
      && leak="${leak}.claude/settings.json runs the Korean writing style hooks, whose scripts a contributor does not have"$'\n'
    grep -qE '"outputStyle"[[:space:]]*:[[:space:]]*"korean-style"' .claude/settings.json \
      && leak="${leak}.claude/settings.json selects the owner's Korean output style"$'\n'
    grep -qF 'bot-sidekick@nerd.kim' .claude/settings.json \
      && leak="${leak}.claude/settings.json names the owner's co-author, which every contributor's Claude Code would then add"$'\n'
  fi
  [ -n "$leak" ] && report FAIL "T17 public repository: a personal instruction or setting is published (docs/22 s7)" \
    "${leak}fix: re-run bash playbook/install-playbook.sh, which moves them into the gitignored local files"
  # CLAUDE.md is the public guidance for contributors. Korean text in it is usually a personal
  # instruction that stayed behind, so it is named, but only as a WARN: the project decides.
  if LC_ALL=C.UTF-8 grep -qP '[\x{AC00}-\x{D7A3}]' CLAUDE.md 2>/dev/null; then
    report WARN "T17 public repository: CLAUDE.md contains Korean text; it is the public guidance, and personal or Korean instructions belong in CLAUDE.local.md (docs/22 s7)"
  fi
fi

# ---- T18 every Linux job goes through the runner expression ------------------
# D50 runs every Linux job of a private repository on the owner's local runner through the standard
# runs-on expression, which still sends a public repository to GitHub-hosted. A job that names a
# hosted x64 label directly bypasses it: in a private repository it waits on GitHub's billing and
# never reaches the local runner (on 2026-10-26 GitHub refused every such job for a failed payment,
# D72). The local runner has no Docker and no arm64, so a job that needs either may keep its label
# with a reason in a trailing `# hosted-runner: <reason>` on the runs-on line. macOS, Windows and
# arm64 labels and matrix-driven values are not reported. A public repository (harness/public-repo)
# is skipped, since the expression changes nothing there. WARN: the job still runs where it says.
if [ "$PUBLIC" -eq 0 ]; then
  hosted=""
  while IFS= read -r wf; do
    [ -f "$wf" ] && [ ! -L "$wf" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      grep -qE '#[[:space:]]*hosted-runner:[[:space:]]*[^[:space:]]{3,}' <<< "${hit#*:}" && continue
      hosted="${hosted}${wf}:${hit%%:*}: $(sed -E 's/^[[:space:]]+//' <<< "${hit#*:}")"$'\n'
    done < <(grep -nE '^[[:space:]]*runs-on:[[:space:]]*ubuntu-(latest|[0-9]{2}\.[0-9]{2})[[:space:]]*(#.*)?$' "$wf" || true)
  done < <(git -c core.quotePath=false ls-files -- '.github/workflows/*.yml' '.github/workflows/*.yaml' 2>/dev/null)
  [ -n "$hosted" ] && report WARN "T18 a Linux job names a GitHub-hosted runner, so in a private repository it never reaches the local runner (D50, docs/04 4.7)" \
    "${hosted}fix: write runs-on as \${{ github.event.repository.private && fromJSON('[\"self-hosted\",\"linux\",\"x64\"]') || '<the label>' }}, or keep the label with a trailing '# hosted-runner: <reason>' when the job needs Docker"
fi

say ""
if [ "$FAIL" -eq 1 ]; then
  say "RESULT: FAIL (structure conformance). The guard itself is incomplete or bypassable; fix the FAIL items above."
  exit 1
fi
if [ "$WARN" -eq 1 ]; then
  say "RESULT: PASS with warnings (structure conformance)."
  exit 0
fi
say "RESULT: PASS (structure conformance)."
exit 0
