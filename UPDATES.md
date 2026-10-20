# Source basis and update tracking

> 한국어: [UPDATES.ko.md](UPDATES.ko.md)

This document does two things:

1. It **pins the source**: which official edition each part of the corpus is based on.
2. It is the **known-divergence register**: upstream legal changes that have happened since that
   edition, and the recorded decision on each. Most of them are deliberately **not** reflected.

Read part 2 before "fixing" a citation that looks out of date. It probably is not a defect.

Last checked: 2026-10-20.

This review re-downloaded the 2023.11.23 guide, the three checklist workbooks and the three Notice
annexes from KISA, compared every Korean sentence of the corpus with them, re-checked every statute
claim in this register against the effective-date texts on law.go.kr, and recorded the resulting
corrections in section 2.9.

## 1. Source versions

| Part of the corpus | Basis | Date |
|---|---|---|
| Annex 7: Certification criterion | Notice [별표 7] (개인정보위 고시 제2023-8호, 발령 = 시행) | 2023.10.5 |
| Annex 7: Key checkpoints | ISMS-P detailed inspection items (세부점검항목) | 2023.10.31 |
| Annex 7-2 and 7-3 (simplified certification): criterion and key checkpoints | Notice [별표 7의2, 별표 7의3] and the matching detailed inspection items | 2024.7.24 |
| Detailed explanation, Related laws, Evidence, Nonconformity examples | ISMS-P Certification Criteria Guide (인증기준 안내서) | 2023.11.23 |
| The English documents under `docs/en/` | unofficial translation of the Korean authoritative version above | Korean original prevails |

## 2. Known divergences from current upstream law

### 2.1 Why a divergence is expected, and correct

The ISMS-P criteria text is not a live mirror of the underlying statutes. The criterion text
changes only when the Notice annexes are amended, and the explanation, related-law, evidence and
nonconformity text changes only when KISA and the PIPC **re-issue the Certification Criteria Guide
(인증기준 안내서)**. Between those events, upstream statutes move and the criteria text does not. This corpus follows the criteria, so it
inherits that lag by design.

Aligning this corpus to a newer upstream notice ahead of a re-issue would put it **out of step with
the current authoritative ISMS-P version**, which is the opposite of what a reference corpus is for.

### 2.2 The open divergence: Standards for Ensuring the Safety of Personal Information

Many items cite this notice (개인정보의 안전성 확보조치 기준) as it stood **effective 2023.9.22**.
Since then:

| What changed upstream | When | Reflected here? |
|---|---|---|
| Guide to the Standards for Measures to Ensure the Safety of Personal Information (개인정보의 안전성 확보조치 기준 안내서) published, then re-issued as the 2025.11 edition | 2024.10.31, 2025.11 | No |
| PIPC Notice 2025-9 (개인정보보호위원회 고시 제2025-9호) amending the notice: the uniform internet-network blocking measure becomes risk-based (the new Article 6-2, in force from issuance). 부칙 제1조 defers the rest to one year after issuance, 2026.10.31: two new required items of the internal management plan (Article 4(1)12 output and copy safeguards, 13 destruction), the widening of the access-rights, authentication and access-record duties from personal information handlers to everyone with access other than data subjects (Article 5(1) and (6), Article 6(2), Article 8(1)), and a review cycle, method and follow-up procedure set in the internal management plan in place of the monthly access-record review (Article 8(2)) | 2025.10.31 / 2026.10.31 | No |
| PIPC Notice 2026-9 (개인정보보호위원회 고시 제2026-9호), the current version of the notice | 2026.7.1 | No |
| Personal Information Protection Act (법률 제20897호): the domestic representative must have an address or office in Korea, and a processor that has a domestic corporation it established, or one over which it exercises dominant influence as the Decree defines, must designate the representative from among those corporations (Article 31-2(2)); a new education and supervision duty (Article 31-2(3)) and matching 과태료 in Article 75(3)3 and 4. Cited by items 3.5.1 and 1.4.1 | 2025.10.2 | No |
| Enforcement Decree (대통령령 제36121호): Article 42-2(1) who must transmit (its subparagraph 1, the large private-sector class, deferred to 2027.2.20), Article 42-4(1) the scope of self-transmission information, and Article 42-6(3) to (5) the transmission methods, giving content to the standards left to Presidential Decree in Article 35-2. Subject matter of item 3.5.2 | 2026.8.20 | No |
| Personal Information Protection Act (법률 제21445호, promulgated 2026.3.10), its Enforcement Decree (대통령령 제36671호, promulgated 2026.9.10) and the related notices take effect: board resolution and filing for the Chief Privacy Officer, notification without delay (지체 없이) on the *possibility* of a leak (Article 34(2); Decree Article 39-3(1) sets 72 hours for this notice too, counted from the points in Decree Article 39-2(1), as Decree Article 39(1) does for a confirmed leak), a new 10 percent of total turnover ceiling for repeated or serious violations (Article 64-2(2)) alongside the retained 3 percent general ceiling (Article 64-2(1)) | 2026.9.11 | No |
| The same Act's proviso to Article 32-2(1) makes ISMS-P certification mandatory above a size threshold; it carries its own later commencement date, and the Enforcement Decree amendment that fixes the scope was pre-announced (입법예고) from 2026.6.2 to 2026.7.13 | 2027.7.1 (not yet in force) | No |

