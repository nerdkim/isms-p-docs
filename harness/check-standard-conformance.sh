#!/usr/bin/env bash
# check-standard-conformance.sh - the HARD security gate for the playbook standard.
#
# Scope: the consumer's own authored files. It deliberately does NOT scan docs/, _research/,
# harness/, templates/, or the ./playbook clone, because those hold rule text and example snippets
# that name forbidden patterns on purpose, nor generated artifacts and binaries (GENERATED_RE).
#
# Within that scope the scan set depends on what the rule is about:
#   - secret literals (S2/S3/S14) scan EVERY authored text file, including `.md`, `.txt`,
#     `Dockerfile`, `.env.example` and extensionless files. A credential does not care about the
#     file extension, so an extension allowlist there is an allowlist for credentials.
#   - rules about a language or file kind (IaC resources, workflow steps, TypeScript idioms) stay
#     scoped to that kind, where a match outside it would be meaningless noise.
#   - Terraform test files (*.tftest.hcl, *.tfmock.hcl) are left to the credential rules: they
#     assert what a module builds and cannot declare a resource of their own.
#
# Severity model (docs/20 s2, rollout owner-set):
#   FAIL = security P0. The checker exits nonzero. Merge blocking additionally requires
#          this CI job to be a required check, with effective branch protection and bypass controls.
#   WARN = P1. Reported only for now; promoted to FAIL once repos are clean.
#
# Two classes of rule, because they need different handling (see the post-filters below):
#   CREDENTIAL rules (S1/S2/S3/S10/S14/S15) are about a credential existing or being handed out.
#     They are never waivable, and their matches are never filtered by context: a key
#     pasted into a comment is still a key. S10 and S15 read workflow configuration, so a
#     commented-out line (which configures nothing) is skipped there, and nothing else is.
#   POLICY rules (S4 to S9, S11, S12, S13, W2 to W4) are about how infrastructure is
#     shaped. A match in a comment or a Terraform `description` is text ABOUT the rule
#     and is dropped; a match inside a block guarded by `count`/`for_each` is a
#     CONDITIONAL grant and is reported WARN rather than FAIL; and a line may carry
#     `conformance-allow: <reason>` to waive it, exactly as check-conventions.sh
#     supports `conventions-allow`. A marker with no reason waives nothing and FAILs.
#
# Rules (source doc in parentheses):
#   FAIL S1 tracked secret / ignored artifact committed (docs/12 s5.1)
#   FAIL S2 plaintext private key in any authored text file (docs/07 s6.1)
#   FAIL S3 AWS access key id literal AKIA... in any authored text file (docs/01 s5)
#   FAIL S4 IaC creates aws_iam_access_key; must use OIDC (docs/04 s1)
#   FAIL S5 project IaC creates the OIDC provider; must reference it (docs/04 s2)
#   FAIL S6 admin / managed *FullAccess policy on a role (docs/04 s3.4)
#   FAIL S7 org/repo wildcard in an OIDC trust sub, unless the same policy block pins a
#           repository_owner_id condition key (token.actions.githubusercontent.com:...) (docs/04 s3.2)
#   FAIL S8 OIDC trust policy does not assert both aud and sub (docs/04 s3.2)
#   FAIL S9 Action "*" together with Resource "*", or a NotAction/NotResource grant (docs/04 s3.4)
#   FAIL S10 key-based AWS auth in a workflow; CI to AWS is OIDC only (docs/04 s1.1)
#   FAIL S11 Cognito, or HS256 / JWT_SECRET symmetric auth (docs/05 s3.3, docs/07 s6)
#   FAIL S12 auth token written to localStorage / sessionStorage (docs/07 s6.3, docs/09 s4.2)
#   FAIL S13 AWS Secrets Manager; secrets live in SSM SecureString (docs/05 s6, docs/07 s5.3)
#   FAIL S14 literal provider API token in any authored text file (docs/01 s5.3)
#   FAIL S15 a workflow pairs pull_request_target, issue_comment or workflow_run with id-token: write (or write-all) (docs/04)
#   WARN W1 gate-bypass token: as any / @ts-ignore / @ts-nocheck / eslint-disable / .skip( (docs/20 s5)
#   WARN W2 free-tier forbidden resource (docs/01 s4.1); CloudFront is the standard edge since v0.7.0
#   WARN W3 direct AI provider SDK; AI goes through Bedrock or Cloudflare Workers AI (docs/19 s1)
#   WARN W4 Lambda Node runtime older than LAMBDA_NODE_MIN (docs/05 s4, docs/07 s1)
#
# Usage: bash check-standard-conformance.sh [ROOT]   (ROOT default = cwd)
# Requires GNU grep. Exit 1 on any FAIL, else 0.
set -uo pipefail

