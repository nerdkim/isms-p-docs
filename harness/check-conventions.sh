#!/usr/bin/env bash
# check-conventions.sh - enforce docs/16 documentation conventions on this repo.
#
# Checks:
#   [1] forbidden unicode punctuation (docs/16 s2.1): em dash U+2014, en dash
#       U+2013, horizontal bar U+2015, middle dot U+00B7, bullet U+2022,
#       fullwidth hyphen U+FF0D, plus the two invisible spaces a Korean IME emits
#       routinely, ideographic space U+3000 and no-break space U+00A0. The invisible
#       pair belongs here for the same reason as the rest: it breaks grep and diff, and
#       it additionally walked straight past check [4], whose separator was ASCII-only.
#   [2] a Korean transliteration / translation of an IT term, in ANY document
#       (docs/16 s3.1). Documents are Korean prose whose IT and engineering terms stay in
#       English ("commit을 push합니다", never the transliteration), which is the same rule the
#       assistant's replies follow. So [2] applies to every document with no language
#       exemption: a Korean-language file is exactly the file this check exists to scan.
#       The only exemption is by declared path: a Korean project's deliverables for Korean
#       readers, listed with a reason in `harness/korean-content` (D71), skip [2] alone.
#       The term dictionary lives in `harness/conventions-terms`, which may only ADD to the
#       core set hard-coded below (see SELF-DEFENSE).
#   [3] prose arrows must be the arrow char (docs/16 s2.1): use U+2192, not the
#       ASCII "->". Code fences / mermaid / shell keep ASCII (excluded here).
#   [4] Korean opening-paren spacing (docs/16 s4.3): no space before "(" when it
#       follows Hangul. Write "한글(부연)", not the spaced form.
#   [5] a Sino-Korean prefix glued to an English term (docs/16 s3.2): do not stick
#       재/비/미/반/역/준/초/무/탈 to an English word (재deploy, 미commit). Use
#       "re-deploy" / "다시 deploy", or a fully Korean form (재배포).
#   [6] a relative markdown link whose target does not exist. The documents ARE this
#       repository's product, and until now every gate checked code while nothing checked
#       them: a rename or a move broke a cross-reference and no run said so.
#
# Scope: the file list is the union of tracked files and untracked-but-not-ignored files
# (git ls-files --others --exclude-standard), so a manual run before git add catches brand-new
# files; .gitignore is respected. Excludes _research/ and any path prefixes listed in
# harness/conventions-exclude (see below).
# Check [1] scans EVERY authored text file, including extensionless ones (Dockerfile,
# Makefile, Caddyfile, .npmrc), because docs/16 s2.1 forbids the 6 characters in any file.
# Binary files are skipped by grep -I, and generated or vendored artifacts (lockfiles,
# minified bundles, source maps, images, fonts, archives) are excluded because their content
# is not authored prose.
# Checks [2][3][4][5] are prose rules on documents and scripts. Only [2] excludes docs/16 and
# this script, because those two carry the term dictionary itself and must be able to name the
# forms they forbid; [3][4][5] now apply to them like any other file, which immediately
# surfaced three real violations inside the document that defines the rules.
# Check [3] runs on prose .md only (code files keep ASCII arrows). Checks [2][4][5] run on the
# whole prose set. The scans strip fenced code blocks; [2][4][5] KEEP inline code spans,
# because a term inside backticks was a one-character way to silence [2] and [5].
#
# SELF-DEFENSE [0] (docs/16 s6.2): the two documented exception mechanisms are themselves the
# cheapest way to disable this checker, so the checker validates its own exceptions.
#   - harness/conventions-exclude may not carry a broad prefix (`.`, `docs/`, `harness/`,
#     `src/`, a bare top-level directory) and may not remove most of the tree. Either is a
#     FAIL. docs/16 s6.2 already says neither exception exists for "hiding the project's own
#     documents from the rules"; [0] makes that sentence mechanical.
#   - a `conventions-allow` marker must state a reason (`conventions-allow: <why>`). A bare
#     marker suppresses nothing and is reported, so a reasonless blanket suppression cannot be
#     sprinkled across the tree.
#   - harness/conventions-terms may only ADD to the core term set. A missing, emptied or
#     truncated file cannot weaken [2] below the core, because the core is hard-coded here and
#     the file is unioned with it, never substituted for it. Deleting the file is therefore a
#     no-op on the core rule rather than a way to switch [2] off.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# ---- mode --------------------------------------------------------------------
# Default is the whole tree, which is what CI must keep doing: a rule that only ever sees the
# diff cannot notice that an untouched file has drifted.
#
#   --staged  scan only the paths in the index, reading the STAGED BLOB rather than the file on
#             disk. Two separate defects close here. Speed: the whole-tree scan is linear in
#             markdown files and measured 21.7 s at 1000 files and 69 s at 3000, and a gate that
#             costs a minute per commit teaches --no-verify, which turns every local gate off at
#             once. Correctness: the file list came from git while the CONTENT came from the
#             working tree, so staging a violation and then cleaning the worktree committed the
#             violation with the hook installed, enabled, and reporting OK.
#
# Positional arguments used to be accepted and silently ignored, so `check-conventions.sh docs`
# scanned the whole tree while looking as though it had scanned one directory. They are now an
# error.
MODE="all"
while [ $# -gt 0 ]; do
  case "$1" in
    --staged) MODE="staged"; shift ;;
    --all)    MODE="all"; shift ;;
    -h|--help) grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown argument '$1'. This checker takes no path; use --staged or --all." >&2
       exit 2 ;;
  esac
