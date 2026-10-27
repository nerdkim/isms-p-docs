#!/usr/bin/env bash
# test-check-conventions.sh - tests for harness/check-conventions.sh.
#
# docs/00 D6 mandates tests for every project. This repo has no node toolchain,
# so the checker (a bash script) is tested with a dependency-free bash harness:
# each case builds a throwaway git repo, drops fixture files, runs the REAL
# checker there, and asserts its exit code plus which check fired.
#
# Forbidden-unicode fixtures are generated at runtime via printf escapes (never
# literal) so this test file itself stays clean under check [1]. Term/arrow/paren
# fixtures are literal Korean, so this file is excluded from checks [2][3][4] via
# the checker's EXCL list.
set -uo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CHECKER="$REPO_ROOT/harness/check-conventions.sh"
[ -f "$CHECKER" ] || { echo "checker not found: $CHECKER" >&2; exit 2; }

if ! grep -qP x <<< x 2>/dev/null; then
  echo "error: GNU grep -P (PCRE) required" >&2; exit 2
fi

pass=0; fail=0
tmproot="$(mktemp -d)"
trap 'rm -rf "$tmproot"' EXIT

# forbidden-unicode fixtures (built via escapes, never literal in this source)
EM_DASH="$(printf '\u2014')"   # em dash (forbidden by check [1])
ARROW="$(printf '\u2192')"     # proper prose arrow (required by check [3])

# new_repo: prints a fresh temp git repo with the checker copied in.
new_repo() {
  local d; d="$(mktemp -d "$tmproot/case.XXXXXX")"
  git -C "$d" init -q
  git -C "$d" config user.email t@t.local
  git -C "$d" config user.name tester
  mkdir -p "$d/scripts" "$d/docs"
  cp "$CHECKER" "$d/scripts/check-conventions.sh"
  # the rule-definition file exists in the real repo and is excluded; mirror it.
  printf '# conventions (rule definition, excluded from term/arrow/paren)\n' \
    > "$d/docs/16-documentation-conventions.md"
  printf '%s' "$d"
}

# assert_repo NAME DIR EXPECT_RC [EXPECT_SUBSTR]
assert_repo() {
  local name="$1" dir="$2" expect_rc="$3" expect_sub="${4:-}"
  git -C "$dir" add -A >/dev/null 2>&1
  local out rc
  out="$(cd "$dir" && bash scripts/check-conventions.sh 2>&1)"; rc=$?
  local ok=1
  [ "$rc" = "$expect_rc" ] || ok=0
  if [ -n "$expect_sub" ]; then grep -qF -- "$expect_sub" <<< "$out" || ok=0; fi
  if [ "$ok" = 1 ]; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (rc=$rc, expected=$expect_rc, wanted substring: '$expect_sub')"
    printf '%s\n' "$out" | sed 's/^/        | /'
    fail=$((fail + 1))
  fi
}

echo "== check-conventions.sh test suite =="

# 1) clean doc passes (proper arrow, attached Korean paren, English IT terms)
d="$(new_repo)"
printf '# clean\n\nA에서 B로 %s 이동한다. 한글(부연) 형식으로 쓰고 repository를 clone한다.\n' "$ARROW" > "$d/docs/clean.md"
assert_repo "clean doc passes" "$d" 0 "RESULT: PASS"

# 2) forbidden unicode (em dash) in a .md fails [1]
d="$(new_repo)"
printf '# bad\n\n범위 %s 설명\n' "$EM_DASH" > "$d/docs/bad.md"
assert_repo "em dash in .md fails [1]" "$d" 1 "forbidden unicode"

# 3) forbidden unicode is also scanned in non-md tracked files (.sh)
d="$(new_repo)"
printf '#!/usr/bin/env bash\n# range %s here\necho hi\n' "$EM_DASH" > "$d/scripts/foo.sh"
assert_repo "em dash in .sh fails [1]" "$d" 1 "forbidden unicode"

# 4) transliteration term in prose fails [2]
d="$(new_repo)"
printf '# doc\n\n어제 커밋을 남겼다.\n' > "$d/docs/translit.md"
assert_repo "translit term in prose fails [2]" "$d" 1 "transliteration"

# 5) same term inside a fenced code block is ignored (strip removes fences)
d="$(new_repo)"
cat > "$d/docs/fenced.md" <<'EOF'
# doc

정상 문장이다.

```
커밋
```
EOF
assert_repo "translit inside code fence passes" "$d" 0 "RESULT: PASS"