# The oldest Lambda Node runtime W4 accepts. The one Node version the standard writes down is the
# Lambda runtime id: the newest AWS GA nodejsNN.x. Raise this when AWS ships the next one (nodejs26.x
# is expected in November 2026); every older runtime then WARNs.
LAMBDA_NODE_MIN=nodejs24.x

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd $ROOT" >&2; exit 2; }
FAIL=0

EXCL='^(docs/|_research/|harness/|templates/|playbook/|node_modules/|\.git/|\.terraform)'

# Generated artifacts and binaries are out of scope for EVERY rule below: they are not authored
# code, so a match in one says nothing about what this project does. The lockfile case is the one
# that mattered. `pnpm-lock.yaml` records the whole transitive graph, so a dependency that merely
# NAMES `@aws-sdk/client-secrets-manager` in its peer list made S13 fail on a freshly scaffolded
# project that uses no such client, and the project's very first commit was blocked. Same list as
# check-conventions.sh GENERATED_RE, kept identical on purpose.
GENERATED_RE='\.(png|jpe?g|gif|ico|webp|avif|bmp|tiff?|woff2?|ttf|otf|eot|pdf|zip|gz|tgz|bz2|xz|7z|jar|so|dylib|dll|exe|wasm|mp3|mp4|mov|avi|webm|ogg|wav|class|pyc|o|a|bin|dat|db|sqlite3?)$|(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|poetry\.lock|uv\.lock|Cargo\.lock|Gemfile\.lock|composer\.lock|\.terraform\.lock\.hcl)$|\.min\.(js|css)$|\.map$'

# tracked + untracked-not-ignored, minus playbook-owned / vendor / generated paths.
# `-c core.quotePath=false` so a path containing non-ASCII characters is emitted literally rather
# than as an escaped \nnn string, which would never match a real filename and would silently drop
# that file from every scan below.
mapfile -t SRC < <( { git -c core.quotePath=false ls-files 2>/dev/null; \
                      git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null; } \
                    | grep -vE "$EXCL" | grep -vE "$GENERATED_RE" | grep . | sort -u )

code=(); iac=(); wf=()
for f in ${SRC+"${SRC[@]}"}; do
  # A Terraform test file asserts what a module builds (modules/*/tests/*.tftest.hcl since the
  # modules moved into the playbook in v0.7.0). It cannot declare a resource, and it names the
  # policies it checks on purpose, so the policy rules skip it. It stays in SRC: a credential pasted
  # into a test is still a credential.
  case "$f" in *.tftest.hcl|*.tfmock.hcl) continue ;; esac
  case "$f" in
    *.ts|*.tsx|*.js|*.mjs|*.cjs|*.py|*.tf|*.hcl|*.tfvars|*.json|*.yml|*.yaml|*.sh) code+=("$f");;
  esac
  case "$f" in *.tf|*.hcl|*.tfvars) iac+=("$f");; esac
  # A composite action carries the same key-auth risk as a workflow, so scan actions too.
  case "$f" in .github/workflows/*.yml|.github/workflows/*.yaml|.github/actions/*|*/action.yml|*/action.yaml) wf+=("$f");; esac
done

# Fail CLOSED on an empty scan set. Reporting PASS after examining nothing is the worst outcome for
# a security gate: it looks identical to a clean repo.
#
# But "empty" has two causes and only one is a defect. If a file SHOULD have survived the filters
# and did not, the listing itself broke (the case this guard exists for: a git that ignores
# `-c core.quotePath=false` returns escaped paths that match nothing downstream) and we must refuse.
# If instead every tracked file is legitimately out of scope (all under harness/, all generated),
# the empty set is the correct answer and erroring would block a clean repo's commits. Deciding by
# re-running the same filters over a plain listing separates the two.
if [ "${#SRC[@]}" -eq 0 ] && git rev-parse --git-dir >/dev/null 2>&1; then
  residual="$(git ls-files 2>/dev/null | grep -vE "$EXCL" | grep -vE "$GENERATED_RE" | grep -c . || true)"
  if [ "${residual:-0}" -gt 0 ]; then
    echo "ERROR: $residual tracked file(s) should have been scanned but the scan set is empty;" >&2
    echo "       refusing to report a pass (check git version / core.quotePath support)." >&2
    exit 2
  fi
