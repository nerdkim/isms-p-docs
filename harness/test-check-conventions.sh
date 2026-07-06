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

if ! echo x | grep -qP x 2>/dev/null; then
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
  if [ -n "$expect_sub" ]; then printf '%s' "$out" | grep -qF "$expect_sub" || ok=0; fi
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

# 6) ASCII arrow in prose fails [3]
d="$(new_repo)"
printf '# doc\n\n데이터가 A -> B 로 흐른다.\n' > "$d/docs/arrow.md"
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

# 11) docs/16 is excluded from [2][3][4] (its own examples name the forms)
d="$(new_repo)"
printf '# conventions\n\n커밋 and A -> B and 한글 (부연) as examples.\n' \
  > "$d/docs/16-documentation-conventions.md"
assert_repo "docs/16 excluded from [2][3][4]" "$d" 0 "RESULT: PASS"

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

# 16) a Korean-designated doc (.ko.md) may use Korean IT terms; [2] is skipped there
d="$(new_repo)"
printf '# 배포\n\n소스를 빌드해 배포한다. 재배포도 한국어로 쓴다.\n' > "$d/docs/DEPLOY.ko.md"
assert_repo ".ko.md skips transliteration [2]" "$d" 0 "RESULT: PASS"

# 17) but the same Korean term in a plain .md still fails [2]
d="$(new_repo)"
printf '# doc\n\n소스를 빌드해 배포한다.\n' > "$d/docs/deploy-plain.md"
assert_repo "plain .md still fails transliteration [2]" "$d" 1 "transliteration"

# 18) the Korean governance docs (agent-conduct.md, korean-honorifics.md) use natural Korean; [2] skips them
d="$(new_repo)"
printf '# conduct\n\n응대는 자연스러운 한국어로 배포와 빌드를 쓴다.\n' > "$d/docs/agent-conduct.md"
assert_repo "agent-conduct.md skips transliteration [2]" "$d" 0 "RESULT: PASS"

echo
echo "RESULT: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1
