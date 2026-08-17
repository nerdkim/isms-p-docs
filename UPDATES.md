# Source basis and update tracking

> 한국어: [UPDATES.ko.md](UPDATES.ko.md)

This document does two things:

1. It **pins the source**: which official edition each part of the corpus is based on.
2. It is the **known-divergence register**: upstream legal changes that have happened since that
   edition, and the recorded decision on each. Most of them are deliberately **not** reflected.

Read part 2 before "fixing" a citation that looks out of date. It probably is not a defect.

Last checked: 2026-07.

## 1. Source versions

| Part of the corpus | Basis | Date |
|---|---|---|
| Annex 7: 인증기준, 주요 확인사항 | Notice [별표 7] detailed inspection items | 2023.10.31 |
| Annex 7-2 and 7-3 (simplified certification) | Notice [별표 7의2, 별표 7의3] detailed inspection items | 2024.7.24 |
| 세부 설명, 관련 법규, 증적자료, 결함사례 | ISMS-P 인증기준 안내서, the Certification Criteria Guide | 2023.11.23 |
| The English documents under `docs/en/` | unofficial translation of the Korean authoritative version above | Korean original prevails |

## 2. Known divergences from current upstream law

### 2.1 Why a divergence is expected, and correct

The ISMS-P criteria text is not a live mirror of the underlying statutes. It changes when KISA and
the PIPC **re-issue the 인증기준 안내서**. Between re-issues, upstream statutes move and the
criteria text does not. This corpus follows the criteria, so it inherits that lag by design.

Aligning this corpus to a newer upstream notice ahead of a re-issue would put it **out of step with
the current authoritative ISMS-P version**, which is the opposite of what a reference corpus is for.

### 2.2 The open divergence: 개인정보의 안전성 확보조치 기준

Many items cite this notice as it stood **effective 2023.9.22**. Since then:

| What changed upstream | When | Reflected here? |
|---|---|---|
| 개인정보의 안전성 확보조치 기준 안내서 published | 2024.10.31 | No |
| 개인정보보호위원회 고시 제2025-9호 amending the notice, effective (includes changes to the uniform internet-network blocking measure system) | 2025.10.31 | No |

**Decision: keep the current text.** The article numbering the criteria depend on (제4조 내부 관리계획
through 제12조 파기) is largely stable across these revisions, and the criteria body only takes on
such a change when the 인증기준 안내서 is re-issued. Rewriting the 관련 법규 sections now would
contradict the current authoritative version (2023.11.23).

### 2.3 Confirmed as current

| Item | Status |
|---|---|
| ISMS-P 인증기준 안내서 | 2023.11.23 is the latest published edition; no later re-issue confirmed. The corpus content is current. |
| 별표 7의2, 7의3 detailed inspection items | The 2024.7.24 revision is fully reflected; the item structure matches 62 and 65. Based on the edition published on 공공데이터포털. <!-- conventions-allow: 공식 표준 용어(데이터, 네트워크) 원문 보존 --> |

## 3. Operating principle

- The corpus follows the **current ISMS-P criteria and guide**, not the newest upstream statute.
- Changes to upstream law (개인정보 보호법, 개인정보의 안전성 확보조치 기준, and so on) are reflected
  **after** KISA and the PIPC re-issue the 인증기준 안내서.
- The trigger is a confirmed re-issue. When one lands: record the reflection plan in this document
  first, then update the Korean and English documents **in the same commit**, then regenerate the
  indexes with `python3 tools/build_index.py`.
- Update the "Last checked" date above whenever this register is reviewed, even when nothing changed.
  A stale check date and "no divergences" look identical otherwise.

## 4. Sources checked

- ISMS-P 인증기준 and 안내서: the official repositories of the PIPC, 개인정보보호위원회, and of
  KISA, 한국인터넷진흥원
- 별표 7의2, 7의3 detailed inspection items: 공공데이터포털, provided by KISA <!-- conventions-allow: 공식 표준 용어(데이터, 네트워크) 원문 보존 -->
- 개인정보의 안전성 확보조치 기준: 국가법령정보센터, the administrative-rules database, and PIPC notices