fi

say() { printf '%s\n' "$*"; }

# grepf PATTERN FILE...  -> prints file:line matches (empty if no files)
# `--` ends option parsing: without it a single file named like `-x.ts` would be read as a grep
# option, grep would error out, and every rule built on grepf would report no hits.
# `-i` because these are pattern-name matches, not case-sensitive identifiers.
grepf() {
  local pat="$1"; shift
  [ "$#" -ge 1 ] || return 0
  grep -nHiE "$pat" -- "$@" 2>/dev/null
}

# grept PATTERN FILE...  -> the same, over EVERY authored text file rather than an extension
# allowlist. `-I` skips a binary that has no telltale extension instead of emitting a useless
# "Binary file matches" line.
#
# A secret does not care what the file is called. An `AKIA...` key pasted into `notes.txt`, a
# `README.md`, a `Dockerfile`, an extensionless script, or a committed `.env.example` used to pass
# this gate untouched, because the scan set was `*.ts|*.py|*.tf|...`. check-conventions.sh [1]
# closed exactly this gap for forbidden characters; leaving it open on the HIGHER-severity checker
# made the extension list an accidental allowlist for credentials. The secret-literal rules
# (S2/S3/S14) therefore scan text-wide, while the rules that are genuinely about a language or a
# file kind (IaC resources, workflow steps, TypeScript idioms) stay scoped to that kind.
grept() {
  local pat="$1"; shift
  [ "$#" -ge 1 ] || return 0
  grep -nHIiE "$pat" -- "$@" 2>/dev/null
}

# report SEV TITLE MATCHES  (sets FAIL when SEV=FAIL and MATCHES non-empty)
report() {
  local sev="$1" title="$2" out="$3"
  [ -n "$out" ] || return 0
  say "  [$sev] $title"
  printf '%s\n' "$out" | sed 's/^/    /'
  [ "$sev" = "FAIL" ] && FAIL=1
  return 0
}

# ---------------------------------------------------------------------------
# Post-filters for POLICY rules.
#
# A grep hit is `path:lineno:content`. Three things can make such a hit a non-violation.
# Each is handled here rather than by weakening the pattern, so the pattern keeps
# catching the real shape and only the provably-inert matches are removed.
#
#   drop_noise    the content is a comment or a Terraform `description`, i.e. text ABOUT
#                 the rule. `# Note: no AdministratorAccess.` is documentation of
#                 compliance and used to FAIL as a violation of it. Never applied to the
#                 credential rules: a secret in a comment is still exposed.
#   waived        the line, or the line above it, carries `conformance-allow: <reason>`.
#                 Never available to the credential rules, because the one thing that
#                 must never be waivable is a credential.
#   is_guarded    the enclosing resource/data/module block declares `count` or `for_each`,
#                 so the resource exists only when a variable says so. The documented
#                 reference form is exactly this (`create_oidc_provider = false`,
#                 docs/01 s2.3), as is the `use_admin_policy` escape hatch. A conditional
#                 grant is real, so it is reported WARN and not dropped: silence there
#                 would hide the day someone flips the variable to true.
#
# All three fail CLOSED. If a file cannot be read, the hit is reported rather than
# filtered away, on the same reasoning as the empty-scan guard above.
# ---------------------------------------------------------------------------