Also promulgated but not yet in force, so not a divergence yet: 개인정보 보호법 법률 제21910호
(promulgated 2026.9.8, effective 2027.3.9).

**Decision: keep the current text.** The article numbering the criteria depend on (Article 4
Internal management plan through Article 13 Destruction) is unchanged across these revisions - the
2025.10.31 version (Notice 2025-9) moved the internet-network blocking measure out of Article 6(6)
into a new branch-numbered Article 6-2 (인터넷망의 차단 조치 등), which does not shift Article 7
onwards, and the 2026.7.1 version altered only Articles 15, 18 and 19 - and it is largely stable
otherwise,
and the criteria body only takes on such a change when the Certification Criteria Guide
(인증기준 안내서) is re-issued. Rewriting the Related laws sections now would contradict the current
authoritative version (2023.11.23).

### 2.3 The pending divergence: the 2026 overhaul of the certification scheme

A full overhaul of the ISMS-P certification scheme is under way. It is the largest pending change,
and the only one that would restructure the **criteria themselves** rather than the statutes they
cite, so it belongs in this register and not only in `extended/README.md`.

| What happened upstream | When | Reflected here? |
|---|---|---|
| The PIPC and the MSIT announce measures to strengthen the effectiveness of the certification scheme (인증 실효성 강화 방안), presenting a notice amendment for the first quarter of 2026 | 2025.12.6 | No |
| The two agencies publish the plan (정보보호 및 개인정보보호 관리체계 인증제 실효성 강화방안): the single criteria set is to be reorganized into three tiers (간편, 표준, 강화), the enhanced tier adding a draft 20 criteria and 76 detailed inspection items on top of the standard tier, and audits are to move from document-centered checks towards technical review (vulnerability checks, penetration tests) and on-site demonstration | 2026.4.10 | No |
| The plan's own timeline: the post-certification measures (상시 점검 강화, 인증취소 기준) from the second half of 2026; the wider mandatory scope and the differentiated three-tier scheme from 2027, with the notice and decree amendments named as follow-up work | 2026.4.10 (plan) | No |
| The 2026.4.10 plan also schedules a revision of the Certification Criteria Guide (인증기준서 개선: review and supplement the existing 인증기준 안내서 in light of recent breaches and technology change, including the serious-defect criteria) from the second half of 2026. This is the trigger in section 3; KISA had listed no new edition by 2026-10-20 | 2026 H2 (planned) | No |
| The Network Act (정보통신망법, 법률 제21500호, promulgated 2026.3.31) takes effect: Article 47-7 is retitled 정보보호 관리체계 인증의 차등적용 등, its new paragraph (2) lets the MSIT apply strengthened criteria and procedures to providers whose breach could seriously endanger life, body or property, and paragraph (4) has those criteria set by notice; new Article 47(10)4 makes a serious violation of information-security laws a ground for cancelling certification | 2026.10.1 | No: no strengthened criteria have been issued |
| Its Enforcement Decree (대통령령 제36735호, promulgated 2026.9.30) takes effect: Article 49-2 moves to Article 55-7 (정보보호 관리체계 인증의 차등적용 대상자의 범위), whose new paragraph (3) names the strengthened tier among providers that must hold ISMS (revenue of KRW 1 trillion or more for major information and communications service providers and data-center operators, KRW 3 trillion or more for any provider, or a breach in the last three years followed by a joint public-private investigation or a penalty surcharge); Article 47(3) and (4) require document and on-site audits together and let qualified technical staff run the on-site audit of strengthened-tier entities and of certified entities that suffered a breach | 2026.10.1 | No |
| PIPC 입법예고(공고 제2026-116호) of a Personal Information Protection Act Enforcement Decree amendment: document and on-site audits together and vulnerability checks by qualified technical staff (draft Article 34-2), the same in post-certification audits (draft Article 34-5), and a one-year 과태료 grace after a mandatory certificate is cancelled; the PIPC plans the matching notice amendment within the year | 2026.9.16 to 2026.10.26 (not promulgated) | No |

