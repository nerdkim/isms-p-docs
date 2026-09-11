# S2. Preliminary Self-Assessment / Nonconformity Risk Scoring

> 한국어: [self-check.ko.md](self-check.ko.md)

Apply `system-grounding.md` first, then use this.

```
[Task] Compare the applicant organization's current operational state against the criteria to pre-diagnose nonconformity risk.

Input:
- Applicable set: {{Annex 7 / 7-2 / 7-3}}
- Operational state description (survey responses or policy/evidence summary): {{input}}
- (Optional) Review scope areas, by subgroup name: {{e.g. 인증 및 권한관리, 접근통제}}

[Procedure]
1. In extended/manifest.json, finalize the item list for the applicable set (Annex 7=101, 7-2=62, 7-3=65).
2. Use the per-item nonconformity examples in extended/index/defect-rulebook.json and the "Key checkpoints" in each item's .md as inspection rules.

Note: defect-rulebook.json and evidence-dictionary.json cover Annex 7 (Korean) only, and their
keys are bare item numbers that are not comparable across sets. For an Annex 7-2 or 7-3 run, take
the rules from each item's own .md (Key checkpoints / Evidence / Nonconformity examples).
3. Classify each item into one of four levels: Met / Partially met / Not met / Undetermined, and cite the nonconformity example that served as the basis for the judgment.
4. Weight the frequently bottlenecked subgroups and prioritize accordingly: 인증 및 권한관리(Authentication and authorization management), 접근통제(Access control), 암호화 적용(Application of encryption), 시스템 및 서비스 운영관리(System and service operation management). Match on the manifest `subgroup` field, not on the number: the same number names a different subject in Annex 7-2 and 7-3, which renumber (those four are 2.5, 2.6, 2.7 and 2.9 in Annex 7 only).
5. Mark "Not met", "Undetermined", and major nonconformity candidates for a human to conclude (the AI presents candidates only).

[Output] Write in the templates/self-assessment.md format and save to
extended/outputs/checklists/self-assessment-<organization>-<date>.md.
```
