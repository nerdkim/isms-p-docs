#!/usr/bin/env bash
# test-check-standard-conformance.sh - self-test for the security checker (docs/00 D6).
# Builds throwaway git fixtures and asserts the checker's exit code (0 PASS, 1 FAIL).
set -uo pipefail
CHK="$(cd "$(dirname "$0")" && pwd)/check-standard-conformance.sh"
# Every fixture lives under one work root that the EXIT trap removes. The trap used to see only the
# last fixture, so each run stranded one directory per case in the system TMPDIR.
WORK="$(mktemp -d)" || { echo "mktemp -d failed" >&2; exit 2; }
tmp=""; cleanup() { rm -rf -- "$WORK"; }; trap cleanup EXIT
fails=0
mkrepo() {
  [ -n "$tmp" ] && rm -rf "$tmp"
  tmp="$(mktemp -d "$WORK/repo.XXXXXX")"; ( cd "$tmp" && git init -q -b main )
}
rc() { ( cd "$tmp" && bash "$CHK" . >/dev/null 2>&1 ); echo $?; }
expect() { # label expected-rc
  local got; got="$(rc)"
  if [ "$got" = "$2" ]; then echo "  PASS $1 (rc=$got)"; else echo "  FAIL $1 (rc=$got, expected $2)"; fails=1; fi
}
# reports LABEL EXPECTED-RC yes|no TEXT - the exit code, and whether the report carries TEXT. A WARN
# rule exits 0 whether or not it fired, so its cases must read the report itself.
reports() {
  local out got seen=no
  out="$( cd "$tmp" && bash "$CHK" . 2>&1 )"; got=$?
  grep -qF -- "$4" <<< "$out" && seen=yes
  if [ "$got" = "$2" ] && [ "$seen" = "$3" ]; then echo "  PASS $1 (rc=$got)"
  else echo "  FAIL $1 (rc=$got, expected $2; \"$4\" reported: $seen, expected $3)"; fails=1; fi
}

echo "== test-check-standard-conformance =="

mkrepo; printf 'export const x = 1\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "clean repo -> PASS" 0

mkrepo; printf 'SECRET=1\n' > "$tmp/.env"; ( cd "$tmp" && git add -f .env )
expect "committed .env -> FAIL" 1

mkrepo; printf 'const k = "AKIA1234567890ABCDEF"\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "AKIA literal -> FAIL" 1

mkrepo; printf 'policy = "arn:aws:iam::aws:policy/AdministratorAccess"\n' > "$tmp/x.tf"; ( cd "$tmp" && git add -A )
expect "admin managed policy -> FAIL" 1

mkrepo; printf 'resource "aws_iam_openid_connect_provider" "g" {}\n' > "$tmp/o.tf"; ( cd "$tmp" && git add -A )
expect "IaC creates OIDC provider -> FAIL" 1

mkrepo
printf 'data "aws_iam_openid_connect_provider" "g" {}\nsub = "repo:nerdkim/p:ref:refs/heads/develop"\n' > "$tmp/o.tf"
( cd "$tmp" && git add -A )
expect "data-source OIDC + specific sub -> PASS" 0

mkrepo; printf 'const y = z as any\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "gate-bypass token (WARN only) -> PASS" 0
w1out="$( cd "$tmp" && bash "$CHK" . 2>&1 )"
if grep -q 'a.ts:1:' <<< "$w1out"; then
  echo "  PASS W1 reports 'as any'"
else
  echo "  FAIL W1 missed 'as any'"; fails=1
fi

# A type whose name starts with Any is a cast to that type, not the any escape hatch (W1 is
# case-insensitive, so 'as AnyValueMap' used to match).
mkrepo; printf 'attributes: attributes as AnyValueMap,\nconst y = z as any;\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
w1out="$( cd "$tmp" && bash "$CHK" . 2>&1 )"
if grep -q 'a.ts:1:' <<< "$w1out"; then
  echo "  FAIL W1 reported a cast to AnyValueMap"; fails=1
elif grep -q 'a.ts:2:' <<< "$w1out"; then
  echo "  PASS W1 skips 'as AnyValueMap' and still reports 'as any;'"
else
  echo "  FAIL W1 missed 'as any;' next to a typed cast"; fails=1
fi

# ---- S8 OIDC trust must assert both aud and sub -------------------------------
mkrepo
printf 'action = "sts:AssumeRoleWithWebIdentity"\ncondition { variable = "token.actions.githubusercontent.com:aud" }\n' > "$tmp/t.tf"
( cd "$tmp" && git add -A )
expect "web-identity trust with aud but no sub -> FAIL" 1

