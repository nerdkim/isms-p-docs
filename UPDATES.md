# Source basis and update tracking

> 한국어: [UPDATES.ko.md](UPDATES.ko.md)

This document does two things:

1. It **pins the source**: which official edition each part of the corpus is based on.
2. It is the **known-divergence register**: upstream legal changes that have happened since that
   edition, and the recorded decision on each. Most of them are deliberately **not** reflected.

Read part 2 before "fixing" a citation that looks out of date. It probably is not a defect.

Last checked: 2026-09-10.

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

The ISMS-P criteria text is not a live mirror of the underlying statutes. It changes when KISA and
the PIPC **re-issue the Certification Criteria Guide (인증기준 안내서)**. Between re-issues,
upstream statutes move and the criteria text does not. This corpus follows the criteria, so it
inherits that lag by design.

Aligning this corpus to a newer upstream notice ahead of a re-issue would put it **out of step with
the current authoritative ISMS-P version**, which is the opposite of what a reference corpus is for.

### 2.2 The open divergence: Standards for Ensuring the Safety of Personal Information

Many items cite this notice (개인정보의 안전성 확보조치 기준) as it stood **effective 2023.9.22**.
Since then:

| What changed upstream | When | Reflected here? |
|---|---|---|
| Guide to the Standards for Measures to Ensure the Safety of Personal Information (개인정보의 안전성 확보조치 기준 안내서) published, then re-issued as the 2025.11 edition | 2024.10.31, 2025.11 | No |
| PIPC Notice 2025-9 (개인정보보호위원회 고시 제2025-9호) amending the notice: the uniform internet-network blocking measure becomes risk-based (the new Article 6-2, in force from promulgation), while the widening of the access-rights and access-records scope (Article 4(1)12 and 13, Article 5(1) and (6), Article 6(2), Article 8(1) and (2)) is deferred by the 부칙 to one year after promulgation, so it is still not in force | 2025.10.31 / 2026.10.31 | No |
| PIPC Notice 2026-9 (개인정보보호위원회 고시 제2026-9호), the current version of the notice | 2026.7.1 | No |
| Personal Information Protection Act (법률 제20897호): the domestic representative must be a domestic corporation the processor established or controls, with a new education and supervision duty (Article 31-2(3)) and matching 과태료 in Article 75. Cited by items 3.5.1 and 1.4.1 | 2025.10.2 | No |
| Enforcement Decree (대통령령 제36121호): Article 42-2(1) who must transmit (its subparagraph 1, the large private-sector class, deferred to 2027.2.20), Article 42-4(1) the scope of self-transmission information, and Article 42-6(3) to (5) the transmission methods, giving content to the standards left to Presidential Decree in Article 35-2. Subject matter of item 3.5.2 | 2026.8.20 | No |
| Personal Information Protection Act, its Enforcement Decree and the related notices: board resolution and filing for the Chief Privacy Officer, notification within 72 hours on the *possibility* of a leak, a new 10 percent of total turnover ceiling for repeated or serious violations (Article 64-2(2)) alongside the retained 3 percent general ceiling (Article 64-2(1)), and ISMS-P certification made mandatory above a size threshold | 2026.9.11 | No |

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
| The two agencies publish the plan (정보보호 및 개인정보보호 관리체계 인증제 실효성 강화방안): the single criteria set is to be reorganized into three tiers (간편, 표준, 강화), the enhanced tier adding 20 criteria and 76 detailed inspection items, and document-centered audit is to give way to technical review and on-site demonstration | 2026.4.10 | No |

**Decision: keep the current text. This is not yet a divergence in the criteria at all.** The
planned notice amendment has not been issued. Re-checked on 2026-09-10, the Notice on certification
(정보보호 및 개인정보보호 관리체계 인증 등에 관한 고시) is still the 2024.7.24 version (개인정보위
고시 제2024-8호 / 과기정통부 고시 제2024-30호) in the 국가법령정보센터 record, so 별표 7, 별표 7의2
and 별표 7의3 are unchanged and the corpus still matches the current authoritative annexes. The
first-quarter-2026 amendment did not land and the published plan works toward a later commencement,
so treat the three-tier restructuring as announced but not in force, and do not pre-empt it.