# drop_noise: stdin/stdout filter over `path:lineno:content` hits.
drop_noise() {
  awk '{
    line = $0
    p = index(line, ":");          if (p == 0) { print line; next }
    rest = substr(line, p + 1)
    q = index(rest, ":");          if (q == 0) { print line; next }
    c = substr(rest, q + 1)
    sub(/^[ \t]*/, "", c)
    if (c ~ /^(#|\/\/|\*|\/\*)/)          next   # comment line
    if (c ~ /^description[ \t]*=/)        next   # Terraform variable/output doc string
    print line
  }'
}

# A waiver only counts inside a COMMENT. Matching the bare token anywhere on a line makes
# any prose that explains the mechanism read as a live waiver: this checker's own header,
# docs/21, and the CLAUDE.md history row that introduced the feature all name
# `conformance-allow: <reason>` in running text, and all three were reported as waivers in
# effect the first time this shipped. Requiring the comment introducer also means a waiver
# can never be smuggled in through a string literal or a piece of rendered content.
WAIVER_RE='(^|[[:space:]])(#|//)[[:space:]]*conformance-allow:[[:space:]]*[^[:space:]]'
WAIVER_BARE_RE='(^|[[:space:]])(#|//)[[:space:]]*conformance-allow:?[[:space:]]*$'

# waived FILE LINENO -> 0 when a reasoned waiver covers that line.
waived() {
  local f="$1" n="$2" cur prev
  cur="$(sed -n "${n}p" -- "$f" 2>/dev/null)" || return 1
  prev=""
  [ "$n" -gt 1 ] && prev="$(sed -n "$((n - 1))p" -- "$f" 2>/dev/null)"
  # A here-string, not a pipe into grep -q: see check-structure-conformance.sh.
  grep -qE "$WAIVER_RE" <<< "$cur"$'\n'"$prev"
}

# is_guarded FILE LINENO -> 0 when the enclosing block declares count/for_each.
#
# The guard must be looked for across the WHOLE block, not just the part above the hit.
# HCL puts `count` on the line after the opener, so a backwards-only scan from the hit
# would miss the single most common shape there is:
#     resource "aws_iam_openid_connect_provider" "github" {   <- the hit is here
#       count = var.create_oidc_provider ? 1 : 0              <- the guard is here
# So: find the nearest opener at or above the hit, find where that block closes, and scan
# the range. If any step cannot resolve, the answer is "not guarded" and the hit is
# reported, never silently dropped.
#
# IaC ONLY. `count` and `for_each` are Terraform vocabulary and `resource`/`data`/`module`/
# `variable`/`output`/`locals`/`provider` are HCL block openers, but this ran on EVERY policy hit
# regardless of file type, and ordinary Python and TypeScript use those words as plain
# identifiers. A Python file with `data = dict(payload)` above the hit and `count = 0` anywhere
# in the following 60 lines demoted a real HS256 finding from FAIL to
# "[conditional: only when its count/for_each variable is true]", which is a sentence with no
# meaning outside HCL, and the run exited 0. Renaming that one local variable flipped the same
# file back to FAIL, which is not a property a security gate may have.
#
# block_range FILE LINENO -> "START,END", the top-level HCL block that encloses LINENO, or nothing
# when the shape cannot be resolved. Shared by is_guarded and the S7 owner pin, both of which ask a
# question about "the block this hit is in" and must resolve it the same way.
#
# A top-level block opens and closes in column 0 (terraform fmt writes it so, and the `^}` closer
# test below already relies on it). The opener used to be matched at any indent, which made an
# attribute such as `variable = "token.actions.githubusercontent.com:sub"` inside a condition {}
# read as a `variable` block, so "the enclosing block" began in the middle of the policy document.
# An opener written indented resolves to no block at all, which is the fail-closed answer.
block_range() {
  local f="$1" n="$2" opener end
  case "$f" in
    *.tf|*.tfvars|*.hcl) ;;
    *) return 0 ;;
  esac
  opener="$(awk -v w="$n" '
    NR <= w && /^(resource|data|module|variable|output|locals|inputs|provider)[[:space:]"({=]/ { o = NR }
    END { print o + 0 }' "$f" 2>/dev/null)" || return 0
  [ "${opener:-0}" -gt 0 ] || return 0
  # No `^}` closer means the block shape could not be resolved, so the answer is "not guarded".
  # The old `opener + 60` fallback invented a window out of nothing and let a `count =` sixty
  # lines away from an unrelated block silence the hit (fail-closed on undecidable, docs/20 s3).
  end="$(awk -v s="$opener" 'NR > s && /^\}/ { print NR; exit }' "$f" 2>/dev/null)"
  [ -n "$end" ] || return 0
  [ "$n" -le "$end" ] || return 0
  printf '%s,%s' "$opener" "$end"
}
is_guarded() {
  local r
  r="$(block_range "$1" "$2")"
  [ -n "$r" ] || return 1
  # grep -c reads the whole block, so sed never writes into a pipe grep already closed.
  [ "$(sed -n "${r}p" -- "$1" 2>/dev/null \
    | grep -cE '^[[:space:]]*(count|for_each)[[:space:]]*=')" -gt 0 ]
}