done

# PFX is prepended when READING a file and never when reporting it, so a message always names
# the repo-relative path whichever mode is running.
PFX=""
STAGEDIR=""
cleanup_stage() { [ -n "$STAGEDIR" ] && rm -rf "$STAGEDIR"; }
trap cleanup_stage EXIT

# No pipe into `grep -q` (see check-structure-conformance.sh): under pipefail an early match can
# fail the pipe through SIGPIPE, so variables go in with a here-string.
if ! grep -qP x <<< x 2>/dev/null; then
  echo "error: GNU grep -P (PCRE) required" >&2; exit 2
fi
# Fail CLOSED on a locale where grep -P cannot match a `\x{...}` code point. In a non-UTF-8
# locale grep exits 2 with "character value in \x{} or \o{} is too large", and treating that
# error as "no match" would make the forbidden-character check silently pass everywhere. Probe
# it once with a real em dash byte sequence, and refuse to run rather than report a false PASS.
if ! grep -qP '[\x{2014}]' <<< $'\xe2\x80\x94' 2>/dev/null; then
  echo "error: grep -P cannot match \\x{...} in this locale (LC_ALL=${LC_ALL:-unset}, LANG=${LANG:-unset})." >&2
  echo "       Re-run under a UTF-8 locale, e.g. LC_ALL=C.UTF-8 bash $0" >&2
  exit 2
fi

# Path prefixes excluded from scanning. `_research/` is always excluded. A repo may
# add more in harness/conventions-exclude (one path prefix per line, # comments ok):
# use this ONLY for authoritative external data corpora that are not the project's own
# prose (e.g. a reproduced official standard/document collection), never to hide the
# project's own docs from the rules. Adopt such an exclusion only as a confirmed
# exception (docs/16 6).
fail=0

# A prefix that would switch the rules off for the project's own source. `.` and `/` cover the
# whole tree; the named directories are where a project's own prose and code live. A bare
# single-segment path (no `/`) that is a real directory is also refused, since it silences that
# entire directory. An external corpus lives at a specific nested path (`vendor/iso-standard/`),
# which none of these patterns match.
BROAD_RE='^(\.|/|\*|\.\*|\.\/)$|^(docs|harness|templates|src|apps|packages|scripts|lib|test|tests|infra|deploy|\.github|_workspace)/?$'

# .korean-style/ is the rule file and tooling of the Korean writing style (docs/22 s6). Its rules must
# list the very transliterations and characters they forbid, and its own installer owns the directory,
# so it is excluded here the way _research/ is, rather than through a per-repo exclude file.
EXCLUDE_RE='^_research/|^\.korean-style/'
USER_EXCLUDE_RE=''
if [ -f harness/conventions-exclude ]; then
  bad_ex=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"; line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] || continue
    # The entry is later interpolated into a regex, so a metacharacter would let a narrow-looking
    # entry match broadly: `docs/.` and `[d]ocs/` both hide the whole docs tree while sailing past
    # a literal comparison against BROAD_RE. Require a plain path, so what the entry looks like is
    # what it matches. Also refuse an entry that is not a valid regex, since an invalid one makes
    # every later grep -E error out and the checker would report PASS having scanned nothing.
    if grep -qE '[][*?+(){}|^$\\.]' <<< "$line"; then
      bad_ex="${bad_ex}  ${line}  (regex metacharacter: use a plain literal path prefix)"$'\n'
      continue
    fi
    if ! grep -qE "^${line}" <<< x 2>/dev/null && ! grep -qE "^${line}" <<< "$line" 2>/dev/null; then
      bad_ex="${bad_ex}  ${line}  (not a usable path prefix)"$'\n'
      continue
    fi
    if grep -qE "$BROAD_RE" <<< "$line"; then
      bad_ex="${bad_ex}  ${line}  (broad prefix: silences the project's own files)"$'\n'
      continue
    fi
    if [ "${#line}" -lt 3 ]; then
      bad_ex="${bad_ex}  ${line}  (too short to be a specific corpus path)"$'\n'
      continue
    fi
    EXCLUDE_RE="$EXCLUDE_RE|^${line}"
    USER_EXCLUDE_RE="${USER_EXCLUDE_RE:+$USER_EXCLUDE_RE|}^${line}"
  done < harness/conventions-exclude
  if [ -n "$bad_ex" ]; then
    echo "== [0] conventions-exclude self-defense =="
    printf '%s' "$bad_ex"
    echo "  -> FAIL: harness/conventions-exclude exists only for an authoritative EXTERNAL data"
    echo "     corpus, never to hide the project's own documents from the rules (docs/16 s6.2)."
    fail=1
  fi
