#!/usr/bin/env bash
# Verify installed guards from any working directory, without cloud access or git mutations.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SELF_TESTS=0
case "${1:-}" in
  '') ;;
  --self-tests) SELF_TESTS=1 ;;
  *) echo 'usage: bash harness/verify.sh [--self-tests]' >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo 'too many arguments' >&2; exit 2; }
if [ "$SELF_TESTS" -eq 1 ]; then
  # Every self-test removes what it creates, on failure too. Each one runs with a TMPDIR of its own,
  # and anything left in it fails the run, so a test that strands fixtures cannot pass unnoticed.
  scratch="$(mktemp -d)"
  trap 'rm -rf -- "$scratch"' EXIT
  run_clean() { # LABEL CMD...
    local label="$1" dir="$scratch/tmp"
    shift
    mkdir "$dir"
    TMPDIR="$dir" "$@"
    if [ -n "$(ls -A "$dir")" ]; then
      echo "FAIL: $label left files in its temporary directory:" >&2
      ls -A "$dir" | head -5 >&2
      exit 1
    fi
    rmdir "$dir"
  }
  for test_script in harness/test-*.sh; do
    [ -f "$test_script" ] || { echo 'self-tests are missing' >&2; exit 1; }
    run_clean "$test_script" bash "$test_script"
  done
  if grep -q 'playbook guard-set install' harness/install.sh 2>/dev/null; then
    run_clean scripts/test-bootstrap.py python3 scripts/test-bootstrap.py
    run_clean scripts/test-sync-standard.py python3 scripts/test-sync-standard.py
    run_clean scripts/test-sync-korean-style.py python3 scripts/test-sync-korean-style.py
    run_clean scripts/test-cf-token.py python3 scripts/test-cf-token.py
    run_clean scripts/test-release-pr.py python3 scripts/test-release-pr.py
    run_clean scripts/test-local-runner.py python3 scripts/test-local-runner.py
    run_clean scripts/test-repo-about.py python3 scripts/test-repo-about.py
    run_clean scripts/test-develop-pr.py python3 scripts/test-develop-pr.py
    run_clean templates/.github/scripts/test-ci-helpers.py python3 templates/.github/scripts/test-ci-helpers.py
    run_clean templates/.github/scripts/test-plan-guard.py python3 templates/.github/scripts/test-plan-guard.py
    run_clean templates/infra-foundation/test-bootstrap-auth.py python3 templates/infra-foundation/test-bootstrap-auth.py
    run_clean templates/infra-foundation/.github/scripts/test-ci-scripts.py python3 templates/infra-foundation/.github/scripts/test-ci-scripts.py
    run_clean templates/infra-foundation/.github/scripts/test-plan-guard.py python3 templates/infra-foundation/.github/scripts/test-plan-guard.py
    run_clean scripts/test-initialize.sh bash scripts/test-initialize.sh
    run_clean scripts/test-infra-templates.sh bash scripts/test-infra-templates.sh
    run_clean modules/aws/cloudfront-function/tests/viewer-request.test.mjs \
      node --test modules/aws/cloudfront-function/tests/viewer-request.test.mjs
  fi
fi
bash harness/check-structure-conformance.sh .
bash harness/check-conventions.sh
bash harness/check-standard-conformance.sh .
# Infra conformance blocks like the other checkers since v0.7.0; its WARN items stay advisory.
if [ -f harness/check-infra-conformance.sh ]; then
  bash harness/check-infra-conformance.sh .
fi
# No implicit history scan: CI and commit-msg pass their actual commit range/message.
printf '%s\n' 'Guard checks complete. Application tests and remote enforcement are separate checks.'