# 6) ASCII arrow in prose fails [3].
# The fixture deliberately contains NO dictionary term. It used to read `데이터가 A -> B 로
# 흐른다.`, and 데이터 is a [2] term, so the case passed on its own even with [3] deleted:
# a mutation replacing the [3] pattern with one that can never match left the suite 36/36
# green. [4] and [5] both died loudly under the same mutation; only [3] was invisible.
d="$(new_repo)"
printf '# doc\n\n값이 A -> B 로 간다.\n' > "$d/docs/arrow.md"
assert_repo "ASCII arrow in prose fails [3]" "$d" 1 "prose arrows"

# 7) ASCII arrow inside inline code is ignored (strip removes inline code)
d="$(new_repo)"
printf '# doc\n\n표현은 `A -> B` 이다.\n' > "$d/docs/arrow-inline.md"
assert_repo "ASCII arrow in inline code passes" "$d" 0 "RESULT: PASS"

# 8) Korean opening-paren with a space fails [4]
d="$(new_repo)"
printf '# doc\n\n한글 (부연) 형식은 틀리다.\n' > "$d/docs/paren.md"
assert_repo "spaced Korean paren fails [4]" "$d" 1 "opening-paren"

# 9) negative lookbehind: 나머지 must NOT match the 머지 term
d="$(new_repo)"
printf '# doc\n\n나머지 작업을 마저 한다.\n' > "$d/docs/namuji.md"
assert_repo "나머지 does not false-positive [2]" "$d" 0 "RESULT: PASS"

# 10) but the bare 머지 (merge) term does match [2]
d="$(new_repo)"
printf '# doc\n\nbranch를 머지했다.\n' > "$d/docs/merge.md"
assert_repo "bare 머지 term fails [2]" "$d" 1 "transliteration"

# 11) docs/16 is excluded from [2] and [5] only. Those two rules require the document to name
# the forms it forbids (the term table, the glued prefixes). [3] arrows and [4] paren spacing
# have no such need, and excluding the file from them was hiding three genuine [4] violations
# inside the very document that defines rule [4].
d="$(new_repo)"
printf '# conventions\n\n커밋 and 재deploy as examples.\n' \
  > "$d/docs/16-documentation-conventions.md"
assert_repo "docs/16 is excluded from [2] and [5]" "$d" 0 "RESULT: PASS"

d="$(new_repo)"
printf '# conventions\n\n한글 (부연) as an example.\n' \
  > "$d/docs/16-documentation-conventions.md"
assert_repo "docs/16 is NOT excluded from [4]" "$d" 1 "opening-paren"

d="$(new_repo)"
printf '# conventions\n\nA -> B as an example.\n' \
  > "$d/docs/16-documentation-conventions.md"
assert_repo "docs/16 is NOT excluded from [3]" "$d" 1 "prose arrows"

# 12) a line carrying a forbidden term but marked conventions-allow is skipped [2]
d="$(new_repo)"
printf '# doc\n\n%s\n' '공식 제목 인용: 커밋 정책. <!-- conventions-allow: quotes an official title -->' > "$d/docs/allow.md"
assert_repo "conventions-allow skips the marked line [2]" "$d" 0 "RESULT: PASS"

# 13) but a forbidden term on an UNmarked line still fails [2]
d="$(new_repo)"
printf '# doc\n\n%s\n' '일반 문장에서 커밋을 남겼다.' > "$d/docs/nomark.md"
assert_repo "unmarked transliteration still fails [2]" "$d" 1 "transliteration"

# 14) Korean prefix glued to an English term (재deploy) fails [5]
d="$(new_repo)"
printf '# doc\n\n문제가 생기면 재deploy 없이 되돌린다.\n' > "$d/docs/prefix.md"
assert_repo "재 glued to English term fails [5]" "$d" 1 "Korean prefix"

# 15) 재 + Hangul (재구축/재사용) and "다시 deploy" pass [5]
d="$(new_repo)"
printf '# doc\n\n다시 deploy한다. 재구축과 재사용은 정상이다.\n' > "$d/docs/prefix-ok.md"
assert_repo "재 + Hangul passes [5]" "$d" 0 "RESULT: PASS"

# 16) There is no language exemption any more. Documents are Korean prose whose IT terms stay
# English (docs/16 s3.1), so a Korean-language file is exactly the file [2] exists to scan. The
# old `*.ko.md` skip inverted the rule the moment every document became Korean, and it was a
# one-rename bypass: naming a file DEPLOY.ko.md switched [2] off for it.
d="$(new_repo)"
printf '# deploy\n\n소스를 build해 deploy한다. 다시 deploy도 English 용어로 쓴다.\n' > "$d/docs/DEPLOY.ko.md"
assert_repo "a Korean doc using English terms passes [2]" "$d" 0 "RESULT: PASS"

