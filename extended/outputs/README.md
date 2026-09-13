# extended/outputs (runtime outputs)

> 한국어: [README.ko.md](README.ko.md)

All outputs produced by AI agents are written only under this directory. Never write to `docs/`.
Subfolders are created as work happens.

| Folder | Purpose | Scenario |
|---|---|---|
| `qa-log/` | Q&A records and audit log for criteria-basis questions (input / paths used / model version / timestamp) | S1 |
| `checklists/` | Preliminary self-assessment results | S2 |
| `drafts/` | Policy/guideline drafts (including a review watermark) | S3 |
| `mappings/` | Evidence-to-control mapping results (including approval/rejection history) | S4 |
| `remediation/` | Remediation statements/completion confirmations and deadline tracking (by audit round) | S5 |
| `mock-audit/` | Mock audit Q&A | S6 |
| `diffs/`, `regwatch/` | Set differences / amendment impact mapping (flags items not in the collection) | S7 |
| `spot-checks/` | Saved copies of content reviews (per-item verdicts with citations), written only when the user asks for a record | S8 |
| `review-queue/` | Human review queue for high-risk outputs (legal interpretation / conformity judgment / policy finalization) | Common |

> Everything under `extended/outputs/` is already git-ignored except these two READMEs, which are
  tracked on purpose so the directory documents itself (see `.gitignore`). Outputs may contain real
  operational data, so keep them out of version control.