**Decision: keep the current text. This is not yet a divergence in the criteria at all.** The
planned notice amendment has not been issued. Re-checked on 2026-10-20, the Notice on certification
(정보보호 및 개인정보보호 관리체계 인증 등에 관한 고시) is still the 2024.7.24 version (개인정보위
고시 제2024-8호 / 과기정통부 고시 제2024-30호) in the 국가법령정보센터 record, so 별표 7, 별표 7의2
and 별표 7의3 are unchanged and the corpus still matches the current authoritative annexes. The
first-quarter-2026 amendment did not land, and no 행정예고 of an amending notice had been found by
2026-10-20. The statutory basis of the differentiated scheme has been in force since 2026.10.1
(정보통신망법 Article 47-7(2) and Enforcement Decree Article 55-7(3)), but no strengthened-criteria
notice under Article 47-7(4) and no amended annex has been issued, and the plan schedules the
strengthened criteria for 2027. So treat the three-tier restructuring of the criteria as legislated but
not yet issued, and do not pre-empt it. Note that Article 23(3) and (4) of the Notice still cite
Decree Article 49-2, which moved to Article 55-7 on 2026.10.1.

The trigger for this corpus is unchanged: a re-issue of the 인증기준 안내서, per section 3. When
amended annexes are promulgated the item counts (101 / 62 / 65) are what move first, so record the
reflection plan here **before** touching `docs/`.

### 2.4 Confirmed as current

| Item | Status |
|---|---|
| ISMS-P Certification Criteria Guide (인증기준 안내서) | KISA still lists the 2023.11.23 edition; no later general criteria guide was found on 2026-10-20. On 2026-10-20 the PDF (262 pages, SHA-256 `cf80d3bb191f325583e7410840d8016b50ffcf28f9fc5a4d044e4ef600f90a9b`) was compared sentence by sentence with the four guide sections of all 101 Annex 7 documents, and its tables and figures were compared page by page; the differences are recorded in section 2.9. |
| Notice on certification (정보보호 및 개인정보보호 관리체계 인증 등에 관한 고시) | The national law database still lists the 2024.7.24 version (개인정보위 고시 제2024-8호 / 과기정통부 고시 제2024-30호); no later issued version was found on 2026-10-20. On 2026-10-20 the annex files (별표 7, 7의2, 7의3, HWP) were compared with all 228 criteria; see section 2.9 for the two omitted provisos. |
| Annex 7-2, 7-3 detailed inspection items | Downloaded KISA's 2024.7.24 workbooks on 2026-09-17: 62 / 65 items and 232 / 222 checkpoints. Compared the Korean criteria and checkpoints with the corpus, allowing whitespace and separator normalization. Recorded the source discrepancies and correction below. |
| ISMS-P Certification Scheme Guide (인증제도 안내서) | KISA still lists the 2024.07 edition (posted 2024.7.24), cited by `extended/README.md`; no later edition found on 2026-09-17. |
| Annex 7 detailed inspection items | Downloaded KISA's 2023.10.31 workbook on 2026-09-17: 101 items and 328 checkpoints, compared as above. Dataset 15106182 is KISA's single entry for every edition: its current file is the Annex 7-3 workbook and its past data hold the Annex 7 (2023.10.31) and Annex 7-2 (2024.7.24) workbooks, each byte-identical to KISA's own file on 2026-10-20; none is a newer Annex 7 edition. The previous open check is resolved in section 2.7. |

### 2.5 Resolved: the Annex 7 date in the source footer

The footer used to cite `[별표 7] 세부점검항목(2023.10.31)`, bundling two different sources under
one date. Two facts settle it:

