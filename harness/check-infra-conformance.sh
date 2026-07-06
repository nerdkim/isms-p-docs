#!/usr/bin/env bash
# check-infra-conformance.sh - enforce playbook infra/DNS structure (D17/D18/D19) on a repo.
#
# Complements check-conventions.sh (docs/16 punctuation/terminology). This checker catches infra
# DRIFT that convention checks miss - the exact gaps that let vscode-stock hand-roll a v4 DNS record:
#
#   [1] cloudflare_record (v4 resource). Standard is cloudflare_dns_record (v5). (D19)
#   [2] cloudflare provider pinned to v4 (~> 4 / "4."). Standard is ">= 5, < 6". (D19)
#   [3] nested env domain <x>.dev.nerd.kim / <x>.stage.nerd.kim. Standard is flat
#       <x>-dev.nerd.kim (D17); Cloudflare free Universal SSL covers only a 1-level wildcard.
#   [4] self-hosted per-service DNS: a deploy/dns/ that creates cloudflare records. Under D18 a
#       self-hosted record points at the shared origin/proxy and belongs CENTRAL in nerdkim/infra
#       (infra/ dns layer), not in the per-service app repo.
#   [5] committed terraform state (*.tfstate) or backend "local" for DNS. Standard is S3 native
#       lock remote state (D19).
#   [6] hand-rolled cloudflare DNS resource not sourced from infra-modules//cloudflare/dns. (D19)
#   [7] missing playbook version marker (playbook version: vX.Y.Z; legacy Korean
#       "playbook 버전:" also accepted) in CLAUDE.md/AGENTS.md. (WARN)
#
# Checks [1]-[4],[6] are FAIL (exit 1). Checks [5](tfstate/local),[7] severity noted inline.
#
# Scope: infra files only (*.tf, *.hcl, *.conf, *.conf.example, Caddyfile, wrangler.toml) so doc
# examples of the forbidden forms (docs mention code.dev.nerd.kim as a "don't") do not false-positive.
# The version-marker check reads CLAUDE.md/AGENTS.md only. Excludes .terraform/, node_modules,
# _research/, and nested playbook/ clones.
#
# Usage: harness/check-infra-conformance.sh [TARGET_DIR]   (default: git root, else cwd)
set -uo pipefail

if ! echo x | grep -qP x 2>/dev/null; then
  echo "error: GNU grep -P (PCRE) required" >&2; exit 2
fi

TARGET_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$TARGET_DIR" || { echo "error: cannot cd to $TARGET_DIR" >&2; exit 2; }

EXCLUDE='(/\.terraform/|/\.terragrunt-cache/|/node_modules/|/_research/|/playbook/|/\.git/)'

# Collect infra files (tracked + untracked-not-ignored, so a manual run before git add works).
mapfile -t INFRA_FILES < <(
  { find . -type f \( -name '*.tf' -o -name '*.hcl' -o -name '*.conf' -o -name '*.conf.example' \
      -o -name 'Caddyfile' -o -name 'wrangler.toml' \) 2>/dev/null; } \
    | grep -vE "$EXCLUDE" | sed 's#^\./##' | sort -u
)

fail=0
warn=0

hit() { # hit <pcre> ; prints matching file:line, returns 0 if any match
  local pat="$1"; local found=1
  local f
  for f in "${INFRA_FILES[@]}"; do
    [ -f "$f" ] || continue
    if grep -HnP "$pat" "$f" 2>/dev/null; then found=0; fi
  done
  return $found
}

if [ "${#INFRA_FILES[@]}" -eq 0 ]; then
  echo "no infra files (*.tf/*.hcl/*.conf/Caddyfile/wrangler.toml) found under $TARGET_DIR - nothing to check."
fi

echo "== [1] cloudflare_record (v4 resource; use cloudflare_dns_record v5) =="
if hit '\bcloudflare_record\b'; then echo "  -> FAIL (D19: replace v4 cloudflare_record with v5 cloudflare_dns_record via infra-modules//cloudflare/dns)"; fail=1; else echo "  OK"; fi

echo "== [2] cloudflare provider pinned to v4 (use \">= 5, < 6\") =="
p2=0
for f in "${INFRA_FILES[@]}"; do
  [ -f "$f" ] || continue
  if grep -qP 'cloudflare/cloudflare' "$f" 2>/dev/null && grep -HnP 'version\s*=\s*"[^"]*(~>\s*4|=\s*4|\b4)\.' "$f" 2>/dev/null; then p2=1; fi
done
if [ "$p2" -eq 1 ]; then echo "  -> FAIL (D19: pin cloudflare provider to \">= 5, < 6\")"; fail=1; else echo "  OK"; fi

