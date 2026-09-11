# S3. Policy/guideline draft generation (criterion-mapped)

> 한국어: [policy-draft.ko.md](policy-draft.ko.md)

Apply `system-grounding.md` first, then use this.

```
[Task] Generate a policy/guideline draft mapped to the criteria.

Input:
- Organization profile: industry/size/whether cloud is used/applicable set
- Document type: {{information security policy / access control guideline / internal management plan, etc.}}

[Procedure]
1. From extended/manifest.json, route to the items related to the given document type, matching the `subgroup` field by name (e.g. an access-control guideline routes to 인증 및 권한관리 and 접근통제). Do not route on the number: the relaxed sets renumber, so the same number names a different subject there.
2. Use each item's .md ("Certification criterion + Detailed explanation + Evidence examples") as the basis for writing.
3. Annotate each clause with the criterion item numbers it satisfies, as a mapping comment.
4. For concrete values not in the collection (retention period/complexity thresholds, etc.), leave a [To verify] placeholder.
5. Clearly watermark it as a draft (not a finalized policy).

[Output] Using the templates/policy-draft.md format (including the clause-to-criterion mapping table),
save to extended/outputs/drafts/<document-type>-draft-<date>.md. Finalize after legal/security review.
```