d="$(new_repo)"
printf '# 배포\n\n소스를 빌드해 배포한다.\n' > "$d/docs/DEPLOY.ko.md"
assert_repo "a .ko.md rename no longer bypasses [2]" "$d" 1 "transliteration"

# 17) but the same Korean term in a plain .md still fails [2]
d="$(new_repo)"
printf '# doc\n\n소스를 빌드해 배포한다.\n' > "$d/docs/deploy-plain.md"
assert_repo "plain .md still fails transliteration [2]" "$d" 1 "transliteration"

# 18) The Korean governance documents are no longer exempt either, and the old globs were
# unanchored, so ANY path ending in agent-conduct.md escaped [2] wherever it sat.
d="$(new_repo)"
printf '# conduct\n\n응대는 자연스러운 Korean 문장에 English 용어를 담아 쓴다.\n' > "$d/docs/agent-conduct.md"
assert_repo "agent-conduct.md using English terms passes [2]" "$d" 0 "RESULT: PASS"

d="$(new_repo)"
printf '# conduct\n\n응대는 자연스러운 한국어로 배포와 빌드를 쓴다.\n' > "$d/docs/agent-conduct.md"
assert_repo "agent-conduct.md is no longer exempt from [2]" "$d" 1 "transliteration"

d="$(new_repo)"
printf '# conduct\n\n응대는 자연스러운 한국어로 배포와 빌드를 쓴다.\n' > "$d/docs/my-agent-conduct.md"
assert_repo "a path merely ENDING in agent-conduct.md is not exempt either" "$d" 1 "transliteration"

# ---- [0] exception self-defense -------------------------------------------------
# The two documented exception mechanisms are the cheapest way to switch this checker off, so
# the checker refuses to be switched off by them (docs/16 s6.2).

# 19) a broad conventions-exclude prefix is refused
d="$(new_repo)"
mkdir -p "$d/harness"
printf 'docs/\n' > "$d/harness/conventions-exclude"
printf '# doc\n\n일반 문장에서 커밋을 남겼다.\n' > "$d/docs/hidden.md"
assert_repo "broad exclude prefix docs/ is refused [0]" "$d" 1 "broad prefix"

# 20) so is a whole-tree prefix (refused as a regex metacharacter, since `.` matches anything)
d="$(new_repo)"
mkdir -p "$d/harness"
printf '.\n' > "$d/harness/conventions-exclude"
assert_repo "whole-tree exclude prefix is refused [0]" "$d" 1 "conventions-exclude exists only for"

# 20b) a narrow-looking entry that is really a broad regex is refused too. `docs/.` and `[d]ocs/`
# both match the whole docs tree while comparing literally as something specific.
d="$(new_repo)"
mkdir -p "$d/harness"
printf 'docs/.\n' > "$d/harness/conventions-exclude"
printf '# doc\n\n일반 문장에서 커밋을 남겼다.\n' > "$d/docs/hidden.md"
assert_repo "regex-metacharacter exclude entry is refused [0]" "$d" 1 "regex metacharacter"

d="$(new_repo)"
mkdir -p "$d/harness"
printf '[d]ocs/\n' > "$d/harness/conventions-exclude"
printf '# doc\n\n일반 문장에서 커밋을 남겼다.\n' > "$d/docs/hidden.md"
assert_repo "bracket-class exclude entry is refused [0]" "$d" 1 "regex metacharacter"

# 21) a specific nested external-corpus path is the sanctioned use and is honoured
d="$(new_repo)"
mkdir -p "$d/harness" "$d/vendor/iso-standard"
printf 'vendor/iso-standard/\n' > "$d/harness/conventions-exclude"
printf '# reproduced official text\n\n커밋 정책 원문.\n' > "$d/vendor/iso-standard/orig.md"
assert_repo "specific external-corpus exclude is honoured [0]" "$d" 0 "RESULT: PASS"

# 21b) the Korean writing style's rule file must list the forms it forbids, so .korean-style/ is
# excluded by the checker itself, the way _research/ is (docs/22 s6). A dotted path cannot be
# written in harness/conventions-exclude, which refuses regex metacharacters.
d="$(new_repo)"
mkdir -p "$d/.korean-style"
printf '# korean-style rules\n\nloanword-spelling: 워크플로우=워크플로\n커밋 메시지를 검사한다.\n' > "$d/.korean-style/rules.md"
assert_repo ".korean-style/ is excluded as the Korean style's rule corpus" "$d" 0 "RESULT: PASS"