- The 2023 amendment of the Notice is **발령일자 = 시행일자 = 2023.10.5** (개인정보위 고시
  제2023-8호 / 과기정통부 고시 제2023-33호), per the 국가법령정보센터 record. There is no
  2023.10.31 amendment.
- The annex itself carries **only the certification criterion**. A check of every checkpoint
  sentence against the gazette text finds none reproduced verbatim: the key checkpoints are not in
  the annex at all, they come from the separate detailed inspection items (세부점검항목).

2023.10.31 is itself confirmed and correct, but for the OTHER document: KISA publishes the detailed
inspection items separately, registered on the Public Data Portal as
`한국인터넷진흥원_ISMS_P 인증기준 세부점검항목_20231031` with a data reference date of 2023.10.31
(now a past-data entry of data.go.kr dataset 15106182, `..._20231031`, byte-identical to KISA's
2023.10.31 workbook on 2026-10-20; the separate dataset 15106188 cited earlier no longer exists). It
is not the Notice's date and must not be "corrected" to 2023.10.5.

The footer now attributes each part separately: the criterion to the Notice annex (2023.10.5), the
key checkpoints to the detailed inspection items (2023.10.31), and the remaining four sections to
the Certification Criteria Guide (2023.11.23).

**That date applies to Annex 7 only.** KISA publishes the detailed inspection items per annex, so
Annexes 7-2 and 7-3 take their own 2024.7.24 editions (in Public Data Portal dataset 15106182, the
past-data entry `..._20240724` is the Annex 7-2 workbook and the current file `..._20240725` the
Annex 7-3 workbook; the former datasets 15134405 and 15134408 no longer exist), not the 2023.10.31
Annex 7 file, which predates those annexes by
nine months. The 254 simplified-set documents carried 2023.10.31 until this was corrected; their
footers now cite 2024.7.24, agreeing with the source pin in section 1 and with the manifest. The 202
Annex 7 documents keep 2023.10.31, which is the right date for them.

### 2.6 Resolved: Annex 7-2 item 1.1.2

The gazette states this criterion as designating **only** the Chief Privacy Officer, while the
corpus had carried Annex 7's fuller sentence requiring a CISO as well. The criterion is now the
gazette text, confirmed from the 국가법령정보센터 open API (admRulSeq 2100000244750, 별표키 000702).
Article 23(3)2 of the Notice corroborates it: it excludes 1.1.2 from ISMS-only certification
precisely because the item is CPO-only.

The **key checkpoints were deliberately left unchanged, and that is correct**. KISA's own Annex 7-2
detailed inspection items (the `_20240724` entry of data.go.kr dataset 15106182, 62 items, byte-identical to KISA's
workbook; the former dataset 15134405 no longer exists)
reuse Annex 7's two checkpoints verbatim for 1.1.2, including the reference to 정보보호 최고책임자
및 개인정보 보호책임자. The corpus matches that source.

**Known upstream inconsistency:** the same KISA file reprints the CISO-plus-CPO wording in its own
상세내용 column, which contradicts the gazette. This corpus follows the gazette for the criterion
and the detailed inspection items for the key checkpoints, which is the correct precedence. Do not
"fix" the checkpoints to match the narrowed criterion; they are what the official checklist says.

### 2.7 Resolved: dataset 15106182 was misidentified

