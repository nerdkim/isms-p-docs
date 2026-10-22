#!/usr/bin/env bash
# test-lib.sh - self-test for harness/lib.sh (docs/00 D6).
#
# Two properties matter here and both were real defects before the library existed:
#   1. the marker pattern must read the BOLDED form, which is what the legacy population uses
#      and which every previous reader silently missed, reporting an adopted repo as greenfield;
#   2. comparison must not treat a pre-reset v1.x marker as newer than current, which a naive
#      `sort -V` does.
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/lib.sh"
pass=0; fail=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

ok() { # LABEL GOT WANT
  if [ "$2" = "$3" ]; then echo "  PASS $1"; pass=$((pass+1))
  else echo "  FAIL $1 (got '$2', want '$3')"; fail=$((fail+1)); fi
}

echo "== test-lib =="

# ---- version comparison -------------------------------------------------------
ok "older is behind"            "$(playbook_version_cmp v0.1.6 v0.2.0)" behind
ok "equal is current"           "$(playbook_version_cmp v0.2.0 v0.2.0)" current
ok "newer is ahead"             "$(playbook_version_cmp v0.3.0 v0.2.0)" ahead
ok "minor axis: behind"         "$(playbook_version_cmp v0.1.9 v0.2.0)" behind
ok "patch axis: behind"         "$(playbook_version_cmp v0.2.0 v0.2.1)" behind
ok "patch axis: ahead"          "$(playbook_version_cmp v0.2.2 v0.2.1)" ahead
# The whole reason a shared comparator exists: `printf 'v0.2.0\nv1.6.3\n' | sort -V | tail -1`
# answers v1.6.3, so a naive comparison tells a legacy repo it leads the standard.
ok "pre-reset is not ahead"     "$(playbook_version_cmp v1.6.3 v0.2.0)" pre-reset
ok "pre-reset vs pre-reset compares normally" "$(playbook_version_cmp v1.6.3 v1.7.0)" behind
ok "garbage is unknown"         "$(playbook_version_cmp nonsense v0.2.0)" unknown
ok "empty is unknown"           "$(playbook_version_cmp '' v0.2.0)" unknown

# ---- marker reading -----------------------------------------------------------
mk() { mkdir -p "$tmp/r"; printf '%s\n' "$1" > "$tmp/r/CLAUDE.md"; rm -f "$tmp/r/harness/ADOPTED" 2>/dev/null; }
mk '> playbook version: v0.1.6 (synced 2026-01-01)'
ok "plain English marker"       "$(playbook_read_adopted "$tmp/r")" v0.1.6
mk '> playbook 버전: v0.1.6 (동기화 기준일 2026-01-01)'
ok "plain Korean marker"        "$(playbook_read_adopted "$tmp/r")" v0.1.6
# The form the legacy population actually uses. Every previous reader returned nothing here.
mk '> **playbook version:** v0.1.6'
ok "bolded label"               "$(playbook_read_adopted "$tmp/r")" v0.1.6
mk '> **playbook 버전:** v0.1.6'
ok "bolded Korean label"        "$(playbook_read_adopted "$tmp/r")" v0.1.6
mk '- playbook version: **v0.1.6**'
ok "bolded value"               "$(playbook_read_adopted "$tmp/r")" v0.1.6
mk '# no marker here at all'
ok "absent marker reads empty"  "$(playbook_read_adopted "$tmp/r")" ""

# The standard layout reads the marker through CLAUDE.md, and the AGENTS.md alias changes nothing.
mk '> playbook version: v0.1.7'; ( cd "$tmp/r" && ln -s CLAUDE.md AGENTS.md )
ok "CLAUDE.md with its AGENTS.md alias" "$(playbook_read_adopted "$tmp/r")" v0.1.7
# v0.3.x kept the instructions in a regular AGENTS.md. Until it is migrated, that name still counts.
rm -f "$tmp/r/AGENTS.md" "$tmp/r/CLAUDE.md"; printf '> playbook version: v0.1.5\n' > "$tmp/r/AGENTS.md"
ok "a v0.3.x AGENTS.md is read as well" "$(playbook_read_adopted "$tmp/r")" v0.1.5
# CLAUDE.md is the entry, so it wins over a stale regular copy under the other name.
mk '> playbook version: v0.1.8'
ok "CLAUDE.md wins over a stale AGENTS.md copy" "$(playbook_read_adopted "$tmp/r")" v0.1.8