# 21c) harness/korean-content: what a Korean project writes for Korean readers keeps the Korean
# terms those readers use (D71). [2] skips the listed paths and says so, every other check still
# scans them, and [2] still scans every other path.
KC_REASON='reason: 한국어 독자에게 내는 통제 문서입니다'
d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf '# Korean deliverables\n%s\ndocs/ko/  # the control documents\n' "$KC_REASON" > "$d/harness/korean-content"
printf '# 통제\n\n배포 전에 백업을 확인합니다.\n' > "$d/docs/ko/control.md"
assert_repo "korean-content lets a listed Korean deliverable keep its Korean terms [2]" "$d" 0 \
  "korean-content: skipped 1 file(s) under docs/ko/"

d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf '%s\ndocs/ko/\n' "$KC_REASON" > "$d/harness/korean-content"
printf '# 통제\n\n배포 전에 확인합니다.\n' > "$d/docs/ko/control.md"
printf '# 개발 문서\n\n배포 순서를 적습니다.\n' > "$d/docs/dev.md"
assert_repo "korean-content leaves [2] on for every other path" "$d" 1 "docs/dev.md:3:"

d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf '%s\ndocs/ko/\n' "$KC_REASON" > "$d/harness/korean-content"
printf '# 통제\n\n범위 %s 설명\n' "$EM_DASH" > "$d/docs/ko/control.md"
assert_repo "korean-content does not lift the forbidden-character check [1]" "$d" 1 "forbidden unicode"

d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf '%s\ndocs/ko/\n' "$KC_REASON" > "$d/harness/korean-content"
printf '# 통제\n\n설명 (부연)\n' > "$d/docs/ko/control.md"
assert_repo "korean-content does not lift the paren-spacing check [4]" "$d" 1 "opening-paren"

# A marker that narrows a gate must say why and must name the deliverables, not the tree.
d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf 'docs/ko/\n' > "$d/harness/korean-content"
printf '# 통제\n\n배포 전에 확인합니다.\n' > "$d/docs/ko/control.md"
assert_repo "korean-content without a reason grants nothing [0]" "$d" 1 "states no reason"

d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf 'reason: short\ndocs/ko/\n' > "$d/harness/korean-content"
printf '# 통제\n\n배포 전에 확인합니다.\n' > "$d/docs/ko/control.md"
assert_repo "korean-content with a reason under 10 characters grants nothing [0]" "$d" 1 "states no reason"

d="$(new_repo)"
mkdir -p "$d/harness"
printf '%s\n/\n' "$KC_REASON" > "$d/harness/korean-content"
assert_repo "korean-content refuses the whole tree [0]" "$d" 1 "korean-content self-defense"

d="$(new_repo)"
mkdir -p "$d/harness"
printf '%s\nharness/\n' "$KC_REASON" > "$d/harness/korean-content"
assert_repo "korean-content refuses harness/ [0]" "$d" 1 "name the Korean deliverables"

d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf '%s\ndocs/.\n' "$KC_REASON" > "$d/harness/korean-content"
printf '# 통제\n\n배포 전에 확인합니다.\n' > "$d/docs/ko/control.md"
assert_repo "korean-content refuses a regex entry [0]" "$d" 1 "regex metacharacter"

# 21c) the wholesale-carve-out share is measured against the tree in both modes. A commit that
# only refreshes the vendored corpus stages almost nothing but excluded paths; measuring the
# staged set blocked every release update of an external corpus that is a small part of the tree.
d="$(new_repo)"
mkdir -p "$d/harness" "$d/vendor/iso-standard"
printf 'vendor/iso-standard/\n' > "$d/harness/conventions-exclude"
printf '# a\n' > "$d/docs/a.md"; printf '# b\n' > "$d/docs/b.md"; printf '# c\n' > "$d/docs/c.md"
printf '# reproduced official text, release 1\n' > "$d/vendor/iso-standard/orig.md"
git -C "$d" add -A >/dev/null 2>&1
git -C "$d" commit -qm seed >/dev/null 2>&1
printf '# reproduced official text, release 2\n' > "$d/vendor/iso-standard/orig.md"
git -C "$d" add -A >/dev/null 2>&1
out="$(cd "$d" && bash scripts/check-conventions.sh --staged 2>&1)"; rc=$?
if [ "$rc" = 0 ] && ! grep -qF "wholesale carve-out" <<< "$out"; then
  echo "  PASS: --staged corpus refresh is measured against the tree, not the staged set [0]"; pass=$((pass + 1))
else
  echo "  FAIL: --staged corpus refresh is measured against the tree, not the staged set [0] (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        | /'; fail=$((fail + 1))
fi