mkrepo
printf 'action = "sts:AssumeRoleWithWebIdentity"\nvariable = "token.actions.githubusercontent.com:aud"\nvariable2 = "token.actions.githubusercontent.com:sub"\nvalues = ["repo:nerdkim/p:ref:refs/heads/develop"]\n' > "$tmp/t.tf"
( cd "$tmp" && git add -A )
expect "web-identity trust with both aud and sub -> PASS" 0

mkrepo; printf 'data "aws_iam_openid_connect_provider" "g" {}\n' > "$tmp/t.tf"; ( cd "$tmp" && git add -A )
expect "provider reference without a trust block -> PASS (S8 not triggered)" 0

# ---- S9 admin-equivalent grant ------------------------------------------------
mkrepo
printf 'statement {\n  "Action" = "*"\n  "Resource" = "*"\n}\n' > "$tmp/p.tf"
( cd "$tmp" && git add -A )
expect "Action * with Resource * -> FAIL" 1

mkrepo; printf 'statement { "NotAction" = ["iam:*"] }\n' > "$tmp/p.tf"; ( cd "$tmp" && git add -A )
expect "NotAction complement grant -> FAIL" 1

mkrepo
printf 'statement {\n  "Action" = ["s3:GetObject"]\n  "Resource" = "*"\n}\n' > "$tmp/p.tf"
( cd "$tmp" && git add -A )
expect "narrow action with Resource * -> PASS (S9 needs both wildcards)" 0

# ---- S10 key-based AWS auth in a workflow ------------------------------------
mkrepo; mkdir -p "$tmp/.github/workflows"
printf 'jobs:\n  x:\n    steps:\n      - uses: aws-actions/configure-aws-credentials@v4\n        with:\n          aws-access-key-id: xxx\n' > "$tmp/.github/workflows/ci.yml"
( cd "$tmp" && git add -A )
expect "access-key auth in a workflow -> FAIL" 1

mkrepo; mkdir -p "$tmp/.github/workflows"
printf 'permissions:\n  id-token: write\njobs:\n  x:\n    steps:\n      - uses: aws-actions/configure-aws-credentials@v4\n        with:\n          role-to-assume: arn:aws:iam::1:role/r\n' > "$tmp/.github/workflows/ci.yml"
( cd "$tmp" && git add -A )
expect "OIDC role-to-assume in a workflow -> PASS" 0

# ---- S15 pull_request_target never gets an OIDC token ------------------------------
# A fork can open the event, the run gets the base repository's permissions, and every repository
# of the owner shares one role pair, so the pairing is banned outright and no waiver lifts it.
s15wf() { mkrepo; mkdir -p "$tmp/.github/workflows"; printf '%b' "$1" > "$tmp/.github/workflows/w.yml"; ( cd "$tmp" && git add -A ); }
s15wf 'on:\n  pull_request_target:\npermissions:\n  id-token: write\n  contents: read\njobs: {}\n'
expect "S15 pull_request_target with id-token: write -> FAIL" 1
s15wf 'on: [push, pull_request_target]\npermissions: write-all\njobs: {}\n'
expect "S15 pull_request_target with write-all, which includes id-token -> FAIL" 1
s15wf 'on:\n  pull_request_target:\njobs:\n  label:\n    permissions:\n      id-token: write\n    steps: []\n'
expect "S15 a job-level id-token: write under pull_request_target -> FAIL" 1
s15wf 'on:\n  pull_request_target:\npermissions:\n  contents: read\n  pull-requests: write\njobs: {}\n'
expect "S15 pull_request_target without id-token -> PASS" 0
s15wf 'on:\n  pull_request:\npermissions:\n  id-token: write\njobs: {}\n'
expect "S15 pull_request with id-token: write -> PASS" 0
s15wf 'on:\n  pull_request_target:\npermissions:\n  # id-token: write\n  contents: read\njobs: {}\n'
expect "S15 a commented-out id-token line configures nothing -> PASS" 0
s15wf '# conformance-allow: we only label pull requests here\non:\n  pull_request_target:\npermissions:\n  id-token: write\njobs: {}\n'
expect "S15 a waiver does not lift it -> FAIL" 1
s15wf 'on:\n  issue_comment:\n    types: [created]\npermissions:\n  id-token: write\njobs: {}\n'
expect "S15 issue_comment with id-token: write -> FAIL" 1
s15wf 'on:\n  workflow_run:\n    workflows: [ci]\n    types: [completed]\njobs:\n  deploy:\n    permissions:\n      id-token: write\n    steps: []\n'
expect "S15 workflow_run with a job-level id-token: write -> FAIL" 1
s15wf 'on:\n  issue_comment:\npermissions:\n  issues: write\njobs: {}\n'
expect "S15 issue_comment without id-token -> PASS" 0

