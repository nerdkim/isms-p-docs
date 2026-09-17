# S8. Review of Submitted Content (Is There an ISMS-P Problem?)

> 한국어: [spot-check.ko.md](spot-check.ko.md)

Apply `system-grounding.md` first, then use this. In Codex or Claude Code the shipped skill
`skill/isms-p-review/SKILL.md` runs this scenario with a routing table
(`skill/isms-p-review/topic-index.json`) in front of the manifest.

```
[Task] Judge whether the content the user handed over (a policy or procedure excerpt, a description of how something is done, a system or configuration note, a screenshot description, an incident write-up, a contract clause) is a problem under the ISMS-P certification criteria. There may be no problem; if so, say exactly that.

Input:
- Submitted content: {{text / file path / description}}
- Applicable set: {{Annex 7 / 7-2 / 7-3}} (if absent, use Annex 7 and state that assumption)

[Procedure]
1. Personal data gate: if the content shows what looks like real personal data (resident registration numbers, phone numbers, email addresses, and so on), do not repeat it; write [masked] in its place and say how many values you masked.
2. Break the content into assertions (each concrete statement about how something is done, decided, configured, or omitted). Note the context given and the unknowns.
3. Route before reading: match the assertions against extended/manifest.json (Korean items of the applicable set, by name and subgroup) and, for Annex 7, against extended/index/defect-rulebook.json. Keep about 8 primary items and list the rest as secondary. Do not grep all of docs/.
4. Read the docs/ko .md of every primary item in full (the English mirror only when the user works in English).
5. Mark every key checkpoint of each primary item against the assertions: 충족 근거 있음 / 미충족 / 정보 부족 / 해당 없음. Then give the item one verdict: 결함 후보 (at least one checkpoint 미충족; quote the assertion, the checkpoint, and the matching nonconformity example), 확인 필요 (nothing 미충족 but a relevant checkpoint is 정보 부족; list the evidence that would settle it, from the Evidence section), 문제 없음 (every relevant checkpoint met or not applicable; say so plainly), or 범위 외 (a real concern the corpus does not decide: legal interpretation, the 2026 overhaul, certification obligation and procedure). Absence of information is 확인 필요, never 문제 없음. Never grade a candidate as major or minor, and never state a number the item's own text does not print.
6. If nothing routes, write plainly that the content does not touch an ISMS-P criterion as far as the collection can tell, and list what you searched for.
7. Quote the item's Related laws line as it stands and do not interpret it. Say once that the citations are as of the Certification Criteria Guide of 2023.11.23 and that later amendments are not reflected.

[Output] Reply in the templates/spot-check.md format (Korean for a Korean user, polite register). Lead with the one-line conclusion. Cite every table row and every basis bullet as docs/ko/<set>/<no>.md > <section>.
Files are written only when the user asks for a saved copy: extended/outputs/spot-checks/spot-check-<topic>-<date>.md, plus one line in extended/outputs/review-queue/<date>-spot-check.md when any verdict is 결함 후보 or a legal point is involved.
```