# 21d) an exclusion that hides most of the tree is still refused, and staging only an unexcluded
# file does not dodge the measurement.
d="$(new_repo)"
mkdir -p "$d/harness" "$d/vendor/iso-standard"
printf 'vendor/iso-standard/\n' > "$d/harness/conventions-exclude"
for n in 1 2 3 4 5 6; do printf '# part %s\n' "$n" > "$d/vendor/iso-standard/part$n.md"; done
assert_repo "an exclusion hiding most of the tree is a wholesale carve-out [0]" "$d" 1 "wholesale carve-out"
git -C "$d" commit -qm seed >/dev/null 2>&1
printf '# a\n' > "$d/docs/a.md"
git -C "$d" add -A >/dev/null 2>&1
out="$(cd "$d" && bash scripts/check-conventions.sh --staged 2>&1)"; rc=$?
if [ "$rc" = 1 ] && grep -qF "wholesale carve-out" <<< "$out"; then
  echo "  PASS: --staged still refuses a wholesale carve-out of the tree [0]"; pass=$((pass + 1))
else
  echo "  FAIL: --staged still refuses a wholesale carve-out of the tree [0] (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        | /'; fail=$((fail + 1))
fi

# 21e) a repository that is itself an external corpus declares so in harness/corpus-repo. With a
# reason the 40% limit is lifted and the share is announced; the files outside the corpus are still
# checked, so a violation there still fails.
d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf 'docs/ko/\n' > "$d/harness/conventions-exclude"
printf '# why\nReproduces the official criteria verbatim; the source text cannot be edited.\n' > "$d/harness/corpus-repo"
for n in 1 2 3 4 5 6; do printf '# 원문 %s\n\n공식 원문 그대로입니다. 커밋 정책.\n' "$n" > "$d/docs/ko/part$n.md"; done
assert_repo "a declared corpus repository may exclude most of its tree [0]" "$d" 0 "the 40% limit does not apply"
printf '# own doc\n\n일반 문장에서 커밋을 남겼다.\n' > "$d/docs/own.md"
assert_repo "a corpus repository still checks the files outside the corpus [2]" "$d" 1 "transliteration"

# 21f) a marker without a reason grants nothing: it fails, and the 40% limit still applies.
d="$(new_repo)"
mkdir -p "$d/harness" "$d/docs/ko"
printf 'docs/ko/\n' > "$d/harness/conventions-exclude"
printf '# a corpus repository\n\n' > "$d/harness/corpus-repo"
for n in 1 2 3 4 5 6; do printf '# 원문 %s\n' "$n" > "$d/docs/ko/part$n.md"; done
out="$(cd "$d" && bash scripts/check-conventions.sh 2>&1)"; rc=$?
if [ "$rc" = 1 ] && grep -qF "states no reason" <<< "$out" && grep -qF "wholesale carve-out" <<< "$out"; then
  echo "  PASS: a reasonless corpus marker fails and lifts nothing [0]"; pass=$((pass + 1))
else
  echo "  FAIL: a reasonless corpus marker fails and lifts nothing [0] (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        | /'; fail=$((fail + 1))
fi

# 21g) the marker lifts the share limit only: a broad prefix is still refused.
d="$(new_repo)"
mkdir -p "$d/harness"
printf 'docs/\n' > "$d/harness/conventions-exclude"
printf 'Reproduces the official criteria verbatim; the source text cannot be edited.\n' > "$d/harness/corpus-repo"
printf '# doc\n\n일반 문장에서 커밋을 남겼다.\n' > "$d/docs/hidden.md"
assert_repo "a corpus repository still refuses a broad exclude prefix [0]" "$d" 1 "broad prefix"

# 21h) a marker that is not a regular file is refused like a reasonless one.
d="$(new_repo)"
mkdir -p "$d/harness/corpus-repo" "$d/vendor/iso-standard"
printf 'vendor/iso-standard/\n' > "$d/harness/conventions-exclude"
printf '# reproduced official text\n' > "$d/vendor/iso-standard/orig.md"
assert_repo "a corpus marker that is a directory is refused [0]" "$d" 1 "not a regular file"

# 22) a conventions-allow marker with no stated reason suppresses nothing and is reported
d="$(new_repo)"
printf '# doc\n\n%s\n' '일반 문장에서 커밋을 남겼다. <!-- conventions-allow -->' > "$d/docs/noreason.md"
assert_repo "reasonless conventions-allow marker is refused [0]" "$d" 1 "must state a reason"

# 22b) punctuation is not a reason either, or the bare blanket marker is back
d="$(new_repo)"
printf '# doc\n\n%s\n' '일반 문장에서 커밋을 남겼다. <!-- conventions-allow:--> -->' > "$d/docs/punct.md"
assert_repo "punctuation-only reason is refused [0]" "$d" 1 "must state a reason"

