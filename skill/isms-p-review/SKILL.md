---
name: isms-p-review
description: Assess content the user hands over (a policy or procedure excerpt, a description of how something is done, a system or configuration note, a screenshot description, an incident write-up, a vendor contract clause) against the ISMS-P certification criteria using the isms-p-docs corpus, and report which items it touches, what is a nonconformity candidate, what needs more information, and what is fine. The answer may be that nothing is wrong. Use when the user asks whether something is a problem, a defect, a gap, or a nonconformity under ISMS-P, ISMS, KISA certification, or the 인증기준, or pastes content and mentions ISMS-P. Do not use for a whole-organization self-assessment survey, for drafting a policy, for editing the corpus, or for ISO 27001 questions (that is iso-27001-review).
argument-hint: <content, or a file path, or empty to assess the content pasted above> [별표7 | 별표7의2 | 별표7의3]
allowed-tools: Read, Grep, Glob, Bash
---

# ISMS-P review

Judge a piece of content against the ISMS-P certification criteria, using only the isms-p-docs
corpus, and say what would be a nonconformity candidate (결함 후보), what needs more information,
and what is fine. "Nothing is wrong here" is a valid and common result. This is scenario S8 of
`extended/README.md`; the scenario prompt is `extended/prompts/spot-check.md` and the report
format is `extended/templates/spot-check.ko.md`. This file is self-sufficient.

## What you produce

One assessment, in the format of section 7, in the language the user wrote in. Every claim
carries a citation into the corpus. Nothing else: do not edit the corpus, do not write files
unless the user asks for a saved copy (section 7 says where), do not draft remediation documents
unless asked.

## 1. Locate the corpus

The corpus is the `isms-p-docs` repository. Resolve its root into `$root`, in this order,
stopping at the first candidate that passes the check (the manifest exists under it and carries
the standard id `isms-p`). Every path in sections 3 and 4 is relative to `$root`; citations in
the report use the repository-relative form (`docs/...`).

```bash
ok() { [ -n "$1" ] && grep -qE '"id"[[:space:]]*:[[:space:]]*"isms-p"' "$1/extended/manifest.json" 2>/dev/null; }
# 1. the current project is the corpus itself (or a directory inside it)
c="$(git rev-parse --show-toplevel 2>/dev/null)"; ok "$c" && root="$c"
# 2. this skill is a symlink into the repository at skill/isms-p-review, two levels up
[ -z "${root:-}" ] && d="$(readlink -f "$HOME/.claude/skills/isms-p-review" 2>/dev/null)" && c="${d%/skill/isms-p-review}" && ok "$c" && root="$c"
# 3. an explicit override
[ -z "${root:-}" ] && ok "${ISMS_P_DOCS_ROOT:-}" && root="$ISMS_P_DOCS_ROOT"
echo "${root:-NOT FOUND}"
```

If the result is `NOT FOUND`, ask the user for the path. Do not answer from memory of the
criteria. Read
`extended/USAGE.md` once per session; its rules (read-only corpus, manifest first, citation on
every claim, human gate, DLP, currency boundary) bind this skill and section 8 restates them.

## 2. Intake

Take the content from `$ARGUMENTS`; if that is a path, read the file; if it is empty, use the
content the user pasted above. Then normalise it before you route:

- Break it into **assertions**: each concrete statement about how something is done, decided,
  configured, or omitted. "운영 DB 관리자 계정 하나를 개발자 3명이 공유한다" is one assertion.
  Keep the user's wording; you will quote it back.
- Note the **context** you were given: organisation size and type, which set applies, whether
  the system is in the certification scope, whether this is a plan or the current state.
