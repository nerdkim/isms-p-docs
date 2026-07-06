#!/usr/bin/env bash
# check-conventions.sh - enforce docs/16 documentation conventions on this repo.
#
# Checks:
#   [1] forbidden unicode punctuation (docs/16 s2.1): em dash U+2014, en dash
#       U+2013, horizontal bar U+2015, middle dot U+00B7, bullet U+2022,
#       fullwidth hyphen U+FF0D.
#   [2] a Korean transliteration / translation of an IT term inside an ENGLISH doc
#       (docs/16 s3.1). Korean-language docs use natural Korean, so [2] is skipped for
#       `*.ko.md` and the Korean governance docs (agent-conduct.md, korean-honorifics.md);
#       it only keeps a Korean term from slipping into English-designated text.
#   [3] prose arrows must be the arrow char (docs/16 s2.1): use U+2192, not the
#       ASCII "->". Code fences / mermaid / shell keep ASCII (excluded here).
#   [4] Korean opening-paren spacing (docs/16 s4.3): no space before "(" when it
#       follows Hangul. Write "한글(부연)", not "한글 (부연)".
#   [5] Korean prefix glued to an English term (docs/16 s3.2): do not stick "재"
#       to an English word (재deploy). Use "re-deploy" or "다시 deploy".
#
# Scope: standard artifacts (docs, templates, root markdown, scripts, harness,
# workflows). The file list is the union of tracked files and untracked-but-not-
# ignored files (git ls-files --others --exclude-standard), so a manual run before
# git add catches brand-new files; .gitignore is respected. Excludes _research/ and
# any path prefixes listed in harness/conventions-exclude (see below).
# Checks [2][3][4][5] also exclude docs/16 (the rule-definition file, which names the
# forbidden forms as examples) and this script. Checks [3][4] run on prose .md
# only (code files keep ASCII arrows). Term/arrow/paren/prefix scans strip fenced code
# blocks and inline code first.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

if ! echo x | grep -qP x 2>/dev/null; then
  echo "error: GNU grep -P (PCRE) required" >&2; exit 2
fi

# Path prefixes excluded from scanning. `_research/` is always excluded. A repo may
# add more in harness/conventions-exclude (one path prefix per line, # comments ok):
# use this ONLY for authoritative external data corpora that are not the project's own
# prose (e.g. a reproduced official standard/document collection), never to hide the
# project's own docs from the rules. Adopt such an exclusion only as a confirmed
# exception (docs/16 6).
EXCLUDE_RE='^_research/'
if [ -f harness/conventions-exclude ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && EXCLUDE_RE="$EXCLUDE_RE|^${line}"
  done < harness/conventions-exclude
fi
mapfile -t FILES < <( { git ls-files '*.md' 'initialize.sh' 'install-playbook.sh' 'scripts/*.sh' 'harness/*.sh' '.github/workflows/*.yml'; git ls-files --others --exclude-standard '*.md' 'initialize.sh' 'install-playbook.sh' 'scripts/*.sh' 'harness/*.sh' '.github/workflows/*.yml'; } | grep -vE "$EXCLUDE_RE" | sort -u )
# exclude the rule-definition file and the checker scripts from term/arrow/paren
# checks. Matched by basename so this works whether the checker lives in harness/
# (this repo) or wherever a consumer installs it. test-check-conventions.sh
# intentionally embeds violation fixtures as test data, so it must be excluded
# here (its own comments are kept clean).
EXCL='docs/16-documentation-conventions\.md$|(^|/)check-conventions\.sh$|(^|/)test-check-conventions\.sh$'
mapfile -t TFILES < <(printf '%s\n' "${FILES[@]}" | grep -vE "$EXCL")
mapfile -t MDFILES < <(printf '%s\n' "${TFILES[@]}" | grep -E '\.md$')

# A line containing the marker `conventions-allow` is skipped by the term/arrow/paren/prefix
# checks [2][3][4][5] (never [1] forbidden unicode, which is scanned raw). Use it for a
# line that legitimately carries a forbidden form, e.g. quoting an official title/proper
# noun verbatim: add a trailing HTML comment like
#   <!-- conventions-allow: quotes the official ISMS-P control title -->
# strip fenced code blocks (keep line numbers), inline code spans, and allow-marked lines
strip() { awk 'BEGIN{inf=0} /^```/{inf=!inf; print ""; next} /conventions-allow/{print ""; next} {if(inf){print ""} else {gsub(/`[^`]*`/,""); print}}' "$1"; }
# strip fenced code blocks and allow-marked lines only (keep inline code; removing it
# would falsely join Korean text and a following "(" across an inline-code span for [4]).
stripfence() { awk 'BEGIN{inf=0} /^```/{inf=!inf; print ""; next} /conventions-allow/{print ""; next} {if(inf){print ""} else {print}}' "$1"; }

fail=0

echo "== [1] forbidden unicode punctuation =="
if grep -rnP '[\x{2014}\x{2013}\x{2015}\x{00B7}\x{2022}\x{FF0D}]' "${FILES[@]}"; then
  echo "  -> FAIL (see above)"; fail=1
else echo "  OK: 0"; fi

echo "== [2] transliteration / translation terms (docs/16 s3.1) =="
# 계층(hierarchy)/저장소(storage) omitted (common Korean homographs, review by hand).
# 머지 uses a negative lookbehind so 나머지 (the rest) does not match.
TPAT='리포지토리|레포|커밋|브랜치|푸시|(?<!나)머지|배포|의존성|근본원인|모듈|레이어|캐시|워크플로우|파이프라인|태그|스택|빌드|번들|컨테이너|롤백|마이그레이션|리팩터링|프리티어|프레임워크|아티팩트|바이너리|시크릿|토큰|헤더|스토어|폴리필|싱글턴|싱글톤|런타임|데몬|워커|미들웨어|화이트리스트|블랙리스트|네이티브|디렉터리|인프라|크롤링|스크래핑|프롬프트|티어|인벤토리|토폴로지|데이터베이스|오케스트레이션|리졸버|스크립트|타임존|테스트|프로비저닝|네이밍|데이터|컴포넌트|아키텍처|리소스|타깃|프론트엔드|백엔드|네트워크|리전|파라미터|콘솔|트리거|스텝|인스턴스|스키마|프록시|스케줄러|폴링|워크로드|인그레스|멀티클라우드|오케스트레이터|크롤러|스캐폴딩|스캐폴드|부트스트랩|셋업|포맷|타임아웃|스토리지|레퍼런스|콜드스타트|태스크|프로파일|스냅샷|레코드|컬럼|매핑|소비측'
th=""
for f in "${TFILES[@]}"; do
  # Korean-language docs are written in natural Korean and may use Korean IT terms
  # (배포, 빌드, 출력값): a `.ko.md` file (docs/16 s4.1) and the Korean governance docs
  # (agent-conduct.md, korean-honorifics.md). Skip [2] for them. On the remaining
  # (English-designated) docs, [2] only keeps a Korean transliteration from slipping in.
  # [4] Korean-paren and [5] prefix-glue still apply to Korean docs; [1]/[3] apply to all.
  case "$f" in *.ko.md|*agent-conduct.md|*korean-honorifics.md) continue;; esac
  h=$(strip "$f" | grep -noP "($TPAT)" | sed "s#^#${f}:#"); [ -n "$h" ] && th+="$h"$'\n'