# owner_pinned FILE LINENO -> 0 when the OIDC trust around an S7 hit pins the GitHub owner by its
# immutable id: a repository_owner_id condition key appears outside a comment in the same top-level
# HCL block (the policy document, the role, or the locals that build both). The key may be written
# out (token.actions.githubusercontent.com:repository_owner_id) or derived from the provider, as
# modules/aws/ci-roles does with "${local.oidc_host}:repository_owner_id". A workflow file has no
# blocks, so there the whole file counts. An HCL block that cannot be resolved pins nothing, the
# fail-closed answer.
owner_pinned() {
  local f="$1" n="$2" r body
  case "$f" in
    *.tf|*.tfvars|*.hcl)
      r="$(block_range "$f" "$n")"
      [ -n "$r" ] || return 1
      body="$(sed -n "${r}p" -- "$f" 2>/dev/null)" ;;
    *) body="$(cat -- "$f" 2>/dev/null)" ;;
  esac
  [ -n "$(grep -vE '^[[:space:]]*(#|//|\*|/\*)' <<< "$body" \
    | grep -E ':repository_owner_id([^A-Za-z0-9_]|$)')" ]
}

# report_policy TITLE MATCHES - noise-filtered, waivable, guard-aware reporting.
report_policy() {
  local title="$1" out="$2" plain="" guarded="" line file rest no
  out="$(printf '%s\n' "$out" | grep . | drop_noise || true)"
  [ -n "$out" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    file="${line%%:*}"; rest="${line#*:}"; no="${rest%%:*}"
    # Synthetic `file: message` hits (S8/S9) have no line number; never filtered.
    case "$no" in ''|*[!0-9]*) plain="${plain}${line}"$'\n'; continue;; esac
    waived "$file" "$no" && continue
    if is_guarded "$file" "$no"; then guarded="${guarded}${line}"$'\n'
    else                             plain="${plain}${line}"$'\n'; fi
  done <<EOF
$out
EOF
  report FAIL "$title" "$(printf '%s' "$plain" | sed '/^$/d')"
  report WARN "$title [conditional: only when its count/for_each variable is true]" \
    "$(printf '%s' "$guarded" | sed '/^$/d')"
  return 0
}

say "== check-standard-conformance (security P0 = FAIL, P1 = WARN) =="

# S1: git-tracked secret / ignored artifact (committed). Tracked only.
s1="$( git ls-files 2>/dev/null | grep -vE "$EXCL" \
  | grep -E '(^|/)\.env(\.[A-Za-z0-9_-]+)?$|(^|/)[^/]*\.tfstate([.]|$)|(^|/)_handoff/|(^|/)node_modules/' \
  | grep -vE '(^|/)\.env\.example$' )"
report FAIL "tracked secret / ignored artifact committed (docs/12 s5.1)" "$s1"

# S2: plaintext private key, anywhere in authored text (see grept)
report FAIL "plaintext private key in source (docs/07 s6.1)" \
  "$(grept 'BEGIN [A-Z ]*PRIVATE KEY' ${SRC+"${SRC[@]}"})"

# S3: AWS access key id literal, anywhere in authored text (see grept)
report FAIL "AWS access key id literal, use OIDC (docs/01 s5)" \
  "$(grept 'AKIA[0-9A-Z]{16}' ${SRC+"${SRC[@]}"})"

# S4: IaC creates an IAM access key
report_policy "IaC creates aws_iam_access_key, use OIDC (docs/04 s1)" \
  "$(grepf 'resource[[:space:]]+\"aws_iam_access_key\"' ${iac+"${iac[@]}"})"

# S5: project IaC creates the OIDC provider (only foundation may; consumers reference it).
# The documented reference form is `count = var.create_oidc_provider ? 1 : 0` with the
# variable defaulting to false (docs/01 s2.3); report_policy reports that as WARN.
report_policy "project IaC creates the OIDC provider, reference it instead (docs/04 s2)" \
  "$(grepf 'resource[[:space:]]+\"aws_iam_openid_connect_provider\"' ${iac+"${iac[@]}"})"

# S6: admin / managed *FullAccess policy attached
report_policy "admin / managed *FullAccess policy (docs/04 s3.4)" \
  "$(grepf '(AdministratorAccess|PowerUserAccess|[A-Za-z]+_?FullAccess)' ${iac+"${iac[@]}"} ${wf+"${wf[@]}"})"