# A public repository keeps the managed block, version line included, in CLAUDE.local.md.
rm -f "$tmp/r/CLAUDE.md" "$tmp/r/AGENTS.md"
printf '# public project\n' > "$tmp/r/CLAUDE.md"
printf '> playbook version: v0.1.9\n' > "$tmp/r/CLAUDE.local.md"
ok "a public repository's CLAUDE.local.md is read last" "$(playbook_read_adopted "$tmp/r")" v0.1.9
mk '> playbook version: v0.1.8'
ok "CLAUDE.md wins over CLAUDE.local.md" "$(playbook_read_adopted "$tmp/r")" v0.1.8
rm -f "$tmp/r/CLAUDE.local.md"

# harness/ADOPTED wins: prose is for people, and a parser must not depend on it.
mkdir -p "$tmp/r/harness"; printf 'version: v0.2.0\ndate: 2026-09-10\n' > "$tmp/r/harness/ADOPTED"
ok "ADOPTED takes precedence"   "$(playbook_read_adopted "$tmp/r")" v0.2.0

# ---- the owner allowlist --------------------------------------------------------
owner() { if playbook_is_owner "$1" "$2"; then printf yes; else printf no; fi; }
ok "the owner's name is the owner"          "$(owner nerdkim someone@example.com)" yes
ok "the owner's domain is the owner"        "$(owner Someone x@nerd.kim)" yes
ok "GitHub's merge-ref author is allowlisted" "$(owner GitHub noreply@github.com)" yes
ok "anyone else is not"                      "$(owner 'Jane Doe' jane@example.com)" no
ok "an empty identity is not the owner"      "$(owner '' '')" no
ok "ALLOWED_AUTHOR_RE overrides the list"    "$(ALLOWED_AUTHOR_RE='^Jane ' owner 'Jane Doe' jane@example.com)" yes

# ---- the identity git would record ------------------------------------------------
git init -q "$tmp/g"
git -C "$tmp/g" config user.name 'Jane Doe'; git -C "$tmp/g" config user.email jane@example.com
ok "identity from user.name and user.email" \
  "$(env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL bash -c ". '$HERE/lib.sh'; playbook_git_identity '$tmp/g'")" \
  "$(printf 'Jane Doe\tjane@example.com')"
ok "GIT_AUTHOR_* wins, as it does for the commit" \
  "$(GIT_AUTHOR_NAME=Other GIT_AUTHOR_EMAIL=o@example.com playbook_git_identity "$tmp/g")" \
  "$(printf 'Other\to@example.com')"
# Every config file hidden and guessing forbidden, so git cannot tell: the answer is empty, which
# the callers then treat as "not a contributor".
git init -q "$tmp/g2"; git -C "$tmp/g2" config user.useConfigOnly true; mkdir -p "$tmp/nohome"
ok "no identity when git cannot tell" \
  "$(HOME="$tmp/nohome" XDG_CONFIG_HOME="$tmp/nohome" GIT_CONFIG_NOSYSTEM=1 \
     env -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL bash -c ". '$HERE/lib.sh'; playbook_git_identity '$tmp/g2'")" ""

# ---- the public repository marker ------------------------------------------------
mkdir -p "$tmp/p/harness"
ok "no marker: a private repository"         "$(playbook_public_repo "$tmp/p")" ""
printf '# comment\npublic since 2026-09-29: outside contributors commit here\n' > "$tmp/p/harness/public-repo"
ok "a marker with a reason is on"            "$(playbook_public_repo "$tmp/p")" on
printf '# only a comment\n\n' > "$tmp/p/harness/public-repo"
case "$(playbook_public_repo "$tmp/p")" in bad:*) ok "a marker without a reason is bad" yes yes;; *) ok "a marker without a reason is bad" no yes;; esac
printf 'too short\n' > "$tmp/p/harness/public-repo"
case "$(playbook_public_repo "$tmp/p")" in bad:*) ok "a reason under 10 characters is bad" yes yes;; *) ok "a reason under 10 characters is bad" no yes;; esac
rm -f "$tmp/p/harness/public-repo"; printf 'public since 2026-09-29: contributors\n' > "$tmp/p/elsewhere"
ln -s ../elsewhere "$tmp/p/harness/public-repo"
case "$(playbook_public_repo "$tmp/p")" in bad:*) ok "a symlinked marker is bad" yes yes;; *) ok "a symlinked marker is bad" no yes;; esac
rm -f "$tmp/p/harness/public-repo"; mkdir "$tmp/p/harness/public-repo"
case "$(playbook_public_repo "$tmp/p")" in bad:*) ok "a directory marker is bad" yes yes;; *) ok "a directory marker is bad" no yes;; esac