done
th=$(printf '%s' "$th" | sed '/^$/d')
if [ -n "$th" ]; then echo "$th"; echo "  -> FAIL: $(printf '%s\n' "$th" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

echo "== [3] prose arrows (use U+2192, not ASCII ->) =="
ah=""
for f in "${MDFILES[@]}"; do
  h=$(strip "$f" | grep -noP '(?<!-)\-\>' | sed "s#^#${f}:#"); [ -n "$h" ] && ah+="$h"$'\n'
done
ah=$(printf '%s' "$ah" | sed '/^$/d')
if [ -n "$ah" ]; then echo "$ah"; echo "  -> FAIL: $(printf '%s\n' "$ah" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

echo "== [4] Korean opening-paren spacing (한글(부연), no space) =="
ph=""
for f in "${MDFILES[@]}"; do
  h=$(stripfence "$f" | grep -noP '[가-힣] +\(' | sed "s#^#${f}:#"); [ -n "$h" ] && ph+="$h"$'\n'
done
ph=$(printf '%s' "$ph" | sed '/^$/d')
if [ -n "$ph" ]; then echo "$ph"; echo "  -> FAIL: $(printf '%s\n' "$ph" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

echo "== [5] Korean prefix glued to an English term (재deploy -> re-deploy / 다시 deploy) =="
# Korean "재" (re-) stuck directly to an ASCII letter is the anti-pattern. 재배포/재구축
# (재 + Hangul) do not match; only 재 immediately followed by [A-Za-z] does.
kh=""
for f in "${TFILES[@]}"; do
  h=$(strip "$f" | grep -noP '재(?=[A-Za-z])' | sed "s#^#${f}:#"); [ -n "$h" ] && kh+="$h"$'\n'
done
kh=$(printf '%s' "$kh" | sed '/^$/d')
if [ -n "$kh" ]; then echo "$kh"; echo "  -> FAIL: $(printf '%s\n' "$kh" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

if [ "$fail" -ne 0 ]; then echo; echo "RESULT: FAIL (docs/16 conventions)."; exit 1; fi
echo; echo "RESULT: PASS (docs/16 conventions)."