On 2026-09-17, the attachment from [dataset 15106182](https://www.data.go.kr/data/15106182/fileData.do)
was downloaded and compared with KISA's Annex 7-3 workbook. The files are byte-identical:
39,734 bytes, SHA-256 `d93e6223d08ee2e4e131beae4dcd849ea2100839d4d1c8b30197deaac1cb83dc`.
The workbook contains 65 items and 222 checkpoints. Its portal title ends in `20240725`, and the
portal reports 225 rows; neither is evidence of a new 101-item Annex 7 edition. The earlier
unverified statement that this dataset described 101 items is withdrawn. Keep the existing pins.

### 2.8 Resolved: checklist transcription and recorded source differences (2026-09-17)

Before editing the corpus, the comparison of all 228 Korean criteria and 782 checkpoints identified
one transcription issue: checkpoint 1 of item 1.1.2 omits `보호` from `개인정보보호 처리` in all
three sets. Both the official workbooks and the 2023.11.23 guide include it. The plan recorded
before editing was to restore the phrase in all three Korean documents, update the matching
English sentences to refer to personal information protection activities, and regenerate the
indexes in the same change. The six documents now carry that correction.

Keep these source discrepancies as recorded exceptions:

- Annex 7 checkpoint 2 of 2.9.2: the workbook has the typo `수립/이하고`; the guide prints
  `수립/이행하고`. Keep the corpus's guide-supported spelling.
- Annex 7-2 criterion 2.9.2: the workbook duplicates `행하여야 한다.` at the end. Keep the
  unduplicated criterion.
- Annex 7-2 criterion 1.1.2: keep the gazette wording, as explained in section 2.6.

This comparison covers criteria and checkpoints. The 19 integrity checks cover all 456 documents,
their structure, shared text, links, and generated metadata; they do not establish the semantic
accuracy of every English sentence or re-verify all legal interpretations.

### 2.9 Resolved: corrections from the full re-verification (2026-10-20)

The corpus was compared again with every official source: the Notice annexes (HWP), the three
checklist workbooks, and the 2023.11.23 guide (text, tables and figures, page by page). Item names,
the Annex 7 criteria and all 782 key checkpoints already matched. The following were corrected in
both languages, and the relaxed sets received the same changes in the sections they borrow from
Annex 7.

- **Notice annexes.** In the Notice, items 1.1.3 and 1.1.5 of Annexes 7-2 and 7-3 end with the
  proviso "(단, 정보보호 및 개인정보보호 관리체계 인증의 경우 ‘정보보호’를 ‘정보보호 및
  개인정보보호’로 한다.)". The workbooks omit it and the corpus had followed them. The criterion
  follows the Notice, so the proviso is restored.
- **Applicability.** Annex 7-2 item 1.1.2 is now marked ISMS `-`, as Article 23(3)2 of the Notice
  requires (section 2.6). Check [13] of `tools/check_corpus.py` now holds every item's applicability
  row to Article 23.
- **2.7.1 encryption table.** In the guide, the cells for authentication information (transmission
  over an information and communications network), personal information (transmission over the
  internet network) and the two storage rows regardless of location span both data-subject columns.
  The corpus had put "-" in the non-user column and attached the 2024.9.15 note to authentication
  information. The table now follows the guide. The note belongs to the internet-network row because
  부칙 2 of PIPC Notice 2023-6 defers Article 7(4) (internet-network transmission), not Article 7(1).
- **Other table structure.** 2.9.4 (the 1-year row keeps its 개인정보취급자의 접속기록 label),
  2.11.5 (the 신고 대상 row rejoins its table across the page break), 2.1.2 and 1.1.5 (the two
  column lists are no longer paired row by row), 3.2.5 (the step-1 label as printed, and the quoted
  Article 58-2 under its title), 3.1.5 and 3.3.4 (requirement statements and their sub-points keep
  the guide's two levels), 3.1.5 and the English 2.8.2 (the guide's ★ marker for statutory boxes).
- **Figures.** Every figure of the guide is now transcribed, as Markdown tables, lists or mermaid
  flowcharts with every printed label: 1.2.2 (information service flow diagram, personal information
  flow tables and flow diagrams, PDF pages 31 to 34), 2.8.1 (page 127), 2.8.2 (page 130), 2.10.2
  (two figures, page 157, each with its own source line), 2.11.1 (the seven-phase incident response
  figure, page 175), and the example screens under the nonconformity cases of 3.1.1, 3.1.2 and 3.3.1
  (pages 195, 197, 236), which are quoted blocks so that they do not count as cases. A label the
  guide itself covers with a callout is marked [판독 불가] / [illegible]. Text inside the images is
  transcribed as printed, including two evident misprints in example screens (3.3.1 "집 전화번화",
  1.2.2 "보관기관").