# 22b2) a reason in any script counts, and its first word may be short. Requiring three
# consecutive alphanumerics refused "공식 게시처 이름" and "an official title" as reasonless.
d="$(new_repo)"
printf '# doc\n\n%s\n%s\n' '공식 제목 인용: 커밋 정책. <!-- conventions-allow: 공식 게시처 이름 원문 보존 -->' \
  '공식 제목 인용: 커밋 정책. <!-- conventions-allow: an official title -->' > "$d/docs/reasons.md"
assert_repo "a Korean reason and a short first word are reasons [0]" "$d" 0 "RESULT: PASS"

# 22b3) two characters are still not a reason
d="$(new_repo)"
printf '# doc\n\n%s\n' '일반 문장에서 커밋을 남겼다. <!-- conventions-allow: ab -->' > "$d/docs/short.md"
assert_repo "a two-character reason is refused [0]" "$d" 1 "must state a reason"

# 22c) a documentation MENTION of the marker inside backticks must not suppress that line. It used
# to, invisibly: the suppression test read the raw line while the [0] audit strips code first.
d="$(new_repo)"
printf '# doc\n\n%s\n' 'The `conventions-allow: reason` marker suppresses a line. 커밋을 남겼다.' \
  > "$d/docs/mention.md"
assert_repo "a backticked mention of the marker does not suppress [2]" "$d" 1 "transliteration"

# 22d) a real marker still works
d="$(new_repo)"
printf '# doc\n\n%s\n' '공식 제목 인용: 커밋 정책. <!-- conventions-allow: quotes an official title -->' \
  > "$d/docs/real.md"
assert_repo "a marker with a real reason still suppresses [2]" "$d" 0 "RESULT: PASS"

# 22e) an unbalanced fence would hide everything after it from [2][3][4][5]
d="$(new_repo)"
printf '# doc\n\n```bash\necho hi\n\n일반 문장에서 커밋을 남겼다.\n' > "$d/docs/unbal.md"
assert_repo "unbalanced code fence is reported [0]" "$d" 1 "unbalanced code fence"

# 22f) an indented fence must be recognised as code, not scanned as prose
d="$(new_repo)"
printf '# doc\n\n- item:\n\n  ```bash\n  git merge  # 커밋 and A -> B\n  ```\n\ndone.\n' > "$d/docs/indent.md"
assert_repo "indented fence is treated as code [2][3]" "$d" 0 "RESULT: PASS"

# 22g) so must a tilde fence
d="$(new_repo)"
printf '# doc\n\n~~~bash\ngit merge  # 커밋 and A -> B\n~~~\n\ndone.\n' > "$d/docs/tilde.md"
assert_repo "tilde fence is treated as code [2][3]" "$d" 0 "RESULT: PASS"

# ---- [1] coverage: extensionless authored files ---------------------------------
# 23) an extensionless authored file (Dockerfile) is scanned by [1]
d="$(new_repo)"
printf 'FROM node:24\n# comment with an em dash %s here\n' "$EM_DASH" > "$d/Dockerfile"
assert_repo "em dash in an extensionless Dockerfile fails [1]" "$d" 1 "forbidden unicode"

# 24) so is a dotfile with no extension
d="$(new_repo)"
printf 'engine-strict=true\n# note %s here\n' "$EM_DASH" > "$d/.npmrc"
assert_repo "em dash in .npmrc fails [1]" "$d" 1 "forbidden unicode"

# 25) but a generated lockfile is not authored prose and stays out of scope
d="$(new_repo)"
printf 'lockfileVersion: 9\n# vendor text %s\n' "$EM_DASH" > "$d/pnpm-lock.yaml"
assert_repo "generated lockfile is out of scope [1]" "$d" 0 "RESULT: PASS"

# 26) the prose set follows the file, not its depth. Under a `^scripts/` anchor the playbook's own
# templates/monorepo/scripts/*.sh were structurally invisible to [2], so the standard shipped
# transliteration violations that surfaced only in the consumer, where they blocked the scaffolded
# project's first commit. A nested scripts/ path must be checked exactly like a top-level one.
d="$(new_repo)"
mkdir -p "$d/templates/monorepo/scripts"
printf '#!/usr/bin/env bash\n# 데이터 보존\n' > "$d/templates/monorepo/scripts/shutdown.sh"
assert_repo "nested scripts/*.sh is in the prose set [2]" "$d" 1 "transliteration"

d="$(new_repo)"
mkdir -p "$d/.github/scripts"
printf '#!/usr/bin/env bash\n# 위험 파라미터 점검\n' > "$d/.github/scripts/gate.sh"
assert_repo "a script under .github/scripts is in the prose set [2]" "$d" 1 "transliteration"