# S7: a wildcard in an OIDC trust sub. One role pair serves every repository of the owner since
# v0.7.0 (docs/04), so `repo:nerdkim/*` is the design, and it is safe exactly when the same trust
# also pins token.actions.githubusercontent.com:repository_owner_id: an owner NAME can be taken over
# after a rename or a deletion, the numeric owner id cannot. So a wildcard sub passes when its
# policy block pins the owner id (see owner_pinned) and FAILs otherwise. The owner part may be the
# immutable-id form GitHub uses for repositories created after 2026-07-15 (repo:nerdkim@38360965/*)
# or an interpolation (repo:${var.github_owner}/*); the old pattern could see neither.
s7=""
while IFS= read -r s7hit; do
  [ -n "$s7hit" ] || continue
  s7f="${s7hit%%:*}"; s7rest="${s7hit#*:}"; s7n="${s7rest%%:*}"
  owner_pinned "$s7f" "$s7n" && continue
  s7="${s7}${s7hit}"$'\n'
done <<EOF
$(grepf 'repo:\*|repo:[A-Za-z0-9_.@${}-]+/\*|repo:[A-Za-z0-9_.@${}-]+/[A-Za-z0-9_.-]*\*' ${wf+"${wf[@]}"} ${iac+"${iac[@]}"})
EOF
report_policy "org/repo wildcard in OIDC trust sub without a repository_owner_id pin (docs/04 s3.2)" \
  "$(printf '%s' "$s7" | sed '/^$/d')"

# S8: an OIDC trust policy must assert BOTH aud and sub. A trust that checks only the issuer
# would let ANY GitHub repository assume the role, which is the single worst OIDC mistake.
# Scoped to files that actually declare a web-identity trust, so a policy that merely names
# the provider does not false-positive. A condition key may also be derived from the provider
# ("${local.oidc_host}:sub", the shape modules/aws/ci-roles uses), hence the `:sub"` form.
s8=""
for f in ${iac+"${iac[@]}"}; do
  grep -q 'sts:AssumeRoleWithWebIdentity' "$f" 2>/dev/null || continue
  grep -qE 'githubusercontent\.com:sub|"sub"|:sub"|[^a-z]sub[^a-z]*=' "$f" 2>/dev/null \
     && grep -qE 'githubusercontent\.com:aud|"aud"|:aud"|[^a-z]aud[^a-z]*=' "$f" 2>/dev/null && continue
  s8="${s8}${f}: web-identity trust without both :aud and :sub"$'\n'
done
report_policy "OIDC trust policy must assert both aud and sub (docs/04 s3.2)" "$s8"

# S9: an admin-equivalent grant. Action "*" plus Resource "*" in the same file, or a
# NotAction / NotResource complement grant (which grants everything except a denylist).
s9=""
for f in ${iac+"${iac[@]}"} ${wf+"${wf[@]}"}; do
  if grep -qiE '"?actions?"?[[:space:]]*[:=][[:space:]]*\[?[[:space:]]*"\*"' "$f" 2>/dev/null \
     && grep -qiE '"?resources?"?[[:space:]]*[:=][[:space:]]*\[?[[:space:]]*"\*"' "$f" 2>/dev/null; then
    s9="${s9}${f}: Action \"*\" together with Resource \"*\""$'\n'
  fi
done
for f in ${iac+"${iac[@]}"}; do
  grep -qiE '"?(NotAction|NotResource)"?[[:space:]]*[:=]' "$f" 2>/dev/null || continue
  # A NotAction under Deny narrows access; under Allow it grants everything except a denylist.
  grep -qiE '"?effect"?[[:space:]]*[:=][[:space:]]*"?Deny' "$f" 2>/dev/null && continue
  s9="${s9}${f}: NotAction/NotResource complement grant"$'\n'
done
report_policy "admin-equivalent IAM grant (docs/04 s3.4)" "$(printf '%s' "$s9" | sed '/^$/d')"

# S10: key-based AWS auth in a workflow. CI to AWS is OIDC only (D5/D11), so an access-key
# input or secret in a workflow is a long-lived credential by definition.
# Comment-filtered (a commented-out step configures nothing) but NOT waivable: this rule is
# about a long-lived credential, which is the one class no reason may excuse.
report FAIL "key-based AWS auth in a workflow, use OIDC (docs/04 s1.1)" \
  "$(grepf '(aws-access-key-id|aws-secret-access-key|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY)' ${wf+"${wf[@]}"} | drop_noise)"