echo "== [3] nested env domain <x>.dev|stage.nerd.kim (use flat <x>-dev.nerd.kim, D17) =="
# Strip '#' comments first so "don't" examples in comments (this repo's own docs/skeletons name the
# forbidden form to warn against it) do not false-positive. Real record values / nginx server_name
# directives are not comments and are still caught.
p3=0
for f in "${INFRA_FILES[@]}"; do
  [ -f "$f" ] || continue
  m=$(sed 's/#.*//' "$f" | grep -nP '[a-z0-9_-]+\.(dev|stage)\.nerd\.kim' 2>/dev/null)
  if [ -n "$m" ]; then printf '%s\n' "$m" | sed "s#^#${f}:#"; p3=1; fi
done
if [ "$p3" -eq 1 ]; then echo "  -> FAIL (D17: flat suffix only, e.g. code-dev.nerd.kim not code<dot>dev.nerd.kim)"; fail=1; else echo "  OK"; fi

echo "== [4] self-hosted per-service DNS (deploy/dns/ creating cloudflare records; D18 = central) =="
p4=0
for f in "${INFRA_FILES[@]}"; do
  case "$f" in
    deploy/dns/*.tf|*/deploy/dns/*.tf)
      if grep -qP '\bcloudflare_(dns_)?record\b' "$f" 2>/dev/null; then echo "  $f: cloudflare record in deploy/dns/"; p4=1; fi ;;
  esac
done
if [ "$p4" -eq 1 ]; then echo "  -> FAIL (D18: a self-hosted record points at the shared origin/proxy and belongs CENTRAL in nerdkim/infra's dns layer, not this app repo. Delete deploy/dns/; keep only the proxy fragment.)"; fail=1; else echo "  OK"; fi

echo "== [5] committed terraform state / backend \"local\" (use S3 remote state, D19) =="
p5=0
if git ls-files 2>/dev/null | grep -E '\.tfstate($|\.backup$)' | grep -vE "$EXCLUDE"; then echo "  -> committed *.tfstate above"; p5=1; fi
if hit 'backend\s+"local"'; then p5=1; fi
if [ "$p5" -eq 1 ]; then echo "  -> FAIL (D19: never commit state; use S3 backend with native lock use_lockfile=true)"; fail=1; else echo "  OK"; fi

echo "== [6] hand-rolled cloudflare DNS resource not via infra-modules//cloudflare/dns (D19) =="
# If a repo declares resource "cloudflare_dns_record" directly AND nowhere references the shared
# module (infra-modules ... //cloudflare/dns?ref=), the record is hand-rolled. The aws/edge and
# aws/api modules are the sanctioned exception (they live in infra-modules, not here).
declares_record=0
references_module=0
for f in "${INFRA_FILES[@]}"; do
  [ -f "$f" ] || continue
  grep -qP 'resource\s+"cloudflare_(dns_)?record"' "$f" 2>/dev/null && declares_record=1
  grep -qP 'infra-modules(\.git)?//(cloudflare/dns|aws/(edge|api))' "$f" 2>/dev/null && references_module=1
done
if [ "$declares_record" -eq 1 ] && [ "$references_module" -eq 0 ]; then
  echo "  -> FAIL (D19: manage records through infra-modules//cloudflare/dns ?ref=, not a hand-rolled resource block)"; fail=1
else echo "  OK"; fi

echo "== [7] playbook version marker in CLAUDE.md/AGENTS.md (WARN) =="
if grep -hoP 'playbook (버전|version):\s*v[0-9]+\.[0-9]+\.[0-9]+' CLAUDE.md AGENTS.md 2>/dev/null | head -1; then
  echo "  OK"
else
  echo "  -> WARN (no 'playbook version: vX.Y.Z' marker; conformance version undeclared)"; warn=1
fi

echo "== [8] legacy Route53 / CloudFront / us-east-1 ACM stack (deprecated by docs/06; WARN) =="
# docs/06 D1/D2: DNS=Cloudflare (Route53 폐기), frontend=S3 static origin + Cloudflare CDN (Cloudflare Pages/CloudFront 아님),
# api=regional ACM ap-northeast-2 (us-east-1 ACM 없음). This is a separate (larger) aws migration,
# so it is surfaced as a WARN, not a hard FAIL of the D17/D18/D19 DNS gate. Match only the legacy
# resources (not the bare string "us-east-1", which is legitimate for Cost Explorer/global services).
if hit '\baws_route53_(zone|record)\b|\baws_cloudfront_distribution\b'; then
  echo "  -> WARN (legacy Cloudflare-free stack; migrate to an S3 static origin + Cloudflare CDN (aws s3 sync) + cloudflare/dns v5 + regional ACM, docs/05, docs/06)"; warn=1
else echo "  OK"; fi

echo
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAIL (infra conformance violations above). See playbook docs/00 D17/D18/D19, docs/06 §7, docs/14 §4.3.4."
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "RESULT: PASS with warnings."
else
  echo "RESULT: PASS."
fi
exit 0
