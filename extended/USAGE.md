# Collection Usage Rules (USAGE)

> 한국어: [USAGE.ko.md](USAGE.ko.md)

This document is the operating agreement for the consumer side: an AI that uses the `docs/` criteria
collection to perform ISMS-P work. The rules for maintaining this repository itself are in the root
`CLAUDE.md` and `AGENTS.md`.

> If you consume the collection in another repository/environment, reflect the contents of this
  document into that environment's `AGENTS.md` (Codex) or `CLAUDE.md` (Claude Code).

## Authoritative sources and write scope

- `docs/` is the **read-only** authoritative collection. Under no circumstances do you
  create/modify/delete anything under `docs/`.
- All outputs are written only under `extended/outputs/`.
- The authoritative sources are only the 228 `.md` files in `docs/`, `extended/manifest.json`,
  `extended/index/*`, and the original material in `references/`. Do not assert
  criteria/laws/figures from the model's general knowledge.

## Workflow (manifest first)

1. Read `extended/manifest.json` first and narrow the scope to the items (`no`, `path`) relevant to
   the question/task. Do not run a random grep across all of `docs/`.
2. Read only the `.md` files for the narrowed items into context. Each file consists of 6 sections
   (Certification criterion / Key checkpoints / Detailed explanation / Related laws / Evidence /
   Nonconformity examples).
3. If self-assessment/mapping is needed, use `extended/index/defect-rulebook.json` (nonconformity
   rules) and `evidence-dictionary.json` (evidence dictionary).

## Output rules

- **Mandatory citation**: Append `[Source: <docs path> > <section>]` to the end of every
  claim/judgment. Content that cannot be cited is either not output or marked as "No basis (not in
  the collection)".
- **Placeholders**: Leave figures/facts not in the collection blank as `[To verify]`.
- **Status line**: At the head of the output, write `Status: AI-generated draft / not reviewed`, the
  generation timestamp, the model version, and the list of source items.
- **Human gate**: Interpretation of laws, certification eligibility judgments, policy finalization,
  final met/not-met determinations, and remediation-completion determinations are finalized by a
  human. Such outputs are also kept as review items in `extended/outputs/review-queue/`.
- **Currency boundary**: State the collection's reference date (detailed inspection items 2023.10.31
  / Certification Criteria Guide 2023.11.23), and do not assert unlisted revisions such as the 2026
  reform; instead flag them as "not in the collection, external verification required".
- **DLP**: Do not input actual personal data or the body of original evidence into external models.
  Handle evidence only at the level of file name/type/metadata.

## Style

- Use polite language (존댓말) for user-facing sentences.
- Do not use em-dash (U+2014) or middle dots (U+00B7, U+2219, U+318D). Use slash (/), colon (:),
  comma (,), parentheses, and '및' for separation/joining. Even if the source has a middle dot,
  convert it to a slash in the output.

## Verification (recommended CI lint)

- `git diff -- docs/` must be empty (the collection is immutable).
- Outputs under `extended/outputs/` must contain at least one `[Source: docs/...]` citation.
- Outputs must contain no em-dash (U+2014) or middle dots (U+00B7, U+2219, U+318D).