d="$(new_repo)"
mkdir -p "$d/templates/self-hosted/.github/workflows"
printf 'name: deploy\n# 배포 확인\n' > "$d/templates/self-hosted/.github/workflows/deploy.yml"
assert_repo "a nested .github/workflows yml is in the prose set [2]" "$d" 1 "transliteration"

# ---- the term dictionary: core plus data file ---------------------------------
# The core set is hard-coded in the checker and the data file may only ADD to it. Measured
# against 85 transliterations a Korean rewrite actually produces, the core caught 3, which
# made [2] a rule that passed 96 percent of what it exists to stop, right as D2 turned it
# into the primary gate on every document.
d="$(new_repo)"
mkdir -p "$d/harness"; printf 'server_ko_term\n' > /dev/null
printf '%s\n' '서버' > "$d/harness/conventions-terms"
printf '# doc\n\n서버가 응답한다.\n' > "$d/docs/term.md"
assert_repo "a term from conventions-terms fails [2]" "$d" 1 "transliteration"

# Deleting the data file must not weaken the rule below the core.
d="$(new_repo)"
printf '# doc\n\n어제 커밋을 남겼다.\n' > "$d/docs/core.md"
assert_repo "a core term fails [2] with no conventions-terms file at all" "$d" 1 "transliteration"

# An entry carrying a regex metacharacter is ignored rather than interpolated, so a stray
# `.` or `|` in the data file cannot silently widen the pattern to match everything.
d="$(new_repo)"
mkdir -p "$d/harness"; printf '.*\n' > "$d/harness/conventions-terms"
printf '# doc\n\nplain english line.\n' > "$d/docs/meta.md"
assert_repo "a regex metacharacter entry is ignored, not interpolated" "$d" 0 "RESULT: PASS"

# ---- inline code no longer silences [2] and [5] --------------------------------
# Both rules used to strip inline code spans before scanning, so one pair of backticks was a
# complete bypass. Under D2, backticks around terms become pervasive in Korean prose.
d="$(new_repo)"
printf '%s\n' '# doc' '' '어제 `커밋`을 남겼다.' > "$d/docs/tick.md"
assert_repo "a backticked transliteration still fails [2]" "$d" 1 "transliteration"

d="$(new_repo)"
printf '%s\n' '# doc' '' '문제가 생기면 재`deploy` 없이 되돌린다.' > "$d/docs/tick5.md"
assert_repo "a backticked term after the prefix still fails [5]" "$d" 1 "Korean prefix"

# ---- [5] covers the whole gluing prefix class ---------------------------------
d="$(new_repo)"
printf '# doc\n\n아직 미commit 상태다.\n' > "$d/docs/prefix2.md"
assert_repo "미 glued to an English term fails [5]" "$d" 1 "Korean prefix"

d="$(new_repo)"
printf '# doc\n\n비침습 방식이고 미완성이다.\n' > "$d/docs/prefix3.md"
assert_repo "the same prefixes before Hangul pass [5]" "$d" 0 "RESULT: PASS"

# ---- [1] covers the two invisible spaces ---------------------------------------
# A Korean IME emits both routinely, they break grep and diff like the other six, and each one
# additionally walked straight past [4], whose separator was ASCII-only. Built from escapes so
# this file carries no literal of them.
IDEO_SPACE="$(printf '\u3000')"   # ideographic space, built from an escape
NBSP="$(printf '\u00a0')"        # no-break space, likewise
d="$(new_repo)"
printf '# doc\n\n표준%s형식\n' "$IDEO_SPACE" > "$d/docs/ideo.md"
assert_repo "ideographic space U+3000 fails [1]" "$d" 1 "forbidden unicode"

d="$(new_repo)"
printf '# doc\n\n표준%s형식\n' "$NBSP" > "$d/docs/nbsp.md"
assert_repo "no-break space U+00A0 fails [1]" "$d" 1 "forbidden unicode"

# ---- [4] scans the whole prose set, not only markdown --------------------------
d="$(new_repo)"
printf '#!/usr/bin/env bash\n# 설정 (부연) 확인\n' > "$d/scripts/paren.sh"
assert_repo "a Korean spaced paren in a .sh fails [4]" "$d" 1 "opening-paren"

# ---- argument handling ---------------------------------------------------------
# A positional path used to be accepted and silently ignored, so a run that looked scoped to
# one directory had in fact scanned the whole tree.
d="$(new_repo)"
printf '# doc\n\nclean line.\n' > "$d/docs/ok.md"
git -C "$d" add -A >/dev/null 2>&1
out="$(cd "$d" && bash scripts/check-conventions.sh docs 2>&1)"; rc=$?
if [ "$rc" = 2 ] && grep -qF "unknown argument" <<< "$out"; then
  echo "  PASS: a positional path is rejected, not silently ignored"; pass=$((pass + 1))