- **Kept differences from the guide text.** These guide-derived passages deliberately differ from
  the printed guide:
  - Misprints corrected: 1.3.1 운명명세서, 2.2.5 a repeated "관련 부서에", 2.4.1 표시판, 2.4.6 SDD,
    2.6.4 응응 프로그램, 2.9.4 용량의, 2.10.4 정보통신 이용촉진(the Act's name), 3.1.4 수감명령
    and 통한 생성한, 3.1.6 해단 and a repeated "촬영 사실을", 3.1.7 전송의 명칭, 3.2.5 토근화,
    3.3.1 제24조제1항제1호 for sensitive-information consent (Article 23) and the wording of case 3,
    3.3.3 기재, 3.5.2 초등교육법, 3.5.3 "이용/내역" and "통지 항목 법적".
  - Statute titles given as enacted: 개인정보 보호법 제31조(개인정보 보호책임자의 지정 등),
    제34조(개인정보 유출 등의 통지/신고), 제58조의2(적용제외), 정보통신망법 제50조(영리목적의
    광고성 정보 전송 제한), 소방시설법 제16조(피난시설, 방화구획 및 방화시설의 관리).
  - Aligned with the statute or the standard: 2.1.2's first CISO duty reads "정보보호 계획의
    수립/시행 및 개선" as in Network Act Article 45-3(4)1 (the guide's table says "정보보호
    관리체계"); in 3.1.3 the reseller case of Network Act Article 23-2(1) is numbered 3, its
    subparagraph number (the guide numbers it 2; subparagraph 2 was deleted on 2020.2.4); 2.6.1's
    private address blocks start at .0 as in RFC 1918 (the guide prints .1); 3.1.6 item 6 drops the
    guide's repeated tail "로서 촬영된 영상을 별도로 저장하지 아니하는 경우".
- **English.** A sentence-by-sentence review corrected 2 high, 6 medium and about 50 low fidelity
  defects, for example 3.1.6 "need not be established" (it read as a prohibition) and "audio
  recording function"; the statutory 개인정보 보호책임자 is "Chief Privacy Officer" throughout;
  the consent gloss for Article 19 in 3.3.1; "fault response" for 장애대응; titles 2.3.4
  ("Expiration") and 2.4.2 ("Physical Entry Control").

## 3. Operating principle

- The corpus follows the **current ISMS-P criteria and guide**, not the newest upstream statute.
- Changes to upstream law (the Personal Information Protection Act (개인정보 보호법), the Standards
  for Ensuring the Safety of Personal Information (개인정보의 안전성 확보조치 기준), and so on) are
  reflected **after** KISA and the PIPC re-issue the Certification Criteria Guide (인증기준 안내서).
- The trigger is a confirmed re-issue. When one lands: record the reflection plan in this document
  first, then update the Korean and English documents **in the same commit**, then regenerate the
  indexes with `python3 tools/build_index.py`.
- Update the "Last checked" date above whenever this register is reviewed, even when nothing changed.
  A stale check date and "no divergences" look identical otherwise.

## 4. Sources checked

- [KISA ISMS-P publication list](https://isms-p.or.kr/ntcn/rcsrm/selectGnrlRcsrmList.do): general
  criteria guide, scheme guide, all three checklist attachments and the three annex files of the
  Notice (downloaded 2026-09-17 and again 2026-10-20).
- law.go.kr open API, effective-date texts (target=eflaw): 정보통신망법 and its Enforcement Decree as in
  force on 2026.10.1, the Personal Information Protection Act and its Enforcement Decree as in force on
  2026.9.11, and the 개인정보의 안전성 확보조치 기준 with its addenda (checked 2026-10-20).
- [Certification notice, 2024.7.24](https://law.go.kr/LSW/admRulInfoP.do?admRulSeq=2100000244750&chrClsCd=010201).
- [Public Data Portal dataset 15106182](https://www.data.go.kr/data/15106182/fileData.do): attachment
  identity confirmed against KISA by SHA-256 on 2026-09-17.

- ISMS-P certification criteria and the Certification Criteria Guide (인증기준 안내서): the official
  repositories of the PIPC (개인정보보호위원회) and of KISA (한국인터넷진흥원); the ISMS-P portal is
  isms-p.or.kr (the former isms.kisa.or.kr host no longer resolves)
- Statutory changes and the 2026 plan: the government press releases on korea.kr (정책브리핑) and the
  국가법령정보센터 open data for the texts in force on each date
- Annex 7-2, 7-3 detailed inspection items: the Public Data Portal (공공데이터포털), provided by KISA <!-- conventions-allow: 공식 표준 용어(데이터, 네트워크) 원문 보존 -->
- The 2026 overhaul of the certification scheme: the PIPC and MSIT announcement (2025.12.6) and the
  published plan (2026.4.10), with the 국가법령정보센터 record of the certification notice used to
  confirm that no amended annex has been promulgated
- Standards for Ensuring the Safety of Personal Information (개인정보의 안전성 확보조치 기준): Korea
  Law Information Center (국가법령정보센터), the administrative-rules database, and PIPC notices
