#!/usr/bin/env bash
# test-check-structure-conformance.sh - self-test for the guard integrity gate (docs/00 D6).
#
# Builds a fully conformant throwaway CONSUMER repo (guard set + CI workflow + CLAUDE.md
# managed block + .gitignore + AGENTS.md -> CLAUDE.md), asserts it passes, then breaks exactly
# one thing per case and asserts the corresponding FAIL. That is the property that matters:
# each single-line evasion must be caught on its own.
#
# 0 = PASS (or PASS with warnings), 1 = FAIL.
set -uo pipefail
HARNESS="$(cd "$(dirname "$0")" && pwd)"
CHK="$HARNESS/check-structure-conformance.sh"
# Every fixture lives under one work root that the EXIT trap removes. The trap used to see only the
# last fixture, so each run stranded one directory per case in the system TMPDIR.
WORK="$(mktemp -d)" || { echo "mktemp -d failed" >&2; exit 2; }
tmp=""; cleanup() { rm -rf -- "$WORK"; }; trap cleanup EXIT
fails=0
# The owner and contributor cases below are decided by the working copy's git identity.
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

# A conformant consumer repo. Deliberately NOT playbook-self shaped (no VERSION, no
# docs/00-overview.md), so the consumer-only rules T4/T8/T9 are exercised.
mkconsumer() {
  [ -n "$tmp" ] && rm -rf "$tmp"
  tmp="$(mktemp -d "$WORK/consumer.XXXXXX")"
  mkdir -p "$tmp/harness/githooks" "$tmp/.github/workflows"
  for f in lib.sh test-lib.sh bootstrap-hooks.sh verify.sh \
           check-conventions.sh test-check-conventions.sh \
           check-standard-conformance.sh test-check-standard-conformance.sh \
           check-commit-messages.sh test-check-commit-messages.sh \
           check-structure-conformance.sh test-check-structure-conformance.sh \
           make-manifest.sh gitmessage; do
    cp "$HARNESS/$f" "$tmp/harness/$f"
  done
  for h in pre-commit commit-msg pre-push; do
    cp "$HARNESS/githooks/$h" "$tmp/harness/githooks/$h"
    chmod +x "$tmp/harness/githooks/$h"
  done
  # The workflow source differs by repo: the playbook keeps the canon at harness/conventions.yml,
  # while a consumer only has the installed copy under .github/workflows/.
  if [ -f "$HARNESS/conventions.yml" ]; then
    cp "$HARNESS/conventions.yml" "$tmp/.github/workflows/conventions.yml"
  elif [ -f "$HARNESS/../.github/workflows/conventions.yml" ]; then
    cp "$HARNESS/../.github/workflows/conventions.yml" "$tmp/.github/workflows/conventions.yml"
  else
    echo "  SKIP: no conventions workflow to build a fixture from" >&2
    exit 0
  fi
  printf '.env\n.env.*\n!.env.example\n_handoff/\n/playbook/\nnode_modules/\ndist/\n' > "$tmp/.gitignore"
  # The block must look like what the installer actually writes, not like a stub. T4 now requires
  # the block to CARRY the rules, so a three-line fixture would fail every case here for a reason
  # that has nothing to do with what each case is testing. Content is representative rather than
  # identical: pinning the exact wording here would make every rule edit break this suite.
  {
    printf '# fixture\n\n'
    printf '<!-- playbook-standard:start -->\n'
    cat <<'FIXBLOCK'
## nerdkim engineering standard

Rules that apply to every task. Depth is in `./playbook/docs`.

### Working with the owner
- Reply in Korean, address the owner as 대표님, keep engineering terms in English.
- Never use the six forbidden punctuation characters, in a reply or in any file.
- Measure the current state before asking for a gated action.

### git
- Conventional Commits, one co-author trailer, no other.
- `develop` is free; the protected branch takes an approved PR only.

### Stack
- Hono on Lambda, Node.js current LTS, arm64, ESM, zod.
- Self-issued RS256 JWT, key in SSM. No Cognito.
- DynamoDB by default, Aurora DSQL when relational.
- DNS is Cloudflare. One CloudFront distribution fronts the S3 site and the API.

### security
- CI reaches AWS through GitHub OIDC only.
- Secrets live in SSM SecureString, never in the repo.
- Auth tokens stay in memory, never in web storage.

### verification
- `pnpm verify` is the CI gate. Do not claim something works without running it.
FIXBLOCK
    printf '\nplaybook version: v9.9.9 (sync date 2026-01-01)\n'
    printf '<!-- playbook-standard:end -->\n'
  } > "$tmp/CLAUDE.md"
  ln -s CLAUDE.md "$tmp/AGENTS.md"
  ( cd "$tmp" && git init -q -b main && git config core.hooksPath harness/githooks && git add -A )
  ( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
}

# The checker skips T11 under CI, so unset the CI markers to make results identical whether
# the suite runs on a laptop or inside Actions.
rc() { ( cd "$tmp" && env -u CI -u GITHUB_ACTIONS bash "$CHK" . >/dev/null 2>&1 ); echo $?; }
expect() { # label expected-rc
  local got; got="$(rc)"
  if [ "$got" = "$2" ]; then echo "  PASS $1 (rc=$got)"; else echo "  FAIL $1 (rc=$got, expected $2)"; fails=1; fi
}
# expect_report LABEL RC TEXT - like expect, and the report must also carry TEXT, so a case cannot
# pass on an unrelated failure such as a manifest left unrecorded.
expect_report() {
  local out got
  out="$( cd "$tmp" && env -u CI -u GITHUB_ACTIONS bash "$CHK" . 2>&1 )"; got=$?
  if [ "$got" = "$2" ] && grep -qF -- "$3" <<< "$out"; then
    echo "  PASS $1 (rc=$got)"
  else
    echo "  FAIL $1 (rc=$got, expected $2 with '$3')"; fails=1
  fi
}

echo "== test-check-structure-conformance =="

mkconsumer
expect "conformant consumer repo -> PASS" 0

mkconsumer; rm -f "$tmp/harness/check-standard-conformance.sh"
expect "T7 security checker deleted -> FAIL" 1

mkconsumer; rm -f "$tmp/harness/check-conventions.sh"
expect "T7 convention checker deleted -> FAIL" 1

mkconsumer; rm -f "$tmp/harness/githooks/commit-msg"
expect "T2 commit-msg hook deleted -> FAIL" 1

mkconsumer; chmod -x "$tmp/harness/githooks/pre-commit"
expect "T2 pre-commit hook not executable -> FAIL" 1

mkconsumer; mv "$tmp/CLAUDE.md" "$tmp/entry.md"; ln -s entry.md "$tmp/CLAUDE.md"
expect "T3 CLAUDE.md is itself a symlink -> FAIL" 1

mkconsumer; rm -f "$tmp/CLAUDE.md"
expect "T3 CLAUDE.md absent -> FAIL" 1

mkconsumer; : > "$tmp/CLAUDE.md"
expect "T3 CLAUDE.md empty -> FAIL" 1

mkconsumer; rm -f "$tmp/AGENTS.md"
expect "T3 AGENTS.md alias absent -> FAIL" 1

# A second regular copy is the drift the alias exists to prevent, even while it still matches.
mkconsumer; rm -f "$tmp/AGENTS.md"; cp "$tmp/CLAUDE.md" "$tmp/AGENTS.md"
expect "T3 AGENTS.md is a regular copy, not the alias -> FAIL" 1

mkconsumer; rm -f "$tmp/AGENTS.md"; printf '# other\n' > "$tmp/other.md"; ln -s other.md "$tmp/AGENTS.md"
expect "T3 AGENTS.md points at a file other than CLAUDE.md -> FAIL" 1

# The reversed pair is the shape Claude Code's editing tools refuse to write through; the
# installer migrates it, so the checker accepts only the standard direction.
mkconsumer; rm -f "$tmp/AGENTS.md"; mv "$tmp/CLAUDE.md" "$tmp/AGENTS.md"; ln -s AGENTS.md "$tmp/CLAUDE.md"
expect "T3 the reversed pair CLAUDE.md -> AGENTS.md -> FAIL" 1

mkconsumer; rm -f "$tmp/AGENTS.md"; ln -s ./CLAUDE.md "$tmp/AGENTS.md"
expect "T3 AGENTS.md -> ./CLAUDE.md is the same alias -> PASS" 0

mkconsumer; printf '# no managed block\n' > "$tmp/CLAUDE.md"
expect "T4 CLAUDE.md managed block removed -> FAIL" 1

mkconsumer; printf '.env\n.env.*\n_handoff/\n/playbook/\n' > "$tmp/.gitignore"
expect "T1/T8 gitignore still complete -> PASS" 0

mkconsumer; printf '_handoff/\n/playbook/\n' > "$tmp/.gitignore"
expect "T1 .env not gitignored -> FAIL" 1

mkconsumer; printf '.env\n.env.*\n/playbook/\n' > "$tmp/.gitignore"
expect "T1 _handoff not gitignored -> FAIL" 1

mkconsumer; printf '.env\n.env.*\n_handoff/\n' > "$tmp/.gitignore"
expect "T8 /playbook/ not gitignored -> FAIL" 1

# A narrower pre-existing entry must not satisfy the `.env.*` rule: `.env.local` alone leaves
# `.env.production` committable, so accepting it would report PASS over a real secret exposure.
mkconsumer; printf '.env\n.env.local\n_handoff/\n/playbook/\n' > "$tmp/.gitignore"
expect "T1 .env.local does not satisfy the .env.* wildcard rule -> FAIL" 1

# The stricter `**/` spelling must be accepted rather than reported as missing.
mkconsumer; printf '**/.env\n**/.env.*\n_handoff/\n/playbook/\n' > "$tmp/.gitignore"
expect "T1 accepts the **/ gitignore spelling -> PASS" 0

# A CRLF .gitignore must not fail every anchored test.
mkconsumer; printf '.env\r\n.env.*\r\n_handoff/\r\n/playbook/\r\n' > "$tmp/.gitignore"
expect "T1 handles CRLF line endings -> PASS" 0

mkconsumer; rm -f "$tmp/.github/workflows/conventions.yml"
expect "T6 CI workflow deleted -> FAIL" 1

# The opt-out path mirrors `install-playbook.sh --no-ci`, which writes the marker AND a
# manifest that has no workflow entry, so T5 must not fire on the absent workflow.
mkconsumer; rm -f "$tmp/.github/workflows/conventions.yml"; : > "$tmp/harness/ci-optout"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 CI workflow deleted with a recorded opt-out -> WARN only, PASS" 0

# But removing the workflow WITHOUT re-recording the manifest must still fail (T5 catches the
# deletion even if someone also drops the opt-out marker in).
mkconsumer; rm -f "$tmp/.github/workflows/conventions.yml"; : > "$tmp/harness/ci-optout"
expect "T5 workflow deleted without re-recording the manifest -> FAIL" 1

T6_RUNNER="runs neither on a GitHub-hosted ubuntu runner nor through the standard private-repository runner expression"
mkconsumer; sed -i 's/^\(    \)runs-on: .*/\1runs-on: self-hosted/' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 self-hosted runner -> FAIL" 1 "$T6_RUNNER"

# D50: the shipped job picks the owner's local runner for a private repository through one fixed
# expression. A plain ubuntu label (a consumer that has not moved yet) still passes; any other
# expression is a runner choice the checker cannot vouch for.
mkconsumer; sed -i 's/^\(    \)runs-on: .*/\1runs-on: ubuntu-latest  # hosted/' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 GitHub-hosted ubuntu runner with a trailing comment -> PASS" 0

mkconsumer
sed -i "s/^\(    \)runs-on: .*/\1runs-on: \${{ github.event.repository.private \&\& 'self-hosted' || 'ubuntu-latest' }}/" \
  "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 another runner expression -> FAIL" 1 "$T6_RUNNER"

# Only the job's own runs-on key counts. The expression or an ubuntu label in a comment, on the
# runs-on line or on a line of its own, used to satisfy a substring test.
STD_EXPR="\${{ github.event.repository.private \&\& fromJSON('[\"self-hosted\",\"linux\",\"x64\"]') || 'ubuntu-latest' }}"
mkconsumer
sed -i "s/^\(    \)runs-on: .*/\1runs-on: [self-hosted] # runs-on: ${STD_EXPR}/" "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 self-hosted runner behind a trailing comment holding the expression -> FAIL" 1 "$T6_RUNNER"

mkconsumer
sed -i "s/^\(    \)runs-on: .*/\1# runs-on: ${STD_EXPR}\n\1runs-on: [self-hosted]/" "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 self-hosted runner under a comment line holding the expression -> FAIL" 1 "$T6_RUNNER"

mkconsumer
sed -i 's/^\(    \)runs-on: .*/\1# runs-on: ubuntu-latest\n\1runs-on: [self-hosted]/' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 self-hosted runner under a comment line naming ubuntu -> FAIL" 1 "$T6_RUNNER"

# A comment on the job id line used to empty the extracted job, which skipped every job check.
mkconsumer; sed -i 's/^  docs-conventions:$/  docs-conventions: # required check/' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 comment on the job id line, standard runner -> PASS" 0
sed -i 's/^\(    \)runs-on: .*/\1runs-on: [self-hosted, evil]/' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 comment on the job id line, self-hosted runner -> FAIL" 1 "$T6_RUNNER"

mkconsumer
python3 - "$tmp/.github/workflows/conventions.yml" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index("  docs-conventions:")
open(p, "w").write(s[:i] + "  docs-conventions: {name: docs-conventions, runs-on: [self-hosted], steps: [{run: 'true'}]}\n")
PY
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 job written as a flow mapping -> FAIL" 1 "the docs-conventions job cannot be read"

# Another spelling of the real key, with a plain decoy key inside a block scalar of a step.
for real in 'runs-on : [self-hosted]' '"runs-on": [self-hosted]'; do
  mkconsumer
  python3 - "$tmp/.github/workflows/conventions.yml" "$real" <<'PY'
import re, sys
p, real = sys.argv[1], sys.argv[2]; s = open(p).read()
s = re.sub(r"(?m)^(    )runs-on: .*$", lambda m: m.group(1) + real, s, count=1)
s = re.sub(r"(?m)^(        run: \|\n)", r"\1          runs-on: ubuntu-latest\n", s, count=1)
open(p, "w").write(s)
PY
  ( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
  expect_report "T6 real key spelled '${real%%:*}:' with a decoy in a block scalar -> FAIL" 1 "$T6_RUNNER"
done

for label in ubuntu-evil ubuntu; do
  mkconsumer; sed -i "s/^\(    \)runs-on: .*/\1runs-on: ${label}/" "$tmp/.github/workflows/conventions.yml"
  ( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
  expect_report "T6 runs-on: ${label} is not a GitHub-hosted label -> FAIL" 1 "$T6_RUNNER"
done
mkconsumer; sed -i 's/^\(    \)runs-on: .*/\1runs-on: ubuntu-24.04/' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 runs-on: ubuntu-24.04 -> PASS" 0

mkconsumer
printf '  shadow:\n    name: docs-conventions\n    runs-on: [self-hosted]\n    steps:\n      - run: echo green\n' \
  >> "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect_report "T6 second job in the same workflow named docs-conventions -> FAIL" 1 "is named docs-conventions"

mkconsumer
printf 'on:\n  pull_request:\njobs:\n  anything:\n    name: docs-conventions # always green\n    runs-on: [self-hosted]\n    steps:\n      - run: true\n' \
  > "$tmp/.github/workflows/decoy.yml"
expect_report "T6 decoy workflow whose name: line carries a comment -> FAIL" 1 "another workflow declares a docs-conventions check"

mkconsumer; sed -i 's/^  docs-conventions:/  renamed-job:/' "$tmp/.github/workflows/conventions.yml"
expect "T6 required job renamed -> FAIL" 1

mkconsumer
printf 'on:\n  pull_request:\njobs:\n  docs-conventions:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' \
  > "$tmp/.github/workflows/decoy.yml"
expect "T6 decoy workflow emitting the same check name -> FAIL" 1

mkconsumer
sed -i 's|bash harness/check-conventions.sh|bash harness/check-conventions.sh \|\| true|' "$tmp/.github/workflows/conventions.yml"
expect "T6 convention check neutered with a discard -> FAIL" 1

mkconsumer
printf '\n  push:\n    paths-ignore:\n      - "**.md"\n' >> "$tmp/.github/workflows/conventions.yml"
expect "T6 paths-ignore filter added -> FAIL" 1

# T5: the guard content is edited after install, so the recorded hash no longer matches.
mkconsumer; printf '\n# weakened\nexit 0\n' >> "$tmp/harness/check-conventions.sh"
expect "T5 checker body edited after install -> FAIL" 1

# Regenerating the manifest is the documented deliberate path, so it passes again. The point
# of T5 is that the change becomes a visible, reviewable diff, not that it is impossible.
mkconsumer; printf '\n# weakened\n' >> "$tmp/harness/check-conventions.sh"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T5 manifest deliberately regenerated -> PASS" 0

mkconsumer; rm -f "$tmp/harness/MANIFEST.sha256"
expect "T5 manifest absent -> WARN only, PASS" 0

# The fail-open the adversarial review found: verifying only what the manifest LISTS means that
# deleting one line exempts that guard file from integrity checking forever. Coverage must be
# asserted in both directions.
mkconsumer
sed -i '2i exit 0   # neutered' "$tmp/harness/githooks/pre-commit"
sed -i '\#harness/githooks/pre-commit$#d' "$tmp/harness/MANIFEST.sha256"
expect "T5 guard neutered AND its manifest line deleted -> FAIL (coverage)" 1

mkconsumer
sed -i '\#\.github/workflows/conventions\.yml$#d' "$tmp/harness/MANIFEST.sha256"
expect "T5 workflow manifest line deleted -> FAIL (coverage)" 1

# A manifest with no trailing newline must not drop its last entry.
mkconsumer
printf '%s' "$(cat "$tmp/harness/MANIFEST.sha256")" > "$tmp/harness/MANIFEST.sha256.tmp"
mv "$tmp/harness/MANIFEST.sha256.tmp" "$tmp/harness/MANIFEST.sha256"
expect "T5 manifest without a trailing newline still verifies fully -> PASS" 0

# Self-mode gates T4/T8/T9 off, so it must not be reachable by planting empty files.
mkconsumer
: > "$tmp/VERSION"; mkdir -p "$tmp/docs"; : > "$tmp/docs/00-overview.md"; : > "$tmp/harness/install.sh"
printf '# no managed block\n' > "$tmp/CLAUDE.md"
expect "T4 cannot be disabled by spoofing playbook self-mode -> FAIL" 1

# T6 must scope to the docs-conventions job: a second job with an ubuntu runner must not satisfy
# the runner check while docs-conventions itself runs somewhere it controls.
mkconsumer
python3 - "$tmp/.github/workflows/conventions.yml" <<'PY'
import re,sys
p=sys.argv[1]; s=open(p).read()
s=re.sub(r"^    runs-on: .*$","    runs-on: self-hosted",s,count=1,flags=re.M)
s+="\n  decoy-other:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n"
open(p,"w").write(s)
PY
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 self-hosted docs-conventions job with an ubuntu sibling -> FAIL" 1

# A checker merely NAMED in the job (a comment) must not satisfy "the job runs it".
mkconsumer
sed -i 's#bash harness/check-conventions.sh#echo "would run harness/check-conventions.sh"#' \
  "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 checker mentioned but never invoked -> FAIL" 1

# A discard written as anything other than `|| true` must still be caught.
mkconsumer
sed -i 's#bash harness/check-conventions.sh#bash harness/check-conventions.sh || echo advisory#' \
  "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash "$HARNESS/make-manifest.sh" >/dev/null 2>&1 )
expect "T6 result discarded with a non-true fallback -> FAIL" 1

# A decoy job whose emitted context comes from `name:` rather than the job id.
mkconsumer
printf 'on:\n  pull_request:\njobs:\n  something-else:\n    name: docs-conventions\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' \
  > "$tmp/.github/workflows/decoy2.yml"
expect "T6 decoy job using name: docs-conventions -> FAIL" 1

# ---- T7 also requires each checker's self-test (docs/00 D6) --------------------
# The infra checker shipped for months with no test. It was report-only until v0.7.0, so its
# silence was indistinguishable from a clean repo, which is exactly why the pair must be enforced
# together.
#
# The fixtures below are STUBS rather than copies of the real files, and that is load-bearing.
# T7 tests PRESENCE, not content, and this self-test is itself distributed: copying from $HARNESS
# assumed the running repo owns a file that a non-infra consumer never receives, so the cp failed,
# the fixture was built without the checker, and the case reported FAIL in every non-infra consumer
# while conventions.yml runs this very script as a hard step. A stub keeps each case testing the
# RULE and keeps the file valid in the playbook and in every consumer, infra or not.
stub() { printf '#!/usr/bin/env bash\n# stub fixture standing in for %s\nexit 0\n' "$1" > "$tmp/harness/$1"; }

mkconsumer; stub check-infra-conformance.sh; stub test-check-infra-conformance.sh
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T7 infra checker with its self-test -> PASS" 0

mkconsumer; stub check-infra-conformance.sh
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T7 infra checker present but its self-test deleted -> FAIL" 1

# A repo with no infra checker must not be asked for the infra test.
mkconsumer
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T7 no infra checker, so no infra test required -> PASS" 0

# ---- T6 the infra checker blocks where it is installed (v0.7.0) -------------------
# It was report-only, so its step carried `|| echo ::warning`. Module code, module sources and PAT
# access are FAIL rules now, so an infra repo must run it, and no invocation may discard its result.
mkconsumer; stub check-infra-conformance.sh; stub test-check-infra-conformance.sh
sed -i 's#bash harness/check-infra-conformance.sh \.$#bash harness/check-infra-conformance.sh . || echo "::warning::advisory"#' \
  "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T6 the infra result discarded the old report-only way -> FAIL" 1

mkconsumer; stub check-infra-conformance.sh; stub test-check-infra-conformance.sh
sed -i 's#bash harness/check-infra-conformance.sh#echo harness/check-infra-conformance.sh#' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T6 an infra repo whose workflow never invokes the infra checker -> FAIL" 1

mkconsumer
sed -i 's#bash harness/check-infra-conformance.sh#echo harness/check-infra-conformance.sh#' "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T6 a repo without the infra checker is not asked to invoke it -> PASS" 0

# ---- the installer pair, which is playbook-only ---------------------------------
# harness/install.sh is not distributed, so a consumer has neither it nor harness/test-install.sh.
# That is what makes both the T5 coverage entry and the T7 pairing below no-ops in a consumer, and
# it is the property that has to hold for the same checker to be valid in both repos.
mkconsumer
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T5/T7 a consumer with no installer is not asked for harness/test-install.sh -> PASS" 0

# Same stub discipline: a consumer has no harness/install.sh to copy from. The rule keys on the
# installer's content, so the stub carries the marker string and nothing else.
pbinstaller() { printf '#!/usr/bin/env bash\n# playbook guard-set install (stub fixture)\n' > "$tmp/harness/install.sh"; }

mkconsumer; pbinstaller; stub test-install.sh
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T7 installer with its self-test -> PASS" 0

mkconsumer; pbinstaller
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T7 installer present but its self-test missing -> FAIL" 1

# Keyed on content, so a consumer's own unrelated installer demands nothing.
mkconsumer
printf '#!/usr/bin/env bash\n# this project has its own deploy installer\n' > "$tmp/harness/install.sh"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T7 an unrelated harness/install.sh does not demand the playbook self-test -> PASS" 0

# The installer itself is manifest-covered, because the marker string inside it is what T7 above,
# the self-detection at the top of the checker, and the workflow's installer step all key on. One
# unguarded literal switching off three gates is the shape the manifest exists to remove. Coverage
# is keyed on the same marker, so the unrelated-installer case above stays a PASS.
mkconsumer; pbinstaller; stub test-install.sh
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T5 the playbook installer is covered by the manifest -> PASS" 0

mkconsumer; pbinstaller; stub test-install.sh
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
sed -i '\#harness/install\.sh$#d' "$tmp/harness/MANIFEST.sha256"
expect "T5 the installer's own manifest line deleted -> FAIL (coverage)" 1

# And the coverage direction: with the installer's self-test present, deleting only its manifest
# line must FAIL, exactly as it does for every other guard file.
mkconsumer; pbinstaller; stub test-install.sh
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
sed -i '\#harness/test-install\.sh$#d' "$tmp/harness/MANIFEST.sha256"
expect "T5 the installer self-test's manifest line deleted -> FAIL (coverage)" 1

# ---- T10 / T12 are advisory and must stay advisory -----------------------------
# Both describe debt a brownfield repo legitimately carries on day one. If either became a FAIL,
# adopting the standard would freeze the repo it was meant to improve, so the WARN level is the rule
# rather than an oversight, and it needs a test of its own to stay that way.
mkconsumer
printf 'node_modules/\n.env\n.env.*\n_handoff/\n/playbook/\n' > "$tmp/.gitignore"
printf '{ "name": "x" }\n' > "$tmp/package.json"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T10/T12 missing build-artifact ignores and verify script -> WARN only, PASS" 0

# ---- T4 the managed block must CARRY the rules, not just the markers -----------
# Marker presence alone used to satisfy T4. That was tolerable while the block only pointed at
# the documents; now that it states the rules, an emptied body silently removes every rule an
# agent would have loaded, and the guard reported PASS on exactly that state.
mkconsumer
python3 - "$tmp/CLAUDE.md" <<'PY'
import io, re, sys
p = sys.argv[1]
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'(playbook-standard:start[^\n]*-->\n).*?(<!-- playbook-standard:end)', r'\1\2', s, flags=re.S)
io.open(p, 'w', encoding='utf-8').write(s)
PY
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T4 markers present but the block body emptied -> FAIL" 1

# And the block the installer actually writes must satisfy it, or T4 is a permanent failure.
mkconsumer
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T4 the block as installed carries the rules -> PASS" 0

# ---- T13 the workflow must actually trigger on this repo's branches ------------
# The blind spot this closes: T6 checks the workflow's CONTENT, and every one of its cases
# passed on a repo where the workflow never ran at all, because the trigger list was
# [develop, master] and the trunk was `main`. No run means no check to require, so no gate,
# and the guard reported PASS throughout. The fixture's trunk is `main` (D44).
mkconsumer
sed -i 's/branches: \[develop, main, master\]/branches: [develop, master]/' \
  "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T13 trunk is main but the workflow only lists develop/master -> FAIL" 1

# The same repo with main covered must pass, or T13 would just be a permanent failure.
mkconsumer
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T13 the shipped trigger list covers main -> PASS" 0

# A repo that opted out of CI has no workflow to reason about, so T13 stays quiet rather than
# reporting a missing gate the owner deliberately declined.
mkconsumer
sed -i 's/branches: \[develop, main, master\]/branches: [develop, master]/' \
  "$tmp/.github/workflows/conventions.yml"
printf 'no CI on this repo\n' > "$tmp/harness/ci-optout"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T13 is silent when CI is opted out -> PASS" 0

# The block-sequence spelling of the same list must be read too. Reading only the `branches:`
# LINE caught the flow form and saw nothing at all in the equivalent block form, so T13 FAILed
# a hand-written or pre-existing workflow whose trigger list was in fact correct.
mkconsumer
python3 - "$tmp/.github/workflows/conventions.yml" <<'PYSEQ'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding='utf-8').read()
s=s.replace("    branches: [develop, main, master]",
            "    branches:\n      - develop\n      - main\n      - master")
io.open(p,'w',encoding='utf-8').write(s)
PYSEQ
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T13 reads the YAML block-sequence branch list -> PASS" 0

# And the block form must still FAIL when the trunk really is absent from it.
mkconsumer
python3 - "$tmp/.github/workflows/conventions.yml" <<'PYSEQ2'
import io,sys
p=sys.argv[1]; s=io.open(p,encoding='utf-8').read()
s=s.replace("    branches: [develop, main, master]",
            "    branches:\n      - develop\n      - master")
io.open(p,'w',encoding='utf-8').write(s)
PYSEQ2
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T13 block-sequence list missing the trunk -> FAIL" 1

# ---- T5 coverage must include the infra self-test -----------------------------
# Deleting a manifest LINE used to exempt that file from tamper detection forever, and the
# coverage assertion that closes it listed every guard file except this one, so the infra
# checker's own self-test could be edited freely with no signal at all.
mkconsumer
cp "$HARNESS/check-infra-conformance.sh" "$tmp/harness/check-infra-conformance.sh"
cp "$HARNESS/test-check-infra-conformance.sh" "$tmp/harness/test-check-infra-conformance.sh"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
expect "T5 an infra consumer with a complete manifest -> PASS" 0

mkconsumer
cp "$HARNESS/check-infra-conformance.sh" "$tmp/harness/check-infra-conformance.sh"
cp "$HARNESS/test-check-infra-conformance.sh" "$tmp/harness/test-check-infra-conformance.sh"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
sed -i '/test-check-infra-conformance\.sh/d' "$tmp/harness/MANIFEST.sha256"
printf '\n# neutered\n' >> "$tmp/harness/test-check-infra-conformance.sh"
expect "T5 infra self-test edited AND its manifest line deleted -> FAIL" 1

# ---- T14 the live workflow must match the template it ships -------------------
# The two silently diverged once already: a trigger-list fix landed in harness/conventions.yml
# and never reached .github/workflows/conventions.yml, so this repository's own gate kept a
# pull_request branch filter the template had deliberately dropped. T13 could not see it (the
# push list was correct) and T5 hashes the live file against itself.
#
# The fixture is playbook-SELF shaped, because that is the only shape holding both files.
# A consumer never receives harness/conventions.yml, harness/install.sh or docs/, so this
# fixture can only be built where those exist. In a consumer the two T14 cases are skipped
# rather than failed: the rule they test is playbook-only by construction, and a self-test
# that cannot run must say so instead of reporting a defect that is not there.
SELF_OK=1
for f in conventions.yml install.sh test-install.sh check-infra-conformance.sh test-check-infra-conformance.sh; do
  [ -f "$HARNESS/$f" ] || SELF_OK=0
done
[ -f "$HARNESS/../docs/00-overview.md" ] || SELF_OK=0

mkself() {
  mkconsumer
  for f in conventions.yml install.sh test-install.sh check-infra-conformance.sh test-check-infra-conformance.sh; do
    cp "$HARNESS/$f" "$tmp/harness/$f"
  done
  mkdir -p "$tmp/docs"; cp "$HARNESS/../docs/00-overview.md" "$tmp/docs/00-overview.md"
  printf 'v0.2.0\n' > "$tmp/VERSION"
  ( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
}

if [ "$SELF_OK" = 1 ]; then
  mkself
  expect "T14 the live workflow matches the template -> PASS" 0

  mkself
  printf '\n# drifted\n' >> "$tmp/.github/workflows/conventions.yml"
  ( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )   # so this is T14, not T5
  expect "T14 the live workflow diverged from the template -> FAIL" 1
else
  echo "  SKIP T14 (playbook-only rule; this harness has no template or docs/ to build a self fixture)"
fi

# ---- T15 the guard must be committed, not merely present ----------------------
# An untracked workflow never runs: GitHub reads workflows from the repository, so a
# conventions.yml in the working tree is a file rather than a gate, and every instruction that
# begins "after the workflow has reported once" is unreachable. Presence and tracking are
# different questions and only presence was ever asked, so a consumer could sit at tier 0 while
# every local signal said tier 2.
mkconsumer
( cd "$tmp" && git add -A >/dev/null 2>&1 && git -c user.email=t@t.local -c user.name=t commit -q -m "chore: guard" >/dev/null 2>&1 )
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
( cd "$tmp" && git add harness/MANIFEST.sha256 >/dev/null 2>&1 && git -c user.email=t@t.local -c user.name=t commit -q -m "chore: manifest" >/dev/null 2>&1 )
expect "T15 a committed guard set -> PASS" 0

mkconsumer
( cd "$tmp" && git add -A >/dev/null 2>&1 && git -c user.email=t@t.local -c user.name=t commit -q -m "chore: guard" >/dev/null 2>&1 )
( cd "$tmp" && git rm --cached -q .github/workflows/conventions.yml >/dev/null 2>&1 )
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
# WARN rather than FAIL, so rc stays 0: in CI everything is tracked by construction, and the
# only window where this can fire is between installing the guard and committing it.
out="$( cd "$tmp" && bash "$CHK" . 2>&1 )"
if grep -q 'T15 a guard file exists but is not tracked' <<< "$out"; then
  echo "  PASS T15 the workflow present but untracked -> WARN"
else
  echo "  FAIL T15 the workflow present but untracked -> WARN (rule did not fire)"; fails=1
fi

# ---- T16 the Korean writing style is installed ---------------------------------
# A WARN, so rc stays 0; the assertion is on the report line itself.
t16() { # label expect(yes|no) [env...]
  local out; out="$( cd "$tmp" && env -u CI -u GITHUB_ACTIONS "${@:3}" bash "$CHK" . 2>&1 )"
  if grep -q 'T16' <<< "$out"; then got=yes; else got=no; fi
  if [ "$got" = "$2" ]; then echo "  PASS $1"; else echo "  FAIL $1 (T16 reported: $got)"; fails=1; fi
}
# ks_install - the Korean writing style's files in this working copy, without any hook wired.
ks_install() {
  mkdir -p "$tmp/.korean-style/scripts/hooks"
  : > "$tmp/.korean-style/rules.md"; : > "$tmp/.korean-style/scripts/hooks/pretooluse.mjs"
}
# ks_hooks FILE - wire its two hooks into FILE, the way its installer writes them.
ks_hooks() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' '{"hooks": {' \
    '  "PreToolUse": [{"hooks": [{"type": "command", "command": "node \"$CLAUDE_PROJECT_DIR/.korean-style/scripts/hooks/pretooluse.mjs\""}]}],' \
    '  "Stop": [{"hooks": [{"type": "command", "command": "node \"$CLAUDE_PROJECT_DIR/.korean-style/scripts/hooks/stop.mjs\""}]}]' \
    '}, "outputStyle": "korean-style"}' > "$1"
}
mkconsumer
t16 "T16 a repo without .korean-style/rules.md is reported" yes
mkconsumer; ks_install; ks_hooks "$tmp/.claude/settings.json"
t16 "T16 an installed Korean style is not reported" no
mkconsumer; mkdir -p "$tmp/.korean-style"; : > "$tmp/.korean-style/rules.md"
t16 "T16 a fresh clone without the Korean scripts is reported" yes
t16 "T16 the missing scripts are not reported under CI, where they are never present" no CI=true
# Scripts that no hook calls never run, and Claude Code reads hooks from either settings file.
mkconsumer; ks_install
t16 "T16 installed scripts with no hook wired are reported" yes
t16 "T16 but not under CI, where the scripts are never present" no CI=true
mkconsumer; ks_install; ks_hooks "$tmp/.claude/settings.local.json"
t16 "T16 hooks in .claude/settings.local.json are accepted" no

# ---- public repository mode (harness/public-repo, docs/22 s7) ---------------------
# check_says LABEL EXPECTED_RC yes|no TEXT [ENV...] - the exit code, and whether a report line
# carrying TEXT was printed. Runs as a local working copy unless the ENV names CI.
check_says() {
  local label="$1" want="$2" should="$3" text="$4" out got seen=no; shift 4
  out="$( cd "$tmp" && env -u CI -u GITHUB_ACTIONS "$@" bash "$CHK" . 2>&1 )"; got=$?
  grep -qF -- "$text" <<< "$out" && seen=yes
  if [ "$got" = "$want" ] && [ "$seen" = "$should" ]; then
    echo "  PASS $label (rc=$got)"
  else
    echo "  FAIL $label (rc=$got, expected $want; \"$text\" printed: $seen, expected $should)"; fails=1
  fi
}
public_on() {
  printf '%s\n' '# public repository marker (test fixture)' "${1-outside contributors commit to this repository}" \
    > "$tmp/harness/public-repo"
}
as_owner()       { git -C "$tmp" config user.name nerdkim; git -C "$tmp" config user.email me@nerd.kim; }
as_contributor() { git -C "$tmp" config user.name 'Jane Contributor'; git -C "$tmp" config user.email jane@example.com; }
# public_layout - what the installer leaves in a public repository: the managed block moved from
# CLAUDE.md into CLAUDE.local.md, the rest of CLAUDE.md kept, and both personal files gitignored.
public_layout() {
  python3 - "$tmp" <<'PYPUB'
import io, os, re, sys
root = sys.argv[1]
text = io.open(os.path.join(root, "CLAUDE.md"), encoding="utf-8").read()
block = re.search(r"<!-- playbook-standard:start -->\n.*?<!-- playbook-standard:end -->\n", text, flags=re.S).group(0)
io.open(os.path.join(root, "CLAUDE.local.md"), "w", encoding="utf-8").write("# personal\n\n" + block)
io.open(os.path.join(root, "CLAUDE.md"), "w", encoding="utf-8").write("# fixture\n\nPublic guidance for contributors.\n")
PYPUB
  printf 'CLAUDE.local.md\n.claude/settings.local.json\n' >> "$tmp/.gitignore"
  public_on
}

mkconsumer; public_layout; rm -f "$tmp/CLAUDE.local.md"
check_says "public: CI, where CLAUDE.local.md never exists, passes a CLAUDE.md without the block" 0 no "T4" CI=true
check_says "public: and the Korean writing style is not asked for in CI" 0 no "T16" CI=true
mkconsumer; public_layout; rm -f "$tmp/CLAUDE.local.md"; as_contributor
check_says "public: a contributor's clone passes without T4 or T16 reminders" 0 no "T16"
check_says "public: and hears nothing about the owner's CLAUDE.local.md" 0 no "CLAUDE.local.md"
mkconsumer; public_layout; rm -f "$tmp/CLAUDE.local.md"; as_owner
check_says "public: the owner's clone without CLAUDE.local.md is reminded (WARN)" 0 yes "T4 public repository: no managed block in CLAUDE.local.md"
mkconsumer; public_layout; as_owner
check_says "public: the owner's clone with the block in CLAUDE.local.md passes without a T4 line" 0 no "T4"
mkconsumer; public_layout
python3 - "$tmp/CLAUDE.local.md" <<'PYTHIN'
import io, re, sys
p = sys.argv[1]; s = io.open(p, encoding="utf-8").read()
io.open(p, "w", encoding="utf-8").write(re.sub(r"(playbook-standard:start[^\n]*-->\n).*?(<!-- playbook-standard:end)", r"\1\2", s, flags=re.S))
PYTHIN
check_says "public: an emptied block in CLAUDE.local.md -> FAIL" 1 yes "T4 the managed block in CLAUDE.local.md carries only"
mkconsumer; public_on; printf 'CLAUDE.local.md\n.claude/settings.local.json\n' >> "$tmp/.gitignore"
check_says "public: CLAUDE.md still carrying the personal block -> FAIL" 1 yes "T4 public repository: CLAUDE.md carries the personal managed block" CI=true
check_says "public: and the same holds locally" 1 yes "T4 public repository: CLAUDE.md carries the personal managed block"
mkconsumer; public_layout; rm -f "$tmp/AGENTS.md"
check_says "public: T3 still requires the AGENTS.md alias -> FAIL" 1 yes "T3 AGENTS.md must be a symlink to CLAUDE.md" CI=true

# Without the marker CLAUDE.local.md does not count: a private repository keeps the block in CLAUDE.md.
mkconsumer; public_layout; rm -f "$tmp/harness/public-repo"
check_says "private: the block only in CLAUDE.local.md -> FAIL" 1 yes "T4 CLAUDE.md has no playbook managed block"
mkconsumer; sed -n '/playbook-standard:start/,/playbook-standard:end/p' "$tmp/CLAUDE.md" > "$tmp/CLAUDE.local.md"
check_says "private: a block left in CLAUDE.local.md is reported (WARN)" 0 yes "T4 CLAUDE.local.md still carries a managed block"

# The marker narrows two gates, so a marker that cannot be read FAILs and grants nothing.
mkconsumer; public_layout; public_on ""
check_says "public: a marker with no reason -> FAIL (T17), and T4 wants the block back" 1 yes "T17 harness/public-repo states no reason" CI=true
check_says "public: the unusable marker turns the mode off" 1 yes "T4 CLAUDE.md has no playbook managed block" CI=true

# T17: nothing personal may be committed.
mkconsumer; public_layout; ( cd "$tmp" && git add -f CLAUDE.local.md )
check_says "public: a tracked CLAUDE.local.md -> FAIL" 1 yes "CLAUDE.local.md is tracked by git" CI=true
mkconsumer; public_layout; grep -v 'CLAUDE.local.md' "$tmp/.gitignore" > "$tmp/gi"; mv "$tmp/gi" "$tmp/.gitignore"
check_says "public: CLAUDE.local.md not gitignored -> FAIL" 1 yes "CLAUDE.local.md is not gitignored" CI=true
mkconsumer; public_layout; ks_hooks "$tmp/.claude/settings.json"
check_says "public: the Korean hooks in the shared settings -> FAIL" 1 yes "runs the Korean writing style hooks" CI=true
check_says "public: and its output style there -> FAIL" 1 yes "selects the owner's Korean output style" CI=true
mkconsumer; public_layout; mkdir -p "$tmp/.claude"
printf '{"attribution": {"commit": "Co-Authored-By: mikdren <bot-sidekick@nerd.kim>", "pr": ""}}\n' > "$tmp/.claude/settings.json"
check_says "public: the owner's co-author in the shared settings -> FAIL" 1 yes "names the owner's co-author" CI=true
mkconsumer; public_layout; mkdir -p "$tmp/.claude"
printf '{"permissions": {"allow": ["Bash(ls:*)"]}}\n' > "$tmp/.claude/settings.json"
check_says "public: shared settings without personal entries pass" 0 no "T17" CI=true
mkconsumer; public_layout; printf '\nKorean text: \xea\xb8\xb0\xeb\x8a\xa5\n' >> "$tmp/CLAUDE.md"
check_says "public: Korean text in CLAUDE.md is named (WARN)" 0 yes "T17 public repository: CLAUDE.md contains Korean text" CI=true

# T16 in a public repository: the owner's working copy only, with the hooks in the local file.
mkconsumer; public_layout; as_owner; ks_install; ks_hooks "$tmp/.claude/settings.local.json"
check_says "public: the owner's Korean hooks in settings.local.json pass" 0 no "T16"
mkconsumer; public_layout; as_owner; ks_install
check_says "public: the owner's Korean scripts with no local hooks are reported (WARN)" 0 yes "T16 public repository: the Korean writing style hooks are not in .claude/settings.local.json"
mkconsumer; public_layout; as_owner
check_says "public: the owner's clone without the Korean style is reported (WARN)" 0 yes "T16 public repository: the Korean writing style is not installed"
mkconsumer; public_layout; as_contributor
check_says "public: a contributor's clone is never asked for the Korean style" 0 no "T16"

# ---- T13 and a work branch -------------------------------------------------------
# A short-lived branch is not a trunk: its pull requests are checked by the unfiltered
# pull_request trigger. With a remote default, that default is the trunk T13 checks.
t13repo() { # DEFAULT_BRANCH -> a committed fixture with origin/HEAD naming DEFAULT_BRANCH, on feature/x
  ( cd "$tmp" && git add -A >/dev/null 2>&1 \
      && git -c user.email=t@t.local -c user.name=t commit -q -m "chore: guard" >/dev/null 2>&1 \
      && git update-ref "refs/remotes/origin/$1" HEAD \
      && git symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$1" \
      && git checkout -q -b feature/x )
}
mkconsumer; t13repo develop
check_says "T13 a work branch checked out while origin's default is covered -> PASS" 0 no "T13"
mkconsumer; t13repo trunk
check_says "T13 origin's default missing from the push list -> FAIL" 1 yes "trunk (origin's default branch, the workflow ignores it)"
mkconsumer; ( cd "$tmp" && git checkout -q -b trunk )
check_says "T13 with no remote default, the checked-out branch still counts -> FAIL" 1 yes "trunk (checked out now, the workflow ignores it)"

# main is the expected trunk of every repository, so it must be on the list before the branch
# exists: renaming master to main on GitHub is one step, and a list without main would leave the
# repository with no gate from that moment.
mkconsumer
( cd "$tmp" && git symbolic-ref HEAD refs/heads/develop )
sed -i 's/branches: \[develop, main, master\]/branches: [develop, master]/' \
  "$tmp/.github/workflows/conventions.yml"
( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
check_says "T13 main missing from the list before the branch exists -> FAIL" 1 yes "main (the trunk of every repository, D44"

# master is retired (D44). A repository that has not renamed it keeps its gate, because the push
# list carries master until every consumer has migrated, and it is told to rename. One on main is not.
mkconsumer; t13repo master
check_says "T13 a repo whose default is still master keeps its gate -> PASS" 0 no "the workflow ignores it"
check_says "T13 and is told to rename master to main (WARN)" 0 yes "T13 this repo still has a master branch"
mkconsumer; ( cd "$tmp" && git checkout -q -b master )
check_says "T13 a local master left in a clone is reported too (WARN)" 0 yes "T13 this repo still has a master branch"
mkconsumer; t13repo main
check_says "T13 a repo on main hears nothing about master" 0 no "master branch"

# ---- T11 the prepare script wires the hooks of a fresh clone ---------------------
# install-playbook.sh [4b] chains `bash harness/bootstrap-hooks.sh` onto prepare, and that script
# sets core.hooksPath itself. T11 looked for the literal core.hooksPath only, so every project the
# installer had wired heard that it had no prepare script.
t11pkg() {
  mkconsumer
  printf '%s\n' "$1" > "$tmp/package.json"
  ( cd "$tmp" && bash harness/make-manifest.sh . >/dev/null 2>&1 )
}
t11pkg '{ "name": "x", "scripts": { "prepare": "bash harness/bootstrap-hooks.sh", "verify": "pnpm check" } }'
check_says "T11 prepare runs harness/bootstrap-hooks.sh -> no prepare warning" 0 no "T11 package.json has no prepare script"
t11pkg '{ "name": "x", "scripts": { "prepare": "git config core.hooksPath harness/githooks", "verify": "pnpm check" } }'
check_says "T11 prepare sets core.hooksPath itself -> no prepare warning" 0 no "T11 package.json has no prepare script"
t11pkg '{ "name": "x", "scripts": { "verify": "pnpm check" } }'
check_says "T11 no prepare script -> WARN, still PASS" 0 yes "T11 package.json has no prepare script"

# T18: every Linux job goes through the runner expression (D50, D72). A hosted x64 label is named,
# a reasoned `# hosted-runner:` keeps it quietly, and other operating systems, arm64 and matrix
# values are not this check's business.
t18wf() { printf 'on: push\njobs:\n  build:\n    runs-on: %s\n    steps:\n      - run: echo hi\n' "$1" > "$tmp/.github/workflows/app.yml"; git -C "$tmp" add -A; }
mkconsumer
check_says "T18 the fixture's own workflow uses the expression -> no T18" 0 no "T18"
t18wf 'ubuntu-latest'
check_says "T18 a job on ubuntu-latest -> WARN, still PASS" 0 yes "T18 a Linux job names a GitHub-hosted runner"
t18wf 'ubuntu-24.04   # pinned image'
check_says "T18 a pinned ubuntu image with a plain comment -> WARN" 0 yes "app.yml:4: runs-on: ubuntu-24.04"
t18wf 'ubuntu-latest  # hosted-runner: its services need Docker'
check_says "T18 a hosted label kept with a reason -> no T18" 0 no "T18"
t18wf 'ubuntu-latest  # hosted-runner:'
check_says "T18 a marker without a reason still warns" 0 yes "T18 a Linux job names a GitHub-hosted runner"
t18wf "\${{ github.event.repository.private && fromJSON('[\"self-hosted\",\"linux\",\"x64\"]') || 'ubuntu-24.04' }}"
check_says "T18 the standard expression with another fallback -> no T18" 0 no "T18"
for label in macos-latest windows-2022 ubuntu-24.04-arm '${{ matrix.os }}'; do
  t18wf "$label"
  check_says "T18 runs-on: $label is not reported" 0 no "T18"
done
mkconsumer; public_layout; as_owner; t18wf 'ubuntu-latest'
check_says "T18 a public repository is skipped" 0 no "T18"

echo ""
if [ "$fails" = 0 ]; then echo "ALL TESTS PASSED"; exit 0; else echo "SOME TESTS FAILED"; exit 1; fi