# S11: Cognito is not used (D3), and auth is self-issued RS256, so a symmetric secret
# (HS256 / JWT_SECRET) means the token signing model is wrong.
# Code that REJECTS a symmetric algorithm is the correct implementation of this very rule, so a
# line naming HS256 next to a rejection is dropped. Cognito matches are never filtered: there is no
# defensive way to declare a user pool.
s11_all="$(grepf '(aws_cognito_user_pool|@aws-sdk/client-cognito|CognitoIdentityProvider|HS256|JWT_SECRET)' ${code+"${code[@]}"})"
s11_cognito="$(printf '%s' "$s11_all" | grep -viE '(HS256|JWT_SECRET)' || true)"
s11_sym="$(printf '%s' "$s11_all" | grep -iE '(HS256|JWT_SECRET)' \
  | grep -viE 'throw|reject|forbid|disallow|not allowed|unsupported|deny|!==|!=|assert|expect\(' || true)"
report_policy "Cognito or symmetric JWT auth; use self-issued RS256 with the key in SSM (docs/05 s3.3, docs/07 s6)" \
  "$(printf '%s\n%s' "$s11_cognito" "$s11_sym" | sed '/^$/d')"

# S12: an auth token in web storage is readable by any script on the page (XSS to account
# takeover). Tokens stay in memory. Narrowly matched so a theme or locale preference does not
# false-positive.
report_policy "auth token written to localStorage / sessionStorage; keep tokens in memory (docs/07 s6.3, docs/09 s4.2)" \
  "$(grepf '(local|session)Storage\.setItem\([^)]*(token|jwt|credential|secret)' ${code+"${code[@]}"})"

# S13: Secrets Manager is forbidden; secrets live in SSM SecureString (free tier and one
# ownership model).
report_policy "AWS Secrets Manager; use SSM SecureString (docs/05 s6, docs/07 s5.3)" \
  "$(grepf '(aws_secretsmanager_secret|secretsmanager:GetSecretValue|@aws-sdk/client-secrets-manager)' ${code+"${code[@]}"})"

# S14: a provider API token literal, anywhere in authored text (see grept). A variable reference
# (var.x, env, data source) is the correct form, so only a long QUOTED literal matches. The quote
# requirement is what keeps this text-wide scan quiet: an `.env.example` placeholder
# (`CLOUDFLARE_API_TOKEN=replace-me`, unquoted) does not match, while a real token pasted into a
# note, a README fence, or a Terraform file does. Grafana Cloud tokens carry a prefix (glc_ for
# an access policy token, glsa_ for a service account), so those match quoted or not (docs/23).
report FAIL "literal provider API token; keep tokens outside the repo (docs/01 s5.3)" \
  "$(grept '(api_token|api_key|access_token|auth_token|secret_key|(^|[[:space:]])token)[[:space:]]*=[[:space:]]*"[A-Za-z0-9_-]{20,}"|(^|[^A-Za-z0-9_])gl(c|sa)_[A-Za-z0-9+/=_-]{32,}' ${SRC+"${SRC[@]}"})"