The trigger for this corpus is unchanged: a re-issue of the 인증기준 안내서, per section 3. When
amended annexes are promulgated the item counts (101 / 62 / 65) are what move first, so record the
reflection plan here **before** touching `docs/`.

### 2.4 Confirmed as current

| Item | Status |
|---|---|
| ISMS-P Certification Criteria Guide (인증기준 안내서) | 2023.11.23 is the latest published edition; no later re-issue confirmed, re-checked 2026-09-10 against the KISA and PIPC repositories. The corpus content is current. |
| Notice on certification (정보보호 및 개인정보보호 관리체계 인증 등에 관한 고시) | The 2024.7.24 version (개인정보위 고시 제2024-8호 / 과기정통부 고시 제2024-30호) is the current one in the 국가법령정보센터 record, re-checked 2026-09-10. 별표 7, 별표 7의2 and 별표 7의3 are unamended, so the pinned annexes are current. |
| Annex 7-2, 7-3 detailed inspection items | The 2024.7.24 revision is fully reflected; the item structure matches 62 and 65. Based on the edition published on the Public Data Portal (공공데이터포털). <!-- conventions-allow: 공식 표준 용어(데이터, 네트워크) 원문 보존 --> |

### 2.5 Resolved: the Annex 7 date in the source footer

The footer used to cite `[별표 7] 세부점검항목(2023.10.31)`, bundling two different sources under
one date. Two facts settle it:

- The 2023 amendment of the Notice is **발령일자 = 시행일자 = 2023.10.5** (개인정보위 고시
  제2023-8호 / 과기정통부 고시 제2023-33호), per the 국가법령정보센터 record. There is no
  2023.10.31 amendment.
- The annex itself carries **only the certification criterion**. A check of every checkpoint
  sentence against the gazette text finds 4 of 328 for Annex 7, 1 of 232 for Annex 7-2 and 1 of 222
  for Annex 7-3: the key checkpoints are not in the annex at all, they come from the separate
  detailed inspection items (세부점검항목).

2023.10.31 is itself confirmed and correct, but for the OTHER document: KISA publishes the detailed
inspection items separately, registered on the Public Data Portal as
`한국인터넷진흥원_ISMS_P 인증기준 세부점검항목_20231031` with a data reference date of 2023.10.31
(data.go.kr dataset 15106188). It is not the Notice's date and must not be "corrected" to 2023.10.5.

The footer now attributes each part separately: the criterion to the Notice annex (2023.10.5), the
key checkpoints to the detailed inspection items (2023.10.31), and the remaining four sections to
the Certification Criteria Guide (2023.11.23).

**That date applies to Annex 7 only.** KISA publishes the detailed inspection items per annex, so
Annexes 7-2 and 7-3 take their own 2024.7.24 editions (Public Data Portal datasets 15134405 with 62
rows and 15134408 with 65 rows), not the 2023.10.31 Annex 7 file, which predates those annexes by
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
detailed inspection items (data.go.kr dataset 15134405, 62 rows, matching the annex's 62 items)
reuse Annex 7's two checkpoints verbatim for 1.1.2, including the reference to 정보보호 최고책임자
및 개인정보 보호책임자. The corpus matches that source.

**Known upstream inconsistency:** the same KISA file reprints the CISO-plus-CPO wording in its own
상세내용 column, which contradicts the gazette. This corpus follows the gazette for the criterion
and the detailed inspection items for the key checkpoints, which is the correct precedence. Do not
"fix" the checkpoints to match the narrowed criterion; they are what the official checklist says.

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

- ISMS-P certification criteria and the Certification Criteria Guide (인증기준 안내서): the official
  repositories of the PIPC (개인정보보호위원회) and of KISA (한국인터넷진흥원)
- Annex 7-2, 7-3 detailed inspection items: the Public Data Portal (공공데이터포털), provided by KISA <!-- conventions-allow: 공식 표준 용어(데이터, 네트워크) 원문 보존 -->
- The 2026 overhaul of the certification scheme: the PIPC and MSIT announcement (2025.12.6) and the
  published plan (2026.4.10), with the 국가법령정보센터 record of the certification notice used to
  confirm that no amended annex has been promulgated
- Standards for Ensuring the Safety of Personal Information (개인정보의 안전성 확보조치 기준): Korea
  Law Information Center (국가법령정보센터), the administrative-rules database, and PIPC notices