# ---- S11 Cognito / symmetric JWT --------------------------------------------
mkrepo; printf 'resource "aws_cognito_user_pool" "u" {}\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "Cognito user pool -> FAIL" 1

mkrepo; printf 'const alg = "HS256"\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "HS256 symmetric signing -> FAIL" 1

mkrepo; printf 'const alg = "RS256"\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "RS256 signing -> PASS" 0

# ---- S12 token in web storage ------------------------------------------------
mkrepo; printf "localStorage.setItem('accessToken', t)\n" > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "access token in localStorage -> FAIL" 1

mkrepo; printf "localStorage.setItem('theme', 'dark')\n" > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "theme preference in localStorage -> PASS" 0

# ---- S13 Secrets Manager -----------------------------------------------------
mkrepo; printf 'resource "aws_secretsmanager_secret" "s" {}\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "Secrets Manager secret -> FAIL" 1

mkrepo; printf 'resource "aws_ssm_parameter" "s" { type = "SecureString" }\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "SSM SecureString parameter -> PASS" 0

# ---- S14 literal provider token in IaC ---------------------------------------
# A synthetic non-secret literal, long enough to match the 20-char threshold.
mkrepo; printf 'provider "cloudflare" { api_token = "abcdefghijklmnopqrstuvwxyz0123" }\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "literal provider api_token -> FAIL" 1

mkrepo; printf 'provider "cloudflare" { api_token = var.cloudflare_api_token }\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "api_token from a variable -> PASS" 0

# ---- W3 / W4 stay advisory ---------------------------------------------------
mkrepo; printf 'import OpenAI from "openai"\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "direct AI provider SDK (WARN only) -> PASS" 0
reports "W3 names the two sanctioned routes" 0 yes "direct AI provider SDK; route AI through Bedrock or Cloudflare Workers AI"

# Cloudflare Workers AI is a sanctioned route again since v0.10.12 (D67), so its packages pass.
mkrepo; printf 'import { Ai } from "@cloudflare/ai"\nimport { createWorkersAI } from "workers-ai-provider"\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
reports "W3 the Cloudflare Workers AI packages are not reported" 0 no "a.ts:"

# Another provider's SDK still is.
mkrepo; printf 'import Anthropic from "@anthropic-ai/sdk"\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
reports "W3 still reports another provider's SDK" 0 yes "a.ts:1:"

# A Workers AI model id names its maker (`@cf/openai/...` is Whisper on the Cloudflare route), not an
# SDK in the app, so neither the code nor the infra setting is reported (found in language-study).
mkrepo; printf 'const stt = "@cf/openai/whisper-large-v3-turbo"\n' > "$tmp/a.ts"
printf 'CF_STT_MODEL = "@cf/openai/whisper-large-v3-turbo"\n' > "$tmp/a.hcl"; ( cd "$tmp" && git add -A )
reports "W3 a Workers AI model id of an OpenAI model is not reported" 0 no "a.ts:"
reports "W3 a Workers AI model id in infra is not reported" 0 no "a.hcl:"

# The OpenAI package is still reported on a line that also names such a model.
mkrepo; printf 'import OpenAI from "openai" // not @cf/openai/whisper-large-v3-turbo\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
reports "W3 the OpenAI package beside a Workers AI model id is still reported" 0 yes "a.ts:1:"

mkrepo; printf 'runtime = "nodejs20.x"\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "nodejs20.x runtime (WARN only) -> PASS" 0