# S15: pull_request_target, issue_comment and workflow_run run in the BASE repository's context,
# with its secrets and token permissions, on events someone else can start (a fork's pull request,
# a comment on a public repository, a run of another workflow). GitHub issues them a default-branch
# sub, and AWS cannot test the event name in a trust policy. Paired with id-token: write (or
# write-all, which includes it) such a run can mint an AWS OIDC token, and since v0.7.0 every
# repository of the owner shares one role pair (docs/04). No reason makes that safe, so it is never
# waivable; a commented-out line configures nothing and is skipped.
s15=""
for f in ${wf+"${wf[@]}"}; do
  case "$f" in .github/workflows/*) ;; *) continue ;; esac
  s15body="$(grep -vE '^[[:space:]]*#' -- "$f" 2>/dev/null)"
  s15ev="$(grep -oE '(^|[^A-Za-z0-9_-])(pull_request_target|issue_comment|workflow_run)([^A-Za-z0-9_-]|$)' <<< "$s15body" \
    | grep -oE 'pull_request_target|issue_comment|workflow_run' | sort -u | paste -sd, -)"
  [ -n "$s15ev" ] || continue
  grep -qiE "id-token:[[:space:]]*[\"']?write|permissions:[[:space:]]*[\"']?write-all" <<< "$s15body" || continue
  s15="${s15}${f}: ${s15ev} together with id-token: write"$'\n'
done
report FAIL "pull_request_target, issue_comment or workflow_run with id-token: write hands an OIDC token to a run someone else can start (docs/04)" \
  "$(printf '%s' "$s15" | sed '/^$/d')"

# W1: gate-bypass tokens
# grepf ignores case, so "as any" must end at a non-word character: `as AnyValueMap` (an
# OpenTelemetry type the API template casts to) is a named type, not the any escape hatch.
report WARN "gate-bypass token: as any / ts-ignore / ts-nocheck / eslint-disable / .skip( (docs/20 s5)" \
  "$(grepf '(as any([^[:alnum:]_]|$)|@ts-ignore|@ts-nocheck|eslint-disable|\.skip\()' ${code+"${code[@]}"})"

# W2: free-tier forbidden resources. Secrets Manager and Cognito are handled as FAIL above
# (S13/S11) and are left out here so a single violation is not reported twice. CloudFront left the
# list in v0.7.0: one distribution in front of the private S3 site and the API is the standard
# edge (docs/05), and the infra checker no longer reports it either.
report WARN "free-tier forbidden resource (docs/01 s4.1)" \
  "$(grepf '(aws_nat_gateway|aws_eip|aws_db_instance|aws_rds_cluster|aws_route53_zone|provisioned_concurrent_executions)' ${iac+"${iac[@]}"} | drop_noise)"

# W3: AI access goes through Bedrock or Cloudflare Workers AI, never another provider's SDK wired
# directly into the app (D67, docs/19 s1). Workers AI left the standard in v0.7.0 and came back in
# v0.10.12 as a REST route from the backend, so its packages are not reported. WARN because a
# dev-only or evaluation script is a legitimate exception that this grep cannot distinguish.
# A Workers AI model id names the model's maker, not an SDK in the app: `@cf/openai/whisper-large-
# v3-turbo` is Whisper served by the Cloudflare route. drop_workers_ai_models takes those ids out
# of a line before it counts, so the model setting of a sanctioned route is not reported.
drop_workers_ai_models() {
  awk '{
    p = index($0, ":"); rest = substr($0, p + 1); q = index(rest, ":")
    text = tolower(substr(rest, q + 1))
    gsub(/@cf\/[a-z0-9._-]+\/[a-z0-9._-]+/, "", text)
    if (text ~ /(openai|@anthropic-ai\/sdk|@google\/generative-ai|@mistralai\/|cohere-ai)/) print $0
  }'
}
report WARN "direct AI provider SDK; route AI through Bedrock or Cloudflare Workers AI (docs/19 s1)" \
  "$(grepf '(openai|@anthropic-ai/sdk|@google/generative-ai|@mistralai/|cohere-ai)' ${code+"${code[@]}"} | drop_noise | drop_workers_ai_models)"

# W4: a Lambda Node runtime older than LAMBDA_NODE_MIN (top of this file). The runtime id is the one
# Node version the standard writes down; every other Node floats on the current LTS. A line WARNs
# when any runtime id on it is older, so a list that still carries an old runtime is caught too.
# WARN because moving an existing function is a migration (docs/11), not a one-line fix.
report WARN "Lambda Node runtime older than ${LAMBDA_NODE_MIN} (docs/05 s4, docs/07 s1)" \
  "$(grepf 'nodejs[0-9]+\.x' ${code+"${code[@]}"} | drop_noise | awk -v min="${LAMBDA_NODE_MIN//[!0-9]/}" '{
      p = index($0, ":"); rest = substr($0, p + 1); q = index(rest, ":")
      c = tolower(substr(rest, q + 1)); old = 0
      while (match(c, /nodejs[0-9]+\.x/)) {
        if (substr(c, RSTART + 6, RLENGTH - 8) + 0 < min + 0) old = 1
        c = substr(c, RSTART + RLENGTH)
      }
      if (old) print
    }')"

# ---- waiver self-defense (mirrors check-conventions.sh [0]) -------------------
# The waiver is the cheapest way to switch a policy rule off, so it is itself checked.
# Every waiver in effect is printed, which is the point: weakening a gate then shows up in
# the pull request diff next to the line it protects, instead of being an invisible act.
# W1 deliberately has no comment filter: `// @ts-ignore` IS a comment, and filtering
# comments there would delete the rule.
report WARN "conformance-allow waiver in effect (one policy rule suppressed per line)" \
  "$(grept "$WAIVER_RE" ${SRC+"${SRC[@]}"})"
report FAIL "conformance-allow marker with no reason suppresses nothing; state why (docs/16 s6.2)" \
  "$(grept "$WAIVER_BARE_RE" ${SRC+"${SRC[@]}"})"

say ""
if [ "$FAIL" -eq 1 ]; then
  say "RESULT: FAIL (security conformance). Fix the FAIL items above; WARN items are advisory."
  exit 1
fi
say "RESULT: PASS (security conformance; WARN items are advisory)."
exit 0