fi

# Authored-text file set for [1]. Everything tracked or newly added, minus generated and
# vendored artifacts whose content nobody wrote by hand. grep -I skips anything still binary,
# so extensionless authored files (Dockerfile, Makefile, Caddyfile, .npmrc, CODEOWNERS) are in
# scope without maintaining an extension allowlist.
GENERATED_RE='\.(png|jpe?g|gif|ico|webp|avif|bmp|tiff?|woff2?|ttf|otf|eot|pdf|zip|gz|tgz|bz2|xz|7z|jar|so|dylib|dll|exe|wasm|mp3|mp4|mov|avi|webm|ogg|wav|class|pyc|o|a|bin|dat|db|sqlite3?)$|(^|/)(pnpm-lock\.yaml|package-lock\.json|yarn\.lock|poetry\.lock|uv\.lock|Cargo\.lock|Gemfile\.lock|composer\.lock|\.terraform\.lock\.hcl)$|\.min\.(js|css)$|\.map$'
# `grep .` drops empty lines, so an empty repo yields a genuinely empty array rather than an
# array holding one empty string (which would reach grep as an empty filename).
# `-c core.quotePath=false` so a path containing non-ASCII characters is emitted literally instead of
# as an escaped "\355\225..." string. A quoted path never matches a real filename, so grep would
# error on it and, worse, that file would be silently absent from the scan set: a single
# Korean-named file would otherwise make check [1] report OK for the whole repository.
if [ "$MODE" = "staged" ]; then
  # ACMR: added, copied, modified, renamed. A deletion has no content to scan.
  mapfile -t ALLTEXT < <( git -c core.quotePath=false diff --cached --name-only --diff-filter=ACMR \
                          | grep -vE "$GENERATED_RE" | grep . | sort -u )
  if [ "${#ALLTEXT[@]}" -gt 0 ]; then
    STAGEDIR="$(mktemp -d)"; PFX="$STAGEDIR/"
    for f in "${ALLTEXT[@]}"; do
      mkdir -p "$STAGEDIR/$(dirname "$f")"
      # The staged blob, not the working copy. That difference is the whole point of this mode.
      git show ":$f" > "$STAGEDIR/$f" 2>/dev/null || : > "$STAGEDIR/$f"
    done
  fi
else
  mapfile -t ALLTEXT < <( { git -c core.quotePath=false ls-files; \
                            git -c core.quotePath=false ls-files --others --exclude-standard; } \
                          | grep -vE "$GENERATED_RE" | grep . | sort -u )
fi
mapfile -t UFILES  < <( printf '%s\n' ${ALLTEXT+"${ALLTEXT[@]}"} | grep . | grep -vE "$EXCLUDE_RE" )

# A repository that IS an external corpus (a reproduced official standard published as a site,
# for example) has most of its tree under conventions-exclude by nature, so the 40% limit below
# would block it for good. `harness/corpus-repo` declares that, and its first non-comment line
# must say why (10 or more characters), as harness/public-repo does: a bare or unreadable marker
# grants nothing and is a FAIL. With a valid marker only the 40% limit is lifted. Every exclude
# entry must still be a specific plain path, every file outside it is still checked, and the
# share is still announced. The marker is committed, so declaring it shows up in review.
CORPUS_REPO=0
if [ -e harness/corpus-repo ] || [ -L harness/corpus-repo ]; then
  corpus_bad=""
  if [ -L harness/corpus-repo ] || [ ! -f harness/corpus-repo ]; then
    corpus_bad="harness/corpus-repo is not a regular file"
  else
    corpus_reason="$(grep -vE '^[[:space:]]*(#|$)' harness/corpus-repo 2>/dev/null | head -1 | tr -d '[:space:]')"
    if [ "${#corpus_reason}" -ge 10 ]; then
      CORPUS_REPO=1
    else
      corpus_bad="harness/corpus-repo states no reason (its first non-comment line must give one, 10 or more characters)"
    fi
  fi
  if [ -n "$corpus_bad" ]; then
    echo "== [0] conventions-exclude self-defense =="
    echo "  -> FAIL: ${corpus_bad}; it grants nothing and the 40% limit still applies (docs/16 s6.2)."
    fail=1
  fi
fi

# A conventions-exclude that removes most of the tree defeats the checker even when every
# individual prefix looks specific. Measure what the USER prefixes remove and refuse a
# wholesale carve-out. The share is of the whole tree in both modes: a staged commit that only
# refreshes a vendored corpus is nearly all excluded paths, and measuring the staged set blocked
# every such update while a carve-out could hide behind a commit that stages one other file.
if [ "$MODE" = "staged" ]; then
  mapfile -t TREE < <( git -c core.quotePath=false ls-files | grep -vE "$GENERATED_RE" | grep . | sort -u )
else
  TREE=( ${ALLTEXT+"${ALLTEXT[@]}"} )