# W4 compares against LAMBDA_NODE_MIN, the one written Node version, instead of a list of old ones.
if grep -qx 'LAMBDA_NODE_MIN=nodejs24.x' "$CHK"; then echo "  PASS W4 LAMBDA_NODE_MIN is defined at nodejs24.x"
else echo "  FAIL W4 LAMBDA_NODE_MIN=nodejs24.x is not defined in the checker"; fails=1; fi
mkrepo; printf 'runtime = "nodejs22.x"\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
reports "W4 a runtime older than the minimum is reported" 0 yes "a.tf:1:"
mkrepo; printf 'runtime = "nodejs24.x"\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
reports "W4 the minimum runtime itself is not reported" 0 no "Lambda Node runtime older"
mkrepo; printf 'runtime = "nodejs26.x"\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
reports "W4 a newer runtime than the minimum is not reported" 0 no "Lambda Node runtime older"
mkrepo; printf 'runtimes = ["nodejs26.x", "nodejs22.x"]\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
reports "W4 a list that still carries an old runtime is reported" 0 yes "a.tf:1:"

# ---- W2 without CloudFront ------------------------------------------------------
# One CloudFront distribution in front of the S3 site and the API is the standard edge since
# v0.7.0, so it left the free-tier list. The rest of the list still warns.
mkrepo; printf 'resource "aws_cloudfront_distribution" "edge" {\n  enabled = true\n}\n' > "$tmp/e.tf"; ( cd "$tmp" && git add -A )
reports "W2 CloudFront is no longer reported" 0 no "free-tier forbidden resource"
mkrepo; printf 'resource "aws_eip" "ip" {}\n' > "$tmp/e.tf"; ( cd "$tmp" && git add -A )
reports "W2 an Elastic IP still is" 0 yes "free-tier forbidden resource"

# ---- false negatives the adversarial review found ----------------------------
# S9 must match the aws_iam_policy_document form, which is the style these projects actually use.
mkrepo
printf 'data "aws_iam_policy_document" "p" {\n  statement {\n    actions   = ["*"]\n    resources = ["*"]\n  }\n}\n' > "$tmp/p.tf"
( cd "$tmp" && git add -A )
expect "S9 lowercase actions/resources wildcard pair -> FAIL" 1

# A NotAction under Deny is legitimately restrictive and must not be flagged.
mkrepo
printf 'statement {\n  effect    = "Deny"\n  NotAction = ["s3:GetObject"]\n}\n' > "$tmp/p.tf"
( cd "$tmp" && git add -A )
expect "S9 NotAction under Deny -> PASS (restrictive, not a grant)" 0

# S8 must not accept ':subnet' as the ':sub' claim.
mkrepo
printf 'action = "sts:AssumeRoleWithWebIdentity"\nsubnet_id = "subnet-123"\nvariable = "token.actions.githubusercontent.com:aud"\n' > "$tmp/t.tf"
( cd "$tmp" && git add -A )
expect "S8 subnet_id does not satisfy the sub claim -> FAIL" 1

# S6 must catch a managed policy name with an underscore before FullAccess.
mkrepo; printf 'policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "S6 AWSLambda_FullAccess -> FAIL" 1

# S12 must catch an uppercase constant key.
mkrepo; printf 'localStorage.setItem(ACCESS_TOKEN, t)\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "S12 uppercase token constant in localStorage -> FAIL" 1

# S3/S14 must see a committed tfvars file.
mkrepo; printf 'aws_key = "AKIA1234567890ABCDEF"\n' > "$tmp/prod.tfvars"; ( cd "$tmp" && git add -A )
expect "S3 AKIA literal in a .tfvars file -> FAIL" 1

# S10 must see key auth inside a composite action, not only a workflow.
mkrepo; mkdir -p "$tmp/.github/actions/setup"
printf 'runs:\n  using: composite\n  steps:\n    - run: echo $AWS_SECRET_ACCESS_KEY\n' > "$tmp/.github/actions/setup/action.yml"
( cd "$tmp" && git add -A )
expect "S10 key auth in a composite action -> FAIL" 1

# S14 must catch a bare `token = "..."` provider attribute.
mkrepo; printf 'provider "x" { token = "abcdefghijklmnopqrstuvwxyz0123" }\n' > "$tmp/a.tf"; ( cd "$tmp" && git add -A )
expect "S14 bare token attribute literal -> FAIL" 1

# A file whose name begins with a dash must not disable every grep-based rule.
mkrepo; printf 'const k = "AKIA1234567890ABCDEF"\n' > "$tmp/-dash.ts"; ( cd "$tmp" && git add -A )
expect "S3 still fires when a filename starts with a dash -> FAIL" 1