- Note the **unknowns**: what the content does not say that would change the verdict.
- **Personal data gate.** If the content carries what looks like real personal data (주민등록번호,
  phone numbers, email addresses, card or account numbers, names tied to such identifiers),
  never repeat it in the report; write `[masked]` in its place and say how many values you
  masked. Judge the practice, not the people. A pasted list plus one sentence about where it
  sits and who can open it is a practice to judge: the sentence is the assertion, and the list is
  summarised as evidence of what the file holds ("n rows with 이름, 주민등록번호, 전화번호,
  이메일"). Stop and ask only when no practice is described at all.

**Choose the set.** Use the set the user names. Otherwise 간편인증, 인증 특례, 중소기업, or a
매출액 300억 threshold point at 별표 7의2 or 7의3; say which you chose and why (under 300억
of ICT-service revenue is 7의2; at or above it without major ICT facilities is 7의3; if the
revenue is given but the facilities are not, take 7의2 below the threshold and say the other
condition was assumed). 간편인증 on its own means this current 인증 특례 track, which is in
force; it refers to the 2026 three-tier scheme only when the user also says 2026, 개편, 3단계,
or names the 강화 or 표준 tier, and then section 6 applies. With no hint, use 별표 7 and state
the assumption in the report header. The 3.x items (개인정보 처리단계별
요구사항) apply to ISMS-P only: for an ISMS-only applicant report them as 범위 외 rather than
judging them.

If the content is not about how an organisation handles information security or personal
information (a general question, a request for the criteria's own text, a legal interpretation),
say so and stop.

## 3. Route to items

Do not read all 228 documents. Route first:

1. Read `skill/isms-p-review/topic-index.json` (next to this file) and match each assertion
   against every topic, then collect the `items` of the topics that hit **for the chosen set**.
   The keywords are a vocabulary, not literal strings to grep for, so match this way:
   - A keyword hits when its content words appear in the assertion in any order, ignoring
     Korean particles and verb endings and English inflection ("계정을 비활성화한 뒤" hits
     "계정 비활성화"; "개발 서버와 운영 서버가 같은 장비" hits "개발 서버" and "같은 장비";
     "sent from personal Gmail" hits "personal email"). Read `topic_ko` and `topic_en` as
     keywords too.
   - Then make one pass in the other direction: for each assertion ask which topics it is
     about, even if no keyword fired. A user's everyday sentence ("운영 DB를 그대로 복사해서
     테스트 서버에 넣어") often names no index word yet clearly belongs to a topic (시험 데이터). <!-- conventions-allow: quotes user phrasing or a corpus term verbatim -->
   - Discard a hit that rests on one short or generic word inside a longer word or in another
     sense ("로그" inside "로그인", "복구" in "복구 테스트" hitting 사고 복구, "admin" in a URL <!-- conventions-allow: quotes user phrasing or a corpus term verbatim -->
     hitting 관리자 계정 rather than 관리자 페이지, "소화" inside "최소화", "열람" meaning staff
     opening a file rather than a data subject's access request, "공유" of a file rather than of a
     protection measure or an account). A hit needs either
     a specific keyword or two keywords of the same topic.
   An empty `items` list for a relaxed set means that set has no counterpart item: report the
   topic as 범위 외 for that set, and say which Annex 7 item covers it in the full set.
2. Confirm and widen with `extended/manifest.json`: keep `lang == "ko"` and `section` equal to
   the chosen set, scan the `name` and `subgroup` of every item for words in the assertions,
   and add neighbours the topic index lists for the same theme when an assertion clearly spans
   them. For 별표 7 you may also grep `extended/index/defect-rulebook.json` (per-item
   nonconformity examples) for the assertion's words, but that grep confirms a route; it does
   not create a primary item on its own, and the same generic-word filter applies to it.
3. Keep at most about 8 **primary** items, the ones a checkpoint would directly test. List every
   other routed item as **secondary** in the report's 관련 항목 section, by number and title,
   even the marginal ones, so nothing is silently dropped. If the routing table
   had no words for something the user said, say so in one line of the report's 관련 항목
   section, so the maintainer can add them (the table is hand-authored; its 별표7의2 and 7의3
   lists are derived by `derive_relaxed_lists.py` next to it).
4. Check the `out_of_scope` block of the topic index. Legal interpretation, the 2026 scheme
   overhaul, certification obligation and procedure, and ISO 27001 are handled as it says.

When nothing routes, say that the content does not touch an ISMS-P criterion as far as the
corpus can tell, and list what you searched for.

## 4. Read only what you routed

For each primary item read the Korean document (`docs/ko/<set>/<no>.md`) in full; it is the
authoritative text and runs 60 to 200 lines. Read the English mirror (`docs/en/...`) only when
the user works in English or when the exact wording of a checkpoint matters. Every path is in
the manifest, so never guess one. `extended/index/defect-rulebook.json` and
`extended/index/evidence-dictionary.json` hold the 별표 7 lists alone and are enough when you
only need those; for 별표 7의2 and 7의3 take the lists from each item's own document, because
those sets renumber and the index files key on bare numbers. In 별표 7의2 and 7의3 the 세부 설명,
관련 법규, 증적자료 and 결함사례 are imported from the Annex 7 counterpart, as each document's
banner says; they are quotable as that item's own text, cited at the relaxed item's own path.

## 5. Assess

For each primary item, go down its `주요 확인사항` one by one and mark each checkpoint against
the assertions:

| Mark | Meaning |
|---|---|
| 충족 근거 있음 | an assertion shows the checkpoint is met |
| 미충족 | an assertion shows it is not met, or matches an example under `결함사례` |
| 정보 부족 | the content does not say; name what would settle it, taken from `증적자료` |
| 해당 없음 | the checkpoint is outside what the content is about |

Then give the item one **verdict**:

- **결함 후보** (nonconformity candidate): at least one checkpoint is 미충족. Quote the
  assertion, name the checkpoint number, and quote the matching 결함사례 if one matches. Say why
  it is a candidate in one or two sentences of your own.
- **확인 필요** (needs information): nothing is 미충족 but at least one relevant checkpoint is
  정보 부족. List the evidence that would settle it.
- **문제 없음** (no issue found): at least one relevant checkpoint is 충족 근거 있음 and the rest
  are 해당 없음. Say so plainly. Do not invent a concern to have something to report. An item
  whose every checkpoint reads 해당 없음 was not tested: move it to 관련 항목 with one line saying
  why it does not apply, give it no verdict, and do not count it among 검토한 항목.
- **범위 외** (out of scope): the concern is real but the corpus does not decide it. See
  section 6.

Absence of information is never 문제 없음; it is 확인 필요 with the missing fact named. The
mirror rule holds too: a practice that covers part of what a checkpoint asks is 충족 근거 for
that part and 정보 부족 for the rest, not 미충족. "Every quarter we reconcile the account list
against the HR roster" is evidence of a periodic review; whether rights are also checked for
appropriateness is a question to ask, not a defect to record. Mark 미충족 only when an assertion
states a practice contrary to the checkpoint, states that the checkpoint's activity does not
happen ("복구 테스트는 한 번도 해본 적이 없습니다"), or matches a 결함사례 in kind, not merely in shape (the example must describe the same sort of <!-- conventions-allow: quotes user phrasing or a corpus term verbatim -->
practice, not just the same sort of gap; when it only resembles the description, the verdict
rests on the checkpoint alone). A verdict of 결함 후보 needs a quoted checkpoint or a quoted
결함사례, copied character for character from the document; shorten only with an explicit
ellipsis (...) and never paraphrase inside quotation marks. If you cannot quote one, it is not a
finding. One fact is 미충족 only for the checkpoint that asks about it directly; the neighbouring
items the same fact routed to are usually 정보 부족, because they ask about something else (영역
분리, 공개서버 보호대책) that the content did not describe. When an assertion describes what people
can actually do and the checkpoint asks about a formal act (지정, 등록, 승인, 분류), the assertion
alone is 정보 부족 for that checkpoint, not 미충족. When a checkpoint's applicability itself turns
on a fact the content did not give (the encryption table of 2.7.1 depends on which fields the copy
holds), mark it 정보 부족 and say which fact would turn it into 미충족.
Some items carry their own exception route: a first checkpoint asks whether something is done
(개발과 운영 환경의 분리) and a later one asks, where that is unavoidable, whether compensating
controls are in place (상호 검토, 상급자 모니터링, 변경 승인, 책임추적성). An assertion that fails
the first checkpoint alone leaves the item **확인 필요**, with a sentence saying it becomes a
결함 후보 if the compensating records turn out to be missing (that is what the item's 결함사례
describes); it is 결함 후보 only when the content also shows the exception unmet. A figure
printed in the item's own document, including a 세부 설명 borrowed from Annex 7, counts as the
item's text and may be stated with its citation. Never grade a candidate as 중결함 or 경결함: that is the auditor's call, and the corpus
does not classify its examples. Numbers (a retention period, a password length, a review
interval) are stated only when the item's own text gives them, with the citation; otherwise
write `[확인필요]` and point at the item's `관련 법규` line.

Be as ready to clear content as to fault it. Content that says how approval, recording, review,
and revocation happen is meeting checkpoints, and the report must say so.

## 6. The boundary of the corpus

The corpus is the criteria text as pinned in `UPDATES.md`: 별표 7 (2023.10.5), 별표 7의2 and
7의3 (2024.7.24), the detailed inspection items (2023.10.31 and 2024.7.24), and the 인증기준
안내서(2023.11.23). Four things sit outside it and are reported as **범위 외**, each with what
the corpus does hold on the point:

- **Legal interpretation.** Copy the item's `관련 법규` line as it stands, with citation. Do not
  interpret it, do not add articles from memory, and do not update it to a newer amendment. Say
  once that the citations are as of the 2023.11.23 guide and that later amendments are not
  reflected, then mark the point for human legal review.
- **The 2026 scheme overhaul** (three tiers, new mandatory targets). Not in the corpus. Say the
  pinned annexes are the current ones as of the register's last check and point at `UPDATES.md`
  section 2.3.
- **Certification obligation, application, audit schedule, fees.** The item documents do not
  cover this. `extended/README.md` sections 1 and 2 summarise the scheme as of their writing
  date; cite that as a summary, not as criteria.
- **ISO/IEC 27001.** Use the iso-27001-review skill on the iso-27001-docs corpus.

## 7. Report format

Korean when the user wrote Korean (polite -습니다 register, and follow the project's conduct
rules if the surrounding project has them), English otherwise. Lead with the conclusion. No em
dash and no middle dot anywhere in the report; use a comma, colon, slash, parentheses, or 및.

```markdown
## ISMS-P 검토 결과

> 상태: AI 생성 초안 / 검토 전 | 적용 세트: 별표 7(추정) | 생성: 2026-09-13 | 자료집 기준: 세부점검항목 2023.10.31 및 2024.7.24, 인증기준 안내서 2023.11.23

**한 줄 결론**: 결함 후보 N건, 확인 필요 N건, 문제 없음 N건입니다(검토한 항목 M개, 관련 항목 K개 추가). 전달 내용에 충족 근거가 있는 확인사항은 J개입니다.

**개인정보 처리 안내(해당 시)**: 전달 내용의 개인정보 값 N개를 `[masked]`로 처리했고 보고서, 인용문, 저장 파일 어디에도 옮겨 적지 않았습니다.

| 항목 | 판정 | 전달 내용 중 근거 | 대응 확인사항 / 결함사례 | 출처 |
|---|---|---|---|---|
| 2.5.2 사용자 식별 | 결함 후보 | "운영 DB 관리자 계정 하나를 개발자 3명이 공유" | 확인사항 2(공유 시 사유와 타당성 검토, 보완대책, 책임자 승인), 결함사례 "개발자가 개인정보처리시스템 계정을 공용으로 사용하고 있으나, 타당성 검토 또는 책임자의 승인 등이 없이 ..." | docs/ko/annex7/2.5.2.md > 주요 확인사항, 결함사례 |

### 판정 근거
(항목별 두세 문장. 전달 내용의 어느 문장이 어느 확인사항에 걸리는지, 왜 후보인지.)

### 확인이 필요한 정보와 증적
- (증적자료 절에서 가져온 항목과 출처)

### 범위 외 또는 이 자료집이 다루지 않는 부분
- (법규 해석, 2026 개편, 의무 대상 판단, 수치 기준)

### 관련 항목(이번 판정에서 직접 시험하지 않음)
- x.y.z 제목, x.y.z 제목

> 이 결과는 인증기준 안내서(2023.11.23)의 확인사항과 결함사례에 근거한 후보 판정입니다. 결함 여부와 경중은 심사원과 담당자가 최종 판단합니다. 관련 법규는 자료집 기준일 당시의 표기이며 이후 개정은 반영되어 있지 않습니다.
```

For an English report use the same structure with these headings: "ISMS-P review result",
the status line ("Status: AI-generated draft / not reviewed | Set applied: ... | Generated: ...
| Corpus basis: ..."), "One-line conclusion", table columns "Item | Verdict | Basis in the
content | Matching checkpoint / nonconformity example | Source", then "Basis of each verdict",
"Information and evidence needed", "Out of scope, or not covered by this corpus", "Related
items (not tested directly)", and the same footer in English. Keep the four verdict labels in
Korean with an English gloss on first use (결함 후보 = nonconformity candidate, 확인 필요 =
needs information, 문제 없음 = no issue found, 범위 외 = out of scope), and keep citation
section names Korean, because they are the headings that exist in the cited files.

J counts every checkpoint that carries at least one 충족 근거 mark, including one that is part
충족 근거 and part 정보 부족(name the met part in the table); a checkpoint that is only 정보 부족 or
해당 없음 is not counted. The 개인정보 처리 안내 line appears only when something was masked.

Citation form: `docs/ko/<set>/<no>.md > <섹션명>`. Every row of the table and every bullet
under 판정 근거 carries one. A statement you cannot cite does not go in the report.

When the verdict is 문제 없음 for everything, the table still lists the items you tested and the
checkpoints they met, so the user can see what was checked rather than a bare "fine". When most
items are 확인 필요 only because the content is silent on some checkpoint, the one-line
conclusion must still say that nothing described is a 결함 후보 and how many checkpoints the
content did meet; a well-run practice must read as well run.

If the user asks to keep a record, save the report as
`extended/outputs/spot-checks/spot-check-<topic>-<YYYY-MM-DD>.md` under the corpus root
(everything under `extended/outputs/` except its readmes is git-ignored), and when any verdict is
결함 후보 or a legal point is involved, append one line naming the file and the items to
`extended/outputs/review-queue/<YYYY-MM-DD>-spot-check.md`. Show the report in the reply as well.

## 8. Rules

- **The corpus is read-only.** Never create, edit, or delete anything under `docs/`. If you
  notice a defect in a document, tell the user so a maintainer can fix it.
- **Manifest first.** Route, then read only the routed documents.
- **Cite every claim.** No citation, no claim.
- **Stay inside the corpus.** Criteria, checkpoints, laws, and figures come from the documents
  or not at all. General knowledge of ISMS-P is not a source here.
- **Currency boundary.** State the pinned dates once; never present a later amendment or the
  2026 overhaul as in force.
- **Human gate.** Conformity, severity, and certification readiness are decided by people.
  Everything you output is a candidate for their review, and the footer says so.
- **Personal data.** Masked, never echoed, never saved.

## 9. Worked example

Input: "운영 DB 관리자 계정 하나를 개발자 3명이 공유하고, 비밀번호는 2년간 바꾸지 않았습니다.
접속기록은 3개월 보관합니다." Set: none given, so 별표 7, stated as assumed.

Assertions: (1) one production DB administrator account is shared by three developers; (2) its
password has not been changed for two years; (3) access records are kept for three months.
Route: topics "공용 계정" and "관리자 계정" give 2.5.2, 2.5.5, 2.5.1; "비밀번호" gives 2.5.4;
"로그, 접속 기록, 보관 기간" gives 2.9.4, 2.9.5; "DB 접근" adds 2.6.4 as secondary.

- 2.5.2 사용자 식별: 결함 후보. Checkpoint 2 asks whether a shared identifier has a documented
  reason, a compensating measure, and the responsible person's approval; the content shows none,
  and the nonconformity example about developers sharing a personal-information-system account
  without review or approval matches. `docs/ko/annex7/2.5.2.md > 주요 확인사항, 결함사례`
- 2.5.5 특수 계정 및 권한 관리: 확인 필요 on whether the administrator account is on the
  special-account register and its holders are minimised and approved.
  `docs/ko/annex7/2.5.5.md > 주요 확인사항, 증적자료`
- 2.5.4 비밀번호 관리: 확인 필요, not 결함 후보. The nonconformity example is about not
  following the organisation's own change cycle, so the internal rule must be read first; ask for
  the password policy. `docs/ko/annex7/2.5.4.md > 결함사례, 증적자료`
- 2.9.4 로그 및 접속기록 관리: 결함 후보. Checkpoint 3 asks whether access records to the
  personal-information system are kept for the legally required period with the required fields;
  the nonconformity example about access records surviving only two months matches the shape of
  the assertion. The period itself is `[확인필요]` from the item's 관련 법규 line, not stated
  from memory. `docs/ko/annex7/2.9.4.md > 주요 확인사항, 결함사례, 관련 법규`

One-line conclusion: 결함 후보 2건, 확인 필요 2건, 문제 없음 0건입니다(검토한 항목 4개, 관련 항목
3개 추가). Read those files before citing them; this example shows the shape of a judgment and is
not itself a source.

## Do not

- Do not read the whole corpus, and do not answer without reading the routed documents.
- Do not report an item you did not read.
- Do not grade 중결함 or 경결함, and do not state numeric requirements the item does not print.
- Do not modernise a legal citation or assert the 2026 overhaul.
- Do not pad a clean result with speculative concerns. Say it is clean, show what was checked.
