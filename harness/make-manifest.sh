#!/usr/bin/env bash
# make-manifest.sh - record the hash of every installed guard file into
# harness/MANIFEST.sha256, which check-structure-conformance.sh [T5] verifies.
#
# Purpose: a guard is only as trustworthy as its own integrity. A one-line edit to
# check-conventions.sh, or a weakened commit-msg hook, silently disables a rule while every
# other check still reports green. The manifest turns that silent edit into a loud CI
# failure, and turns a deliberate change into a reviewable diff of this file.
#
# Honest limit: this is drift and casual-tamper detection, not a cryptographic signature.
# Whoever can edit a checker can also re-run this script. The value is that the manifest line
# changes too, so the weakening appears in the PR diff next to the edit instead of hiding
# inside a 200-line script. Together with the CI required check (which runs the checker) and
# branch protection, editing a guard stops being an invisible act.
#
# Run it:
#   - automatically, at the end of harness/install.sh, so a fresh install is always green
#   - manually, after deliberately changing a guard in the playbook repo:
#       bash harness/make-manifest.sh
#
# Usage: bash make-manifest.sh [ROOT]   (ROOT default = git root, else cwd)
set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd $ROOT" >&2; exit 2; }

command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum required" >&2; exit 2; }
[ -d harness ] || { echo "no harness/ directory at $ROOT" >&2; exit 2; }

OUT="harness/MANIFEST.sha256"

# Every guard file whose content must not drift. MANIFEST.sha256 itself is excluded (it
# cannot contain its own hash), and so are the marker files (commitmsg-strict, ci-optout,
# conventions-exclude, commit-gate-since, public-repo, corpus-repo, korean-content), which are per-repo
# policy the owner sets deliberately. Each is committed, so changing one still shows up in review, and
# the ones that narrow a gate (commit-gate-since, public-repo, corpus-repo, korean-content) refuse to
# grant anything without a stated reason.
# The personal files a public repository keeps (CLAUDE.local.md, .claude/settings.local.json) are
# gitignored and never part of the guard.
#
# Each entry is guarded by `[ -f harness/$f ]`, so a file that a given repo does not have is
# simply omitted rather than breaking the manifest. That is what lets playbook-only guards
# (conventions.yml, test-install.sh) and profile-only guards (the infra pair) share one list.
FILES=""
for f in lib.sh test-lib.sh bootstrap-hooks.sh verify.sh \
         check-conventions.sh test-check-conventions.sh \
         check-standard-conformance.sh test-check-standard-conformance.sh \
         check-commit-messages.sh test-check-commit-messages.sh \
         check-structure-conformance.sh test-check-structure-conformance.sh \
         check-infra-conformance.sh test-check-infra-conformance.sh \
         test-install.sh test-upgrade.sh test-branch-protection.sh migrate-agent-files.py make-manifest.sh gitmessage conventions.yml conventions-terms \
         docs-stop-hook.sh test-docs-stop-hook.sh ui-design-hook.sh test-ui-design-hook.sh \
         githooks/pre-commit githooks/commit-msg githooks/pre-push; do
  [ -f "harness/$f" ] && FILES="$FILES harness/$f"
done
# The playbook installer, keyed on CONTENT rather than name. It was the one guard file covered by
# nothing: the literal 'playbook guard-set install' is what check-structure-conformance.sh keys
# self-detection AND the T7 installer pairing on, and what conventions.yml keys its installer
# self-test step on, so editing that one string silences three gates at once. Nothing recorded its
# hash, so the edit left no trace of its own. Keying on the marker instead of the filename keeps a
# consumer's own unrelated harness/install.sh out of the manifest, exactly as T7 keys on it to
# avoid demanding a playbook self-test the consumer never received.
if [ -f harness/install.sh ] && grep -q 'playbook guard-set install' harness/install.sh 2>/dev/null; then
  FILES="$FILES harness/install.sh"
fi
# The live CI workflow is part of the guard: a weakened workflow is the highest-value edit.
for w in .github/workflows/conventions.yml .github/workflows/conventions.yaml; do
  [ -f "$w" ] && FILES="$FILES $w"
done

{
  printf '# playbook guard manifest. Verified by check-structure-conformance.sh [T5].\n'
  printf '# Regenerate deliberately with: bash harness/make-manifest.sh\n'
  printf '# A change here must accompany a real, reviewed change to the listed guard file.\n'
  # shellcheck disable=SC2086  # word splitting is the intended way to expand the file list
  sha256sum $FILES
} > "$OUT"

printf 'wrote %s (%s files)\n' "$OUT" "$(grep -cv '^#' "$OUT")"