# ---- rules that had no fixture until now (S2, S4, S7, W2) ---------------------
# Each is a P0 FAIL that shipped untested. They were verified by hand to fire, but an untested rule
# is one edit away from silently not running, which is how the [0] fence-count bug reached a commit.
mkrepo
printf 'const pem = `-----BEGIN RSA PRIVATE KEY-----\nMIIEow\n-----END RSA PRIVATE KEY-----`\n' > "$tmp/k.ts"
( cd "$tmp" && git add -A )
expect "S2 plaintext private key -> FAIL" 1

mkrepo; printf 'resource "aws_iam_access_key" "ci" { user = "ci" }\n' > "$tmp/i.tf"; ( cd "$tmp" && git add -A )
expect "S4 IaC creates an IAM access key -> FAIL" 1

mkrepo; printf 'values = ["repo:nerdkim/*:*"]\n' > "$tmp/t.tf"; ( cd "$tmp" && git add -A )
expect "S7 org wildcard in an OIDC trust sub -> FAIL" 1

# ---- S7 a wildcard sub needs the owner-id pin (v0.7.0) ---------------------------
# One role pair now serves every repository of the owner, so `repo:nerdkim/*` is the design. It is
# safe exactly when the same trust also pins the immutable owner id; without the pin it FAILs as
# before. The pin is looked for in the policy block that holds the sub, so a pinned block elsewhere
# in the file cannot vouch for an unpinned one.
s7trust() { # FILE PIN(yes|comment|no) SUB-VALUES
  {
    printf 'data "aws_iam_policy_document" "trust" {\n  statement {\n    actions = ["sts:AssumeRoleWithWebIdentity"]\n'
    printf '    condition {\n      test     = "StringEquals"\n      variable = "token.actions.githubusercontent.com:aud"\n      values   = ["sts.amazonaws.com"]\n    }\n'
    case "$2" in
      yes)     printf '    condition {\n      test     = "StringEquals"\n      variable = "token.actions.githubusercontent.com:repository_owner_id"\n      values   = [var.github_owner_id]\n    }\n' ;;
      comment) printf '    # pin token.actions.githubusercontent.com:repository_owner_id here\n' ;;
    esac
    printf '    condition {\n      test     = "StringLike"\n      variable = "token.actions.githubusercontent.com:sub"\n      values   = %s\n    }\n  }\n}\n' "$3"
  } >> "$1"
}
mkrepo; s7trust "$tmp/trust.tf" yes '["repo:nerdkim/*", "repo:nerdkim@38360965/*"]'; ( cd "$tmp" && git add -A )
expect "S7 an owner wildcard with the repository_owner_id pin -> PASS" 0
mkrepo; s7trust "$tmp/trust.tf" yes '["repo:${var.github_owner}/*:ref:refs/heads/develop", "repo:${var.github_owner}@${var.github_owner_id}/*:environment:prod"]'
( cd "$tmp" && git add -A )
expect "S7 the module's interpolated subs with the pin -> PASS" 0
mkrepo; s7trust "$tmp/trust.tf" no '["repo:nerdkim@38360965/*"]'; ( cd "$tmp" && git add -A )
expect "S7 the immutable-id wildcard form without the pin -> FAIL" 1
mkrepo; s7trust "$tmp/trust.tf" no '["repo:${var.github_owner}/*"]'; ( cd "$tmp" && git add -A )
expect "S7 an interpolated owner wildcard without the pin -> FAIL" 1
mkrepo; s7trust "$tmp/trust.tf" comment '["repo:nerdkim/*"]'; ( cd "$tmp" && git add -A )
expect "S7 a pin that is only a comment pins nothing -> FAIL" 1
mkrepo; s7trust "$tmp/trust.tf" yes '["repo:nerdkim/app:ref:refs/heads/develop"]'
s7trust "$tmp/trust.tf" no '["repo:nerdkim/*"]'; ( cd "$tmp" && git add -A )
expect "S7 a pinned block does not vouch for an unpinned one in the same file -> FAIL" 1

