# S6. Mock Audit Q&A / Interview Preparation

> 한국어: [mock-audit.ko.md](mock-audit.ko.md)

Apply `system-grounding.md` first, then use this.

```
[Task] Generate mock audit Q&A for the specified area/items.

Input:
- Applicable set: {{Annex 7 / 7-2 / 7-3}}
- Certification: {{ISMS / ISMS-P}}
- Target subgroup or item: {{e.g. 접근통제(Access control)}}

[Procedure]
1. Confirm the target items with extended/manifest.json, keeping only those whose `appliesTo` includes the certification (ISMS leaves out the 3.x items of every set and, in Annex 7-2, item 1.1.2 under Notice Article 23(3)2), and read each item's .md.
2. Convert "Key checkpoints" into anticipated auditor questions.
3. Using "Detailed explanation + Evidence" as the basis, build a skeleton of model answers and a list of evidence to present (cite the basis in each answer).
4. Prioritize the commonly cited problem subgroups by name (인증 및 권한관리, 접근통제, 암호화 적용, 시스템 및 서비스 운영관리), matching the manifest `subgroup` field; they are 2.5/2.6/2.7/2.9 in Annex 7 and 7-3 but 2.4/2.5/2.6/2.8 in 7-2.
5. Mark any facts in an answer that must be corrected to your organization's actual situation with [verify in-house].

[Output] Save to extended/outputs/mock-audit/qna-<area>-<date>.md in the templates/mock-audit-qna.md format (anticipated question/answer skeleton/required evidence/basis citation).
```
