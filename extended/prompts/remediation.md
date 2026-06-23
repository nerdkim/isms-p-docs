# S5. Remediation (100-day) Document Drafting Assistance and Deadline Tracking

> 한국어: [remediation.ko.md](remediation.ko.md)

Apply `system-grounding.md` first, then use this.

```
[Task] Draft the remediation records / completion confirmations for the nonconformity report items, and produce a deadline tracking table.

Input:
- Nonconformity report items: {{nonconformity content + relevant criterion number}}
- Nonconformity notification date: {{YYYY-MM-DD}}

[Procedure]
1. For each nonconformity, use its criterion number to read the corresponding item .md under docs/, and cite its "Detailed explanation + Evidence" as the basis for the remediation direction.
2. For each nonconformity, present the remediation direction (before -> after) and the candidate evidence to submit.
3. Compute the deadline timeline: notification date + 40 days (first round) / 100 days total including the extension (final). Mark the deadline calculations to be checked against the original audit team notification.
4. Keep "remediation complete" markings in a "proposed" state until the owner signs off (the actual completion decision is made by a human).

[Output] Save to extended/outputs/remediation/<audit round>/remediation-plan-<date>.md using the templates/remediation.md format (nonconformity number / before and after / evidence / deadline).
```