# modules/aws/ci-roles derives every condition key from the provider ARN and builds the documents
# in one locals block, so neither the owner pin (S7) nor the aud and sub claims (S8) are spelled out
# with the host. Both must still be read; dropping the derived pin must still FAIL.
ciroles() { # PIN(yes|no)
  {
    printf 'locals {\n  oidc_host    = split(":oidc-provider/", var.oidc_provider_arn)[1]\n'
    printf '  sub_key      = "${local.oidc_host}:sub"\n  aud_key      = "${local.oidc_host}:aud"\n'
    [ "$1" = yes ] && printf '  owner_id_key = "${local.oidc_host}:repository_owner_id"\n'
    printf '  sub_prefixes = [\n    "repo:${var.github_owner}/*",\n    "repo:${var.github_owner}@${var.github_owner_id}/*",\n  ]\n'
    printf '  trust = {\n    Statement = [{\n      Action    = "sts:AssumeRoleWithWebIdentity"\n'
    printf '      Condition = { StringLike = { (local.sub_key) = local.sub_prefixes } }\n    }]\n  }\n}\n'
  } > "$tmp/main.tf"
}
mkrepo; ciroles yes; ( cd "$tmp" && git add -A )
expect "S7/S8 derived condition keys in one locals block, owner pinned -> PASS" 0
mkrepo; ciroles no; ( cd "$tmp" && git add -A )
expect "S7 the same module without the derived owner-id key -> FAIL" 1

# ---- Terraform test files ---------------------------------------------------------
# A module test asserts the very policies the rules forbid elsewhere, and declares no resource.
mkrepo; mkdir -p "$tmp/modules/aws/ci-roles/tests"
printf 'run "apply" {\n  assert {\n    condition     = aws_iam_role_policy_attachment.apply.policy_arn == "arn:aws:iam::aws:policy/AdministratorAccess"\n    error_message = "near admin"\n  }\n  variables { subs = ["repo:nerdkim/*"] }\n}\n' \
  > "$tmp/modules/aws/ci-roles/tests/ci-roles.tftest.hcl"
( cd "$tmp" && git add -A )
expect "a .tftest.hcl naming AdministratorAccess and a wildcard sub -> PASS" 0
mkrepo; mkdir -p "$tmp/modules/x/tests"
printf 'run "x" {\n  variables { key = "AKIA1234567890ABCDEF" }\n}\n' > "$tmp/modules/x/tests/x.tftest.hcl"
( cd "$tmp" && git add -A )
expect "a credential in a .tftest.hcl is still a credential (S3) -> FAIL" 1

mkrepo; printf 'resource "aws_nat_gateway" "n" { subnet_id = "subnet-1" }\n' > "$tmp/n.tf"; ( cd "$tmp" && git add -A )
expect "W2 free-tier forbidden resource (WARN only) -> PASS" 0

# ---- generated artifacts are out of scope (GENERATED_RE) ----------------------
# A lockfile records the whole transitive dependency graph, so a package that merely NAMES a
# forbidden client in its peer list is not a violation by this project. This exact case blocked the
# first commit of every freshly scaffolded monorepo.
mkrepo
printf 'export const x = 1\n' > "$tmp/a.ts"
printf "packages:\n  '@aws-sdk/client-secrets-manager': '>=3.x'\n" > "$tmp/pnpm-lock.yaml"
( cd "$tmp" && git add -A )
expect "S13 ignores a generated lockfile -> PASS" 0

mkrepo
printf 'import { SecretsManagerClient } from "@aws-sdk/client-secrets-manager"\n' > "$tmp/a.ts"
( cd "$tmp" && git add -A )
expect "S13 still fires on real code usage -> FAIL" 1

# An empty scan set is only an error when a file SHOULD have been scanned. A repo whose every
# tracked file is legitimately out of scope must pass rather than block the commit.
mkrepo
printf "packages:\n  a: 1\n" > "$tmp/pnpm-lock.yaml"
( cd "$tmp" && git add -A )
expect "every tracked file out of scope -> PASS, not a fail-closed error" 0

# ---- secret literals are scanned text-wide, not by extension ------------------
# The scan set used to be `*.ts|*.py|*.tf|...`, which made the extension list an accidental
# allowlist for credentials: the same key was a FAIL in app.ts and invisible in notes.txt.
mkrepo; printf 'key = AKIA1234567890ABCDEF\n' > "$tmp/notes.txt"; ( cd "$tmp" && git add -A )
expect "S3 in a .txt file -> FAIL" 1

mkrepo; printf '# readme\n\nAKIA1234567890ABCDEF\n' > "$tmp/README.md"; ( cd "$tmp" && git add -A )
expect "S3 in a .md file -> FAIL" 1

mkrepo; printf 'AWS_ACCESS_KEY_ID=AKIA1234567890ABCDEF\n' > "$tmp/.env.example"; ( cd "$tmp" && git add -A )
expect "S3 inside a committed .env.example -> FAIL" 1

mkrepo; printf 'ENV K=AKIA1234567890ABCDEF\n' > "$tmp/Dockerfile"; ( cd "$tmp" && git add -A )
expect "S3 in an extensionless Dockerfile -> FAIL" 1

