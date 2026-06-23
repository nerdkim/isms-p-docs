# S4. Evidence-to-control mapping and gap report

> 한국어: [evidence-map.ko.md](evidence-map.ko.md)

Use this after first applying `system-grounding.md`.

```
[Task] Map the evidence you hold to the certification criteria items and derive the missing evidence.

Inputs:
- Applicable set: {{Annex 7 / 7-2 / 7-3}}
- List of evidence you hold (metadata: file name/type/owner/cycle etc., do not input the body): {{input}}

[Procedure]
1. Use the per-item "evidence examples" in extended/index/evidence-dictionary.json as the mapping reference dictionary.
2. Compare the evidence you hold against each item's evidence examples and classify each item as met / partial / missing.
3. For missing/partial items, specify which evidence examples are absent, and cite the relevant Evidence section as the basis.
4. Make each mapping a "candidate" status that a human can approve/reject (verifying the actual authenticity of evidence is the human's job).

[Output]
- Mapping result (JSON): item number -> evidence held -> fulfillment status -> basis path
- Missing-evidence To-Do list
Save to extended/outputs/mappings/evidence-control-map-<organization>-<date>.json.
```