else
  echo "  FAIL: a positional path is rejected, not silently ignored (rc=$rc)"; fail=$((fail + 1))
fi

# ---- --staged reads the index, not the working tree ----------------------------
# The file list came from git while the CONTENT came from disk, so staging a violation and
# then cleaning the worktree committed the violation with the hook installed and reporting OK.
d="$(new_repo)"
printf '%s\n' '# doc' '' '어제 커밋을 남겼다.' > "$d/docs/staged.md"
git -C "$d" add -A >/dev/null 2>&1
printf '# doc\n\nclean english line.\n' > "$d/docs/staged.md"     # worktree cleaned, NOT re-added
out="$(cd "$d" && bash scripts/check-conventions.sh --staged 2>&1)"; rc=$?
if [ "$rc" = 1 ] && grep -qF "transliteration" <<< "$out"; then
  echo "  PASS: --staged reads the staged blob, not the working tree"; pass=$((pass + 1))
else
  echo "  FAIL: --staged reads the staged blob, not the working tree (rc=$rc)"; fail=$((fail + 1))
fi

# And the same repo in whole-tree mode legitimately passes, which is what made the gap
# invisible: both answers are correct for the file each mode is reading.
out="$(cd "$d" && bash scripts/check-conventions.sh 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then
  echo "  PASS: whole-tree mode reads the working tree (each mode answers for its own input)"; pass=$((pass + 1))
else
  echo "  FAIL: whole-tree mode reads the working tree (rc=$rc)"; fail=$((fail + 1))
fi

# ---- [6] relative markdown links must resolve ---------------------------------
# The documents ARE this repository's product, and until now every gate checked code while
# nothing checked them: a rename or a move broke a cross-reference and no run said so. The
# only link check that existed was in the playbook-only Stop hook and only over docs/*.md.
d="$(new_repo)"
printf '# a\n\nsee [b](b.md).\n' > "$d/docs/a.md"
printf '# b\n' > "$d/docs/b.md"
assert_repo "a resolving relative link passes [6]" "$d" 0 "RESULT: PASS"

d="$(new_repo)"
printf '# a\n\nsee [gone](nope.md).\n' > "$d/docs/a.md"
assert_repo "a broken relative link fails [6]" "$d" 1 "broken relative link"

# An anchor on a target that exists is fine; the anchor itself is not resolved.
d="$(new_repo)"
printf '# a\n\nsee [b](b.md#some-section).\n' > "$d/docs/a.md"
printf '# b\n' > "$d/docs/b.md"
assert_repo "an anchor on an existing target passes [6]" "$d" 0 "RESULT: PASS"

# A same-file anchor addresses this document and has no path to resolve.
d="$(new_repo)"
printf '# a\n\njump to [here](#somewhere).\n' > "$d/docs/a.md"
assert_repo "a same-file anchor passes [6]" "$d" 0 "RESULT: PASS"

# An external target is out of scope: this checker never reaches the network.
d="$(new_repo)"
printf '# a\n\nsee [site](https://example.com/x) and [mail](mailto:a@b.c).\n' > "$d/docs/a.md"
assert_repo "http and mailto targets are out of scope for [6]" "$d" 0 "RESULT: PASS"

# A placeholder in an example is not a link. docs/16 writes exactly this shape while
# explaining the link convention itself.
d="$(new_repo)"
printf '# a\n\nwrite it as [07-...](07-...md) or [x](<name>.md).\n' > "$d/docs/a.md"
assert_repo "a placeholder target is not treated as a link [6]" "$d" 0 "RESULT: PASS"

# A link inside a fenced code block is a code sample, not a cross-reference.
d="$(new_repo)"
{ printf '# a\n\n'; printf '```markdown\n'; printf 'see [gone](nope.md)\n'; printf '```\n'; } > "$d/docs/a.md"
assert_repo "a link inside a code fence is ignored by [6]" "$d" 0 "RESULT: PASS"

# A link up out of docs/ resolves against the LINKING file's directory, not the repo root.
d="$(new_repo)"
mkdir -p "$d/harness"; printf 'x\n' > "$d/harness/thing.sh"
printf '# a\n\nsee [thing](../harness/thing.sh).\n' > "$d/docs/a.md"
assert_repo "a parent-relative link resolves from the linking file [6]" "$d" 0 "RESULT: PASS"

echo
echo "RESULT: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1