mkrepo; printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3Blb\n' > "$tmp/deploykey"; ( cd "$tmp" && git add -A )
expect "S2 in an extensionless file -> FAIL" 1

# A placeholder must stay quiet: S14 requires a QUOTED long literal, so the usual unquoted
# `.env.example` form is not a finding.
mkrepo; printf 'CLOUDFLARE_API_TOKEN=replace-me-before-use\n' > "$tmp/.env.example"; ( cd "$tmp" && git add -A )
expect "unquoted .env.example placeholder -> PASS (S14 needs a quoted literal)" 0

# A Grafana Cloud token is recognised by its prefix, quoted or not; a short test fixture is not one.
mkrepo; printf 'GRAFANA_OTLP_TOKEN=glc_eyJvIjoiMTIzNDU2IiwibiI6InN0YWNrLXRva2VuIiwiayI6ImFiYyJ9\n' > "$tmp/.env.example"
( cd "$tmp" && git add -A )
expect "S14 Grafana Cloud access policy token -> FAIL" 1
mkrepo; printf 'const auth = "123456:glc_local-test-token";\n' > "$tmp/a.test.ts"; ( cd "$tmp" && git add -A )
expect "S14 short glc_ test fixture -> PASS" 0

# ---- policy-rule post-filters (comment / description / count guard / waiver) ----
# Regression set for the false positives that made the gate unusable on the very repos the
# standard is built on: the checker exited 1 on infra-modules citing six comment and
# description lines, a count-guarded resource, and the SSO permission set that docs/01 s6
# designates as standard. A gate that fails compliant configuration teaches `--no-verify`,
# so every filter is pinned in BOTH directions: it drops the inert match and it still
# catches the real one.

mkrepo; printf '# Note: no AdministratorAccess. Narrow to the services the stack uses.\n' > "$tmp/x.tf"
( cd "$tmp" && git add -A )
expect "S6 comment documenting compliance -> PASS" 0

mkrepo; printf 'variable "p" {\n  description = "Default AdministratorAccess for the admin set."\n  type = string\n}\n' > "$tmp/v.tf"
( cd "$tmp" && git add -A )
expect "S6 inside a Terraform description -> PASS" 0

mkrepo; printf 'variable "p" {\n  default = "arn:aws:iam::aws:policy/AdministratorAccess"\n}\n' > "$tmp/v.tf"
( cd "$tmp" && git add -A )
expect "S6 as a real variable default -> FAIL (description filter must not swallow it)" 1

# The guard sits BELOW the opener, which a backwards-only scan from the hit would miss.
mkrepo
printf 'resource "aws_iam_openid_connect_provider" "g" {\n  count = var.create_oidc_provider ? 1 : 0\n  url   = "https://token.actions.githubusercontent.com"\n}\n' > "$tmp/o.tf"
( cd "$tmp" && git add -A )
expect "S5 count-guarded provider -> PASS (reported WARN, conditional)" 0

mkrepo
printf 'resource "aws_iam_openid_connect_provider" "g" {\n  url = "https://token.actions.githubusercontent.com"\n}\n' > "$tmp/o.tf"
( cd "$tmp" && git add -A )
expect "S5 unguarded provider -> FAIL (guard filter must not swallow it)" 1

mkrepo
printf '# conformance-allow: this module IS the foundation-owned shared provider (docs/01 s6)\nresource "aws_iam_openid_connect_provider" "g" {\n  url = "x"\n}\n' > "$tmp/o.tf"
( cd "$tmp" && git add -A )
expect "reasoned waiver suppresses a policy rule -> PASS" 0

# The waiver must never reach a credential rule. If a stated reason could excuse a committed
# key, the gate would be advisory for the one class it exists to stop.
mkrepo
printf '# conformance-allow: we really need this key here\nconst k = "AKIA1234567890ABCDEF"\n' > "$tmp/a.ts"
( cd "$tmp" && git add -A )
expect "waiver does NOT suppress a credential rule (S3) -> FAIL" 1

mkrepo; printf '# AKIA1234567890ABCDEF was rotated\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
expect "credential rule ignores the comment filter (S3 in a comment) -> FAIL" 1

mkrepo
printf '# conformance-allow:\nresource "aws_iam_openid_connect_provider" "g" {\n  url = "x"\n}\n' > "$tmp/o.tf"
( cd "$tmp" && git add -A )
expect "reasonless waiver marker -> FAIL (suppresses nothing, and is itself reported)" 1