# ---- the playbook itself, and a spoof of it -------------------------------------------
# Self mode switches consumer-only rules off in two checkers, so it must need real content and must
# survive a rename of the overview or a VERSION without the v.
mkself() { # DIR - the four facts a playbook repository carries
  mkdir -p "$1/harness" "$1/docs"
  printf 'v0.7.0\n' > "$1/VERSION"
  printf '#!/usr/bin/env bash\n# playbook guard-set install (fixture)\n' > "$1/harness/install.sh"
  printf 'name: conventions\n' > "$1/harness/conventions.yml"
  printf '# overview\n' > "$1/docs/00-overview.md"
}
isself() { if playbook_is_self "$1"; then printf yes; else printf no; fi; }
mkself "$tmp/pb"
ok "a playbook-shaped tree is the playbook itself"   "$(isself "$tmp/pb")" yes
printf '0.7.0\n' > "$tmp/pb/VERSION"; mv "$tmp/pb/docs/00-overview.md" "$tmp/pb/docs/00-intro.md"
ok "a VERSION without the v and a renamed overview" "$(isself "$tmp/pb")" yes
mkself "$tmp/s1"; : > "$tmp/s1/harness/install.sh"
ok "an installer without its marker is no playbook"  "$(isself "$tmp/s1")" no
mkself "$tmp/s2"; : > "$tmp/s2/VERSION"
ok "an empty VERSION is no playbook"                 "$(isself "$tmp/s2")" no
mkself "$tmp/s3"; rm -f "$tmp/s3/harness/conventions.yml"
ok "no conventions template is no playbook"          "$(isself "$tmp/s3")" no
mkself "$tmp/s4"; rm -f "$tmp/s4/docs/00-overview.md"
ok "no docs/00-*.md overview is no playbook"         "$(isself "$tmp/s4")" no
mkdir -p "$tmp/consumer"
ok "a consumer is no playbook"                        "$(isself "$tmp/consumer")" no

# ---- the human sentence -------------------------------------------------------
case "$(playbook_describe_delta v0.1.6 v0.2.0)" in BEHIND:*) ok "delta names BEHIND" yes yes;; *) ok "delta names BEHIND" no yes;; esac
case "$(playbook_describe_delta v1.6.3 v0.2.0)" in PRE-RESET:*) ok "delta names PRE-RESET" yes yes;; *) ok "delta names PRE-RESET" no yes;; esac
case "$(playbook_describe_delta '' v0.2.0)" in "no marker"*) ok "delta names first adoption" yes yes;; *) ok "delta names first adoption" no yes;; esac

# ---- no pipe into grep -q ----------------------------------------------------------
# Every guard and self-test runs under `set -o pipefail`. grep -q exits at its first match, a
# writer still writing then dies of SIGPIPE, and pipefail reports the whole pipe as failed: a
# match read as a miss, at random. It failed T5 and T6 of check-structure-conformance.sh about one
# run in seven on a busy machine. The scripts feed a variable with a here-string, test command
# output with [ -n "$(...)" ], and count with grep -c, which reads to the end. A `||` is not a
# pipe, so the pattern requires a single bar.
piped=""
for f in "$HERE"/*.sh "$HERE"/githooks/*; do
  [ -f "$f" ] || continue
  hits="$(grep -nE '(^|[^|])\|[[:space:]]*grep([[:space:]]+-[A-Za-z]+)*[[:space:]]+-[A-Za-z]*q' "$f" \
    | grep -vE '^[0-9]+:[[:space:]]*#')"
  [ -n "$hits" ] && piped="${piped}$(sed "s#^#${f##*/}:#" <<< "$hits")"$'\n'
done
ok "no guard or self-test pipes into grep -q" "$piped" ""

echo ""
echo "RESULT: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1