fi
if [ -n "$USER_EXCLUDE_RE" ] && [ "${#TREE[@]}" -gt 0 ]; then
  hidden="$(printf '%s\n' "${TREE[@]}" | grep -cE "$USER_EXCLUDE_RE" || true)"
  share=$((hidden * 100 / ${#TREE[@]}))
  if [ "$CORPUS_REPO" = 1 ]; then
    echo "== [0] conventions-exclude self-defense =="
    echo "  corpus repository (harness/corpus-repo): harness/conventions-exclude hides $hidden of ${#TREE[@]} files (${share}%); the 40% limit does not apply"
  elif [ "$hidden" -gt 0 ] && [ "$share" -ge 40 ]; then
    echo "== [0] conventions-exclude self-defense =="
    echo "  harness/conventions-exclude hides $hidden of ${#TREE[@]} files (${share}%)"
    echo "  -> FAIL: an exclusion covering 40% or more of the tree is a wholesale carve-out,"
    echo "     not an external-corpus exception (docs/16 s6.2). A repository that is itself a"
    echo "     reproduced external corpus says so, with the reason, in harness/corpus-repo."
    fail=1
  fi
fi

# Korean deliverables (D71, docs/16 s3.1 and s6.2). Rule [2] keeps the IT terms of a document in
# English, which is right for the standard and for a project's own engineering documents, and wrong
# for what a Korean project writes for Korean readers: a Korean control document uses the Korean
# words its readers use, and the Korean writing skill tells Claude to write them that way.
# harness/korean-content names those paths, one plain path prefix per line (`#` comments ok), and a
# line starting with `reason:` says why in 10 or more characters. With a valid file [2] skips the
# listed paths and nothing else changes: [1] and [3] to [6] still scan them. A file without a reason,
# or with an entry that carries a regex metacharacter, names the whole tree or harness/, or is shorter
# than 3 characters, grants nothing and is a FAIL. It hides no file from the forbidden-character scan
# the way conventions-exclude does, so there is no 40% limit, and [2] announces what it skipped.
KC_RE=''
KC_PATHS=''
if [ -e harness/korean-content ] || [ -L harness/korean-content ]; then
  kc_bad=""; kc_reason=0; kc_re=""; kc_paths=""
  if [ -L harness/korean-content ] || [ ! -f harness/korean-content ]; then
    kc_bad="  harness/korean-content is not a regular file"$'\n'
  else
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%%#*}"
      if [[ "$line" =~ ^[[:space:]]*reason: ]]; then
        kc_why="$(printf '%s' "${line#*reason:}" | tr -d '[:space:]')"
        [ "${#kc_why}" -ge 10 ] && kc_reason=1
        continue
      fi
      line="$(printf '%s' "$line" | tr -d '[:space:]')"
      [ -n "$line" ] || continue
      # Interpolated into a regex below, as conventions-exclude entries are, so only a plain path.
      if grep -qE '[][*?+(){}|^$\\.]' <<< "$line"; then
        kc_bad="${kc_bad}  ${line}  (regex metacharacter: use a plain literal path prefix)"$'\n'
        continue
      fi
      if [ "${#line}" -lt 3 ] || grep -qE '^(/+|harness(/.*)?)$' <<< "$line"; then
        kc_bad="${kc_bad}  ${line}  (the whole tree, harness/ or too short: name the Korean deliverables)"$'\n'
        continue
      fi
      kc_re="${kc_re:+$kc_re|}^${line}"
      kc_paths="${kc_paths:+$kc_paths }${line}"
    done < harness/korean-content
    [ "$kc_reason" = 1 ] ||
      kc_bad="${kc_bad}  harness/korean-content states no reason (a line 'reason: ...' of 10 or more characters)"$'\n'
  fi
  if [ -n "$kc_bad" ]; then
    echo "== [0] korean-content self-defense =="
    printf '%s' "$kc_bad"
    echo "  -> FAIL: harness/korean-content grants nothing, so [2] still scans every path (docs/16 s6.2)."
    fail=1
  else
    KC_RE="$kc_re"
    KC_PATHS="$kc_paths"
  fi
fi

# Prose file set for [2][3][4][5]: documents plus the standard's own scripts and workflows.
#
# The path patterns are anchored with `(^|/)`, not `^`, so a file matches wherever it sits in the
# tree. That is not cosmetic. Under `^scripts/.*\.sh$` the playbook's own
# `templates/monorepo/scripts/shutdown.sh` was structurally invisible here, while the identical
# file, once scaffolded into a project as `scripts/shutdown.sh`, WAS in scope. The standard shipped
# a template carrying three transliteration violations, its own gate could not see them, and they
# surfaced only in the consumer, where they blocked the scaffolded project's very first commit. A
# checker that cannot see the artifacts it distributes is not enforcing the standard on them, so
# the prose set now follows the file rather than its depth.
#
# The three git hooks are extensionless, so an extension-shaped pattern could never reach them
# even though all three carry Korean operator messages. They are named explicitly.
mapfile -t FILES < <( printf '%s\n' ${UFILES+"${UFILES[@]}"} \
  | grep -E '\.md$|(^|/)initialize\.sh$|(^|/)install-playbook\.sh$|(^|/)bootstrap\.sh$|(^|/)scripts/.*\.sh$|(^|/)harness/.*\.sh$|(^|/)harness/githooks/[a-z][a-z-]*$|(^|/)\.github/workflows/.*\.ya?ml$' )
# exclude the rule-definition file and the checker scripts from term/arrow/paren
# checks. Matched by basename so this works whether the checker lives in harness/
# (this repo) or wherever a consumer installs it. test-check-conventions.sh
# intentionally embeds violation fixtures as test data, so it must be excluded
# here (its own comments are kept clean).
# Two tiers, not one. The whole-file exclusion used to remove docs/16 and this script from
# [2][3][4][5] alike, and it was hiding three genuine [4] violations inside the very document
# that defines rule [4]. Only the two "name the forbidden form" rules need the exemption:
# [2] because docs/16 carries the Korean|English term table and this script carries the
# dictionary, and [5] because both spell out the glued prefixes they reject. [3] arrows and
# [4] Korean paren spacing now apply to them like any other file.
#
# test-check-conventions.sh stays out of all four: it embeds violation fixtures as test data
# on purpose, so scanning it would report its own corpus.
EXCL_ALL='(^|/)test-check-conventions\.sh$'
EXCL_TERMS='docs/16-documentation-conventions\.md$|(^|/)check-conventions\.sh$'
mapfile -t TFILES  < <(printf '%s\n' "${FILES[@]}" | grep -vE "$EXCL_ALL")
mapfile -t TERMFILES < <(printf '%s\n' ${TFILES+"${TFILES[@]}"} | grep -vE "$EXCL_TERMS")   # [2] and [5]
mapfile -t MDFILES < <(printf '%s\n' ${TFILES+"${TFILES[@]}"} | grep -E '\.md$')

# A line carrying the marker `conventions-allow: <reason>` is skipped by the
# term/arrow/paren/prefix checks [2][3][4][5] (never [1] forbidden unicode, which is always
# scanned raw). Use it for a line that must carry a forbidden form to quote an official title
# or proper noun verbatim, as a trailing HTML comment:
#   <!-- conventions-allow: quotes the official ISMS-P control title -->
# The REASON IS MANDATORY. A bare `conventions-allow` with no `: <text>` suppresses nothing,
# so the suppression mechanism cannot be used as a silent blanket switch.
# The reason must contain real words. `conventions-allow:-->` satisfied a "non-whitespace follows"
# test and so restored the bare blanket marker this rule exists to prevent, so require three word
# characters after the colon, where spaces and punctuation may separate them. A word character is
# anything that is not space, punctuation or a control character, so any script counts: requiring
# three consecutive [[:alnum:]] made the first word decide, which refused a Korean reason that
# starts with a two-syllable word ("공식 게시처 이름") and an English one that starts with "an",
# and in mawk, which reads bytes, Hangul is not [[:alnum:]] at all, so strip() kept a line whose
# marker grep had accepted. The bracket expressions below behave the same in GNU grep and in mawk;
# mawk counts each byte of a multibyte character, which only makes a non-ASCII reason easier.
ALLOW_WORD='[^[:space:][:punct:][:cntrl:]]'
ALLOW_GAP='[[:space:][:punct:]]*'
ALLOW_RE="conventions-allow:${ALLOW_GAP}${ALLOW_WORD}${ALLOW_GAP}${ALLOW_WORD}${ALLOW_GAP}${ALLOW_WORD}"
# What counts as an attempted marker for [0]: the token followed by a colon, by a comment
# close, or by end of line. Anything that continues into more prose is a mention, not a marker.
MARKER_SHAPE_RE='conventions-allow[[:space:]]*(:|-->|\*/|$)'
# A fence may be indented (inside a list) and may be written with tildes. Recognising only a
# column-0 backtick fence meant an indented code sample was scanned as prose and false-positived.
FENCE_RE='^[[:space:]]*(```|~~~)'
# strip fenced code blocks (keep line numbers), inline code spans, and allow-marked lines.
# The allow test runs on the CODE-STRIPPED copy of the line: a documentation mention of the marker
# is always written inside backticks, and testing the raw line let such a mention silently suppress
# the checks on that line while [0] (which strips code before auditing) could not see it.
strip() { awk -v ar="$ALLOW_RE" -v fr="$FENCE_RE" 'BEGIN{inf=0}
  $0 ~ fr {inf=!inf; print ""; next}
  {if(inf){print ""; next} t=$0; gsub(/`[^`]*`/,"",t); if(t ~ ar){print ""; next} print t}' "$1"; }
# strip fenced code blocks and allow-marked lines only (keep inline code; removing it
# would falsely join Korean text and a following "(" across an inline-code span for [4]).
stripfence() { awk -v ar="$ALLOW_RE" -v fr="$FENCE_RE" 'BEGIN{inf=0}
  $0 ~ fr {inf=!inf; print ""; next}
  {if(inf){print ""; next} t=$0; gsub(/`[^`]*`/,"",t); if(t ~ ar){print ""; next} print $0}' "$1"; }
# strip fenced code blocks and inline code spans but KEEP allow-marked lines. Used by [0],
# which must inspect the markers themselves, and which must not mistake a documentation
# mention of the marker (always written inside backticks or a code fence) for a real usage.
stripcode() { awk -v fr="$FENCE_RE" 'BEGIN{inf=0}
  $0 ~ fr {inf=!inf; print ""; next}
  {if(inf){print ""} else {gsub(/`[^`]*`/,""); print}}' "$1"; }

echo "== [0] exception self-defense (conventions-allow markers) =="
# A marker without a stated reason suppresses nothing, so it would be a silent blanket switch.
# Scanned over the prose set only, since the marker affects [2][3][4][5] alone; the
# rule-definition file and this checker are excluded like everywhere else.
bare=""; nallow=0
for f in ${TFILES+"${TFILES[@]}"}; do
  [ -f "$PFX$f" ] || continue
  # Marker-SHAPED, not merely mentioned. A real marker ends the phrase: it is followed by a
  # colon (the reason), or it closes the comment it sits in, or the line ends. Prose that
  # merely names the mechanism continues into more words, and flagging that fired on every
  # sentence explaining the rule, including this checker's own comments. A marker with no
  # reason must still be reported, because it suppresses nothing while looking as though it
  # does, so the shape test keeps the bare form in scope and only prose drops out.
  h="$(stripcode "$PFX$f" | grep -nE "$MARKER_SHAPE_RE" | grep -vE "$ALLOW_RE" || true)"
  [ -n "$h" ] && bare+="$(printf '%s\n' "$h" | sed "s#^#${f}:#")"$'\n'
  # grep -c reads to the end, so stripcode never writes into a closed pipe.
  [ "$(stripcode "$PFX$f" | grep -cE "$ALLOW_RE")" -gt 0 ] && nallow=$((nallow + 1))
done
bare="$(printf '%s' "$bare" | sed '/^$/d')"

# An unbalanced fence is a third way to switch the prose checks off. The strip functions toggle
# in/out of a code block, so an odd number of fence lines leaves everything after the last one
# treated as code and silently exempt from [2][3][4][5]. Malformed markdown and a deliberate
# carve-out look identical here, so report either way.
unbal=""
for f in ${TFILES+"${TFILES[@]}"}; do
  [ -f "$PFX$f" ] || continue
  # grep -c prints a count AND exits 1 when the count is zero, so a `|| echo 0` fallback appended a
  # second line and the arithmetic below errored out on every file, silently disabling this check.
  n="$(grep -cE "$FENCE_RE" "$PFX$f" 2>/dev/null)"; n="${n:-0}"
  [ $((n % 2)) -eq 0 ] || unbal="${unbal}  ${f}: ${n} fence lines (odd)"$'\n'
done
if [ -n "$unbal" ]; then
  printf '%s' "$unbal"
  echo "  -> FAIL: an unbalanced code fence hides the rest of the file from checks [2][3][4][5]."
  fail=1
fi

if [ -n "$bare" ]; then
  printf '%s\n' "$bare"
  echo "  -> FAIL: a conventions-allow marker must state a reason (conventions-allow: <why>)."
  echo "     A reasonless marker suppresses nothing (docs/16 s6.2)."
  fail=1
elif [ -n "$unbal" ]; then
  : # already reported above
elif [ "$nallow" -gt 20 ]; then
  echo "  WARN: $nallow files carry a marker. It exists for a rare verbatim quotation;"
  echo "        this many suggests the rules are being routed around."
else
  echo "  OK: every marker states a reason ($nallow file(s) use one)"
fi

echo "== [1] forbidden unicode punctuation =="
# -I skips binary files, so the file set above needs no extension allowlist and extensionless
# authored files (Dockerfile, Makefile, .npmrc) are covered.
# grep's exit codes are 0 match, 1 no match, 2+ ERROR. Treating 2 as "no match" is the classic
# fail-open: one unreadable or tracked-but-deleted file would turn the whole check into a pass.
# So distinguish the three cases explicitly and treat an error as a hard failure.
if [ "${#UFILES[@]}" -gt 0 ]; then
  u_out="$(grep -rnIP '[\x{2014}\x{2013}\x{2015}\x{00B7}\x{2022}\x{FF0D}\x{3000}\x{00A0}]' "${UFILES[@]/#/$PFX}" 2>&1)"; u_rc=$?
  [ -n "$PFX" ] && u_out="$(printf '%s\n' "$u_out" | sed "s#^${PFX}##")"
  case "$u_rc" in
    0) printf '%s\n' "$u_out"; echo "  -> FAIL (see above)"; fail=1 ;;
    1) echo "  OK: 0 ($(printf '%s\n' "${UFILES[@]}" | grep -c .) files scanned)" ;;
    *) printf '%s\n' "$u_out" | head -20
       echo "  -> FAIL: grep errored (exit $u_rc); refusing to report a pass it did not verify"; fail=1 ;;
  esac
else
  echo "  OK: 0 (no files to scan)"
fi

echo "== [2] transliteration / translation terms (docs/16 s3.1) =="
# CORE is hard-coded here and can only be widened, never narrowed, by the data file below.
# 계층(hierarchy)/저장소(storage) omitted (common Korean homographs, review by hand).
# 머지 uses a negative lookbehind so 나머지, meaning the rest, does not match.
TPAT_CORE='리포지토리|레포|커밋|브랜치|푸시|(?<!나)머지|배포|의존성|근본원인|모듈|레이어|캐시|워크플로우|파이프라인|태그|스택|빌드|번들|컨테이너|롤백|마이그레이션|리팩터링|프리티어|프레임워크|아티팩트|바이너리|시크릿|토큰|헤더|스토어|폴리필|싱글턴|싱글톤|런타임|데몬|워커|미들웨어|화이트리스트|블랙리스트|네이티브|디렉터리|인프라|크롤링|스크래핑|프롬프트|티어|인벤토리|토폴로지|데이터베이스|오케스트레이션|리졸버|스크립트|타임존|테스트|프로비저닝|네이밍|데이터|컴포넌트|아키텍처|리소스|타깃|프론트엔드|백엔드|네트워크|리전|파라미터|콘솔|트리거|스텝|인스턴스|스키마|프록시|스케줄러|폴링|워크로드|인그레스|멀티클라우드|오케스트레이터|크롤러|스캐폴딩|스캐폴드|부트스트랩|셋업|포맷|타임아웃|스토리지|레퍼런스|콜드스타트|태스크|프로파일|스냅샷|레코드|컬럼|매핑|소비측'

# harness/conventions-terms ADDS to the core, one term per line, `#` comments allowed. It is a
# data file rather than another line of this script for two reasons: adding a term to a
# manifest-covered guard file forces a manifest regeneration on every vocabulary change, and
# the dictionary is the part of this rule that must keep growing. Union, never substitution:
# deleting or emptying the file leaves the core rule exactly as strong as it was.
#
# Why it needed to grow at all: measured against 85 transliterations a Korean rewrite actually
# produces, the core caught 3. A rule that passes 96 percent of what it exists to stop is a
# rule in name only, and D2 turns [2] from a mostly-dormant check into the primary gate on
# every document in the repository.
TPAT="$TPAT_CORE"
TERMS_ADDED=0
if [ -f harness/conventions-terms ]; then
  while IFS= read -r t || [ -n "$t" ]; do
    t="${t%%#*}"; t="$(printf '%s' "$t" | tr -d '[:space:]')"
    [ -n "$t" ] || continue
    case "$t" in *'|'*|*'('*|*')'*|*'['*|*']'*|*'*'*|*'+'*|*'?'*|*'\'*|*'.'*) continue;; esac
    grep -qF -- "$t" <<< "$TPAT" || { TPAT="$TPAT|$t"; TERMS_ADDED=$((TERMS_ADDED + 1)); }
  done < harness/conventions-terms
fi

th=""
kc_skipped=0
for f in ${TERMFILES+"${TERMFILES[@]}"}; do
  [ -f "$PFX$f" ] || continue
  # No language exemption. Under docs/16 s3.1 every document is Korean prose whose IT terms
  # stay English, so a Korean-language file is exactly the file this check exists to scan.
  # The old skip list (`*.ko.md` and the two Korean governance documents) inverted the rule the
  # moment the documents became Korean, and its globs were unanchored, so any path merely
  # ENDING in agent-conduct.md escaped too. The one exemption is by declared path, not by
  # language: a Korean deliverable listed in harness/korean-content (D71, see above).
  if [ -n "$KC_RE" ] && grep -qE "$KC_RE" <<< "$f"; then
    kc_skipped=$((kc_skipped + 1))
    continue
  fi
  #
  # stripfence, not strip: strip removes inline code spans, so writing `커밋` in backticks
  # silenced the check for that line. Inline code in a Korean document carries English
  # identifiers, which cannot match a Hangul pattern, so keeping it costs nothing.
  h=$(stripfence "$PFX$f" | grep -noP "($TPAT)" | sed "s#^#${f}:#"); [ -n "$h" ] && th+="$h"$'\n'
done
th=$(printf '%s' "$th" | sed '/^$/d')
[ -z "$KC_RE" ] ||
  echo "  korean-content: skipped $kc_skipped file(s) under ${KC_PATHS}, written for Korean readers (D71)"
if [ -n "$th" ]; then echo "$th"; echo "  -> FAIL: $(printf '%s\n' "$th" | grep -c .) hits"; fail=1
else echo "  OK: 0 (core terms + $TERMS_ADDED from harness/conventions-terms)"; fi

echo "== [3] prose arrows (use U+2192, not ASCII ->) =="
ah=""
for f in "${MDFILES[@]}"; do
  h=$(strip "$PFX$f" | grep -noP '(?<!-)\-\>' | sed "s#^#${f}:#"); [ -n "$h" ] && ah+="$h"$'\n'
done
ah=$(printf '%s' "$ah" | sed '/^$/d')
if [ -n "$ah" ]; then echo "$ah"; echo "  -> FAIL: $(printf '%s\n' "$ah" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

echo "== [4] Korean opening-paren spacing (한글(부연), no space) =="
# Scope, stated rather than left implicit (docs/16 s4.3). The rule is Hangul ADJACENCY: a space
# between a Hangul syllable and an opening parenthesis. It deliberately does NOT fire after an
# ASCII token, so `pnpm verify (typecheck + lint + test)` stays legal. That is not an oversight
# to be widened later: the repository's own Korean corpus already writes 66 such parentheticals
# and reads correctly, while gluing a parenthesis onto a code-shaped token would make it read
# as a call. The consequence is that the rule cannot judge a parenthetical whose preceding
# token is English, and docs/16 s4.3 says so.
#
# The separator class carries the two invisible spaces as well as ASCII space. Both are now
# forbidden outright by [1], so this is defence in depth rather than the only line: a Korean
# IME emits them routinely and either one used to walk straight past this check.
#
# File set is TFILES, not just markdown: a Korean parenthetical in a shell script or a workflow
# comment is the same violation, and [2] and [5] already scan those files.
ph=""
for f in ${TFILES+"${TFILES[@]}"}; do
  [ -f "$PFX$f" ] || continue
  h=$(stripfence "$PFX$f" | grep -noP '[가-힣][ \x{3000}\x{00A0}]+\(' | sed "s#^#${f}:#"); [ -n "$h" ] && ph+="$h"$'\n'
done
ph=$(printf '%s' "$ph" | sed '/^$/d')
if [ -n "$ph" ]; then echo "$ph"; echo "  -> FAIL: $(printf '%s\n' "$ph" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

echo "== [5] Korean prefix glued to an English term (재deploy -> re-deploy / 다시 deploy) =="
# A Sino-Korean prefix stuck directly to an ASCII letter is the anti-pattern. 재배포/비침습
# (prefix + Hangul) do not match; only a prefix immediately followed by [A-Za-z] does.
# The class is wider than 재 because the same mistake is made with every prefix in it: 미commit
# and 미overwrite were both already in this tree.
#
# stripfence, not strip, AND an optional backtick in the lookahead. strip removed inline code
# spans, so 재`deploy` left a bare 재 with nothing after it; keeping the span leaves a backtick
# between the prefix and the term, which an ASCII-letter-only lookahead also misses. One
# backtick was the whole bypass, from either direction.
kh=""
for f in ${TERMFILES+"${TERMFILES[@]}"}; do
  [ -f "$PFX$f" ] || continue
  h=$(stripfence "$PFX$f" | grep -noP '[재비미반역준초무탈](?=`?[A-Za-z])' | sed "s#^#${f}:#"); [ -n "$h" ] && kh+="$h"$'\n'
done
kh=$(printf '%s' "$kh" | sed '/^$/d')
if [ -n "$kh" ]; then echo "$kh"; echo "  -> FAIL: $(printf '%s\n' "$kh" | grep -c .) hits"; fail=1; else echo "  OK: 0"; fi

echo "== [6] relative markdown links resolve =="
# Only relative targets, resolved against the LINKING file's directory. An http/mailto target
# is out of scope (this checker never reaches the network) and a bare `#anchor` addresses the
# same file. A target carrying `<`, `>` or `...` is a placeholder in an example rather than a
# link, which is how docs/16 writes `[07-...](07-...md)` while explaining the link convention.
lh=""
for f in ${MDFILES+"${MDFILES[@]}"}; do
  [ -f "$PFX$f" ] || continue
  d="$(dirname "$f")"
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    case "$target" in
      http://*|https://*|mailto:*|'#'*) continue ;;
      *'<'*|*'>'*|*'...'*) continue ;;
    esac
    t="${target%%#*}"                     # drop a trailing anchor
    [ -n "$t" ] || continue
    # Resolved against the tree on disk, not against $PFX: in staged mode only the staged
    # paths are materialised, so a link to an unmodified file would look broken. A link target
    # is a property of the tree, and the tree is the right thing to ask.
    [ -e "$d/$t" ] || lh+="${f}: -> ${target}"$'\n'
  done < <(stripfence "$PFX$f" | grep -oP '\]\(\K[^)]+' || true)
done
lh=$(printf '%s' "$lh" | sed '/^$/d')
if [ -n "$lh" ]; then echo "$lh"; echo "  -> FAIL: $(printf '%s\n' "$lh" | grep -c .) broken relative link(s)"; fail=1
else echo "  OK: 0"; fi

if [ "$fail" -ne 0 ]; then echo; echo "RESULT: FAIL (docs/16 conventions)."; exit 1; fi
echo; echo "RESULT: PASS (docs/16 conventions)."