# A waiver counts only inside a comment. Prose that NAMES the mechanism is not a waiver:
# this checker's header, docs/21 and the CLAUDE.md history row all write the token in
# running text, and the first version reported all three as waivers in effect.
mkrepo
printf 'A line may carry `conformance-allow: <reason>` to waive a policy rule.\n' > "$tmp/doc.md"
( cd "$tmp" && git add -A )
w2out="$( cd "$tmp" && bash "$CHK" . 2>&1 )"
if grep -q 'waiver in effect' <<< "$w2out"; then
  echo "  FAIL prose naming the marker was reported as a live waiver"; fails=1
else
  echo "  PASS prose naming the marker is not a waiver"
fi

# ... and it does not silently waive a rule either.
mkrepo
printf 'see `conformance-allow: whatever`\nresource "aws_iam_openid_connect_provider" "g" {\n  url = "x"\n}\n' > "$tmp/o.tf"
( cd "$tmp" && git add -A )
expect "non-comment marker does NOT waive (S5 still fires) -> FAIL" 1

# W1 matches comment directives by design, so it must NOT be comment-filtered.
mkrepo; printf '// @ts-ignore\nconst y = 1\n' > "$tmp/a.ts"; ( cd "$tmp" && git add -A )
w1out="$( cd "$tmp" && bash "$CHK" . 2>&1 )"
if grep -q 'ts-ignore' <<< "$w1out"; then
  echo "  PASS W1 still reports a comment directive (not comment-filtered)"
else
  echo "  FAIL W1 comment directive was filtered away"; fails=1
fi

# ---- is_guarded is Terraform vocabulary and must not reach other languages ----
# `count`, `for_each`, `data`, `resource`, `module` are HCL. Applying the block-guard rule to
# every file type meant an ordinary Python or TypeScript file demoted a real S11/S12/S13
# finding from FAIL to "[conditional: only when its count/for_each variable is true]", which is
# a sentence with no meaning outside HCL, and the run exited 0. Renaming one local variable
# flipped the same file back to FAIL.
mkrepo
printf 'import jwt\ndef issue(payload):\n    data = dict(payload)\n    return jwt.encode(data, S, algorithm="HS256")\ndef retry(items):\n    count = 0\n    return count\n' > "$tmp/auth.py"
( cd "$tmp" && git add -A )
expect "S11 in Python with HCL-looking identifiers around it -> FAIL" 1

mkrepo
printf 'const data = {}\nlet count = 0\nlocalStorage.setItem("access_token", t)\n' > "$tmp/auth.ts"
( cd "$tmp" && git add -A )
expect "S12 in TypeScript with HCL-looking identifiers around it -> FAIL" 1

# The real HCL case must keep working: this is the shape the demotion exists for.
mkrepo
printf 'resource "aws_cognito_user_pool" "p" {\n  count = var.enable_cognito ? 1 : 0\n  name  = "p"\n}\n' > "$tmp/auth.tf"
( cd "$tmp" && git add -A )
expect "S11 in HCL behind a count guard -> PASS (WARN, conditional)" 0

# The enclosing block is the top-level one, which opens in column 0. An indented attribute named
# like a block keyword (`variable = ...` inside a condition) used to be taken for the opener, so the
# count guard of the real block was never seen.
mkrepo
printf 'data "aws_iam_policy_document" "p" {\n  count = var.enabled ? 1 : 0\n  statement {\n    condition {\n      variable = "aws:PrincipalArn"\n      values   = ["arn:aws:iam::aws:policy/AdministratorAccess"]\n    }\n  }\n}\n' > "$tmp/p.tf"
( cd "$tmp" && git add -A )
expect "S6 behind a count guard, below an indented variable attribute -> PASS (WARN, conditional)" 0

# An HCL block with no closing brace cannot be reasoned about, so the hit is reported rather
# than silenced by an invented 60-line window.
mkrepo
printf 'resource "aws_cognito_user_pool" "p" {\n  name = "p"\n' > "$tmp/auth.tf"
printf 'count = 1\n' >> "$tmp/auth.tf"
( cd "$tmp" && git add -A )
expect "S11 in an unclosed HCL block -> FAIL (undecidable is not guarded)" 1

echo ""
if [ "$fails" = 0 ]; then echo "ALL TESTS PASSED"; exit 0; else echo "SOME TESTS FAILED"; exit 1; fi
