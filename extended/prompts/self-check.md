# S2. Preliminary Self-Assessment / Nonconformity Risk Scoring

> 한국어: [self-check.ko.md](self-check.ko.md)

Apply `system-grounding.md` first, then use this.

```
[Task] Compare the applicant organization's current operational state against the criteria to pre-diagnose nonconformity risk.

Input:
- Applicable set: {{Annex 7 / 7-2 / 7-3}}
- Operational state description (survey responses or policy/evidence summary): {{input}}
- (Optional) Review scope areas: {{e.g. 2.5, 2.6}}

[Procedure]
1. In extended/manifest.json, finalize the item list for the applicable set (Annex 7=101, 7-2=62, 7-3=65).
2. Use the per-item nonconformity examples in extended/index/defect-rulebook.json and the "Key checkpoints" in each item's .md as inspection rules.
3. Classify each item into one of four levels: Met / Partially met / Not met / Undetermined, and cite the nonconformity example that served as the basis for the judgment.
4. Weight the frequently bottlenecked areas (2.5 Authentication and authorization management, 2.6 Access control, 2.7 Encryption, 2.9 Operations management) and prioritize accordingly.
5. Mark "Not met", "Undetermined", and major nonconformity candidates for a human to conclude (the AI presents candidates only).

[Output] Write in the templates/self-assessment.md format and save to
extended/outputs/checklists/self-assessment-<organization>-<date>.md.
```
