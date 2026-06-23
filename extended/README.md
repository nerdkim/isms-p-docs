# ISMS-P Reference Collection: AI Utilization Plan (extended)

> 한국어: [README.ko.md](README.ko.md)

This document sets out **how AI agents such as Claude Code / OpenAI Codex can use the ISMS-P
certification-criteria reference collection built under `docs/` (101 Annex 7 items + 62/65
special-case items) to help prepare for and respond to an ISMS-P certification audit effectively.**

> Core principle: `docs/` is a **read-only authoritative reference collection** and is never
  modified. Every output the AI produces is written only under this `extended/` layer.

---

## 1. What ISMS-P is, and who obtains it, when, and why

**ISMS-P** (Personal Information and Information Security Management System) is a national
certification operated by the Korea Internet & Security Agency (KISA), with policy jointly held by
the Ministry of Science and ICT (MSIT) and the Personal Information Protection Commission (PIPC). It
splits into information-security-focused **ISMS** (16 management-system + 64 protection-measure = 80
criteria) and **ISMS-P**, which adds personal-information processing-stage requirements (21 items)
on top for a total of 101 criteria. When an organization that handles personal information obtains
ISMS-P, it also satisfies the ISMS obligation.

**The reasons for obtaining it** fall broadly into three categories: (1) fulfilling a legal
obligation, (2) managing accountability/reputation risk in the event of a large-scale breach, and
(3) securing credibility for bids/contracts.

### Applicability (who must obtain it)

| Category | Basis |
|---|---|
| Mandatory target (ISP) | Telecommunications business operators providing information and communications network services in Seoul and all metropolitan cities. Mandatory regardless of revenue/number of users |
| Mandatory target (IDC) | Integrated information and communications facility (data center) operators. Mandatory regardless of revenue/number of users |
| Mandatory target (revenue) | Information and communications service segment prior-year revenue of KRW 10 billion or more / or, among those with annual revenue/receipts of KRW 150 billion or more, tertiary general hospitals and universities with 10,000 or more enrolled students |
| Mandatory target (users) | Daily average of 1 million or more users over the three months immediately preceding the end of the prior year |
| Voluntary application | Public/private entities, corporations, organizations, or individuals that are not mandatory targets applying voluntarily for credibility/bidding incentives |
| Certification special case (simplified) | Small enterprises / mid-sized enterprises with information and communications segment revenue under KRW 30 billion (Annex 7-2), and mid-sized enterprises without major information and communications equipment (Annex 7-3). Reduced items/fees/timeline |
| Preliminary certification | Preliminary ISMS certification that a new virtual-asset service provider obtains first, ahead of full certification (which requires at least 2 months of operation), in order to file with the FIU |

### Timeline/maintenance

- **Acquisition deadline**: obtain by **August 31 of the year after** becoming a mandatory target.
  Failure to comply carries **an administrative fine of up to KRW 30 million** under Article 76 of
  the Network Act (정보통신망법).
- **Valid for 3 years**. During the validity period there is a **post-certification audit at least
  once a year**, and before expiry a **renewal audit** extends validity for another 3 years. Missing
  a post-certification/renewal audit results in loss of effect/revocation.

> **Currency boundary**: this reference collection is based on the detailed inspection items of
  2023.10.31 / the Certification Criteria Guide of 2023.11.23. The full overhaul of the
  certification scheme announced in December 2025 (notice revision planned for Q1 2026:
  reorganization into three tiers of simplified/standard/enhanced, expansion of mandatory targets,
  mandatory technical review, etc.) is **not reflected in the collection**, so the AI must not
  assert this area and should confirm it against external sources (see the guardrails in Section 7).

---

## 2. How the audit proceeds and what it examines

The overall timeline runs about 6 months or more from preparation to acquisition, and applying
requires **at least 2 months of operating history**.

```
Application (8 weeks before target date) -> Preliminary review (6 weeks before, check statement of operations/implementation evidence) -> Contract/fee
 -> Documentary review + on-site audit (1 to 2 weeks) -> Nonconformity report/closing meeting (remediation request form)
 -> Remediation (up to 100 days) -> Certification committee deliberation/resolution -> Certificate issuance (valid 3 years)
```

What the auditor focuses on is not "does the organization possess the documents" but **"can it prove
with evidence that each criterion's key checkpoints are actually operated"**
(operational-effectiveness focus).

- **Nonconformity classification**: general nonconformity / **major nonconformity** (a material
  impact on the management system; the audit may be halted upon confirmation).
- **Frequent-nonconformity focus areas**: 2.5 Authentication and authorization management, 2.6
  Access control, 2.7 Application of encryption, 2.9 System and service operation management
  (logs/access records).
- **Three frequent-nonconformity patterns**: (1) missing/unreported evidence, (2) mismatch between
  policy and operation, (3) failure to implement required protection measures / absence of periodic
  review.
- **Remediation**: complete the first round within 40 days of the nonconformity notification date,
  and complete within a total of **100 days** including extensions. Failure to complete results in
  certification revocation (an initial audit is voided).

**Where AI assistance is most valuable**: (a) generating output drafts based on criteria mapping,
(b) advance self-diagnosis by comparison against nonconformity examples, (c) checking consistency of
policy/settings/logs, (d) automatic evidence mapping/packaging, (e) assisting with drafting
remediation documents.

---

## 3. AI utilization architecture

```
User question/input
   |
   v
[1] manifest.json-first routing  ->  identify relevant items (no, path)
   |
   v
[2] Read only the 6 sections of the relevant docs/item .md as context (read-only)
       Certification criterion / Key checkpoints / Detailed explanation / Related laws / Evidence / Nonconformity examples
   |
   v
[3] Generate output with sources (citations) attached  ->  record only under extended/
   |
   v
[4] Route high-risk outputs (legal interpretation/conformity judgment/policy finalization) to review-queue -> human approval
```

This structure (a) narrows the search scope via `manifest.json`/`index/` to reduce hallucination,
(b) enforces a `docs/` path citation on every claim, and (c) isolates outputs into `extended/` to
keep the collection immutable.

---

## 4. Key utilization scenarios

| ID | Scenario | Input | AI task | Output (extended/) | Human review |
|---|---|---|---|---|---|
| S1 | Criteria-grounded Q&A | Natural-language question | Route to items via manifest, then read only the relevant .md and answer with citations attached | `qa-log/` | Legal-interpretation answers are reviewed |
| S2 | Advance self-diagnosis | Operating-status survey/summary + applicable set | Compare against nonconformity examples/checkpoints to classify as met/not met/partial/pending, and prioritize frequent-nonconformity areas | `checklists/` | Approve the final met/not met judgment |
| S3 | Policy/guideline draft | Organizational characteristics + document type | Draft grounded in criteria/detailed explanation/evidence examples + clause-to-criterion mapping | `drafts/` | Legal/security review |
| S4 | Evidence-to-control mapping | List/metadata of held evidence | Compare against `evidence-dictionary` to map sufficient/insufficient/missing | `mappings/` | Approve/reject the mapping |
| S5 | Remediation document | Nonconformity report items | Skeleton of a remediation statement/completion confirmation grounded in detailed explanation/evidence + 100-day deadline tracking | `remediation/` | Judge remediation completion |
| S6 | Mock Q&A | Applicable set + target area | Turn key checkpoints into anticipated questions, with detailed explanation/evidence as the answer basis | `mock-audit/` | Correct against the organization's actual state |
| S7 | Set/revision impact mapping | Set-transition/revision query | Derive set differences via the set difference of manifest item sets, and flag revisions not in the collection | `diffs/`, `regwatch/` | Compliance officer review |

The execution prompts for each scenario are in [`prompts/`](prompts/), and the output formats are in
[`templates/`](templates/).

---

## 5. extended/ directory layout

```
tools/
  build_index.py                parse docs/ -> regenerate every index below (deterministic, reproducible)
extended/
  README.md                     this plan document
  USAGE.md                      operating rules for collection use (consumer). Reflect into the consuming environment's AGENTS.md/CLAUDE.md
  manifest.json                 machine-readable index of this repository's ISMS-P corpus (456 items: 228 per language). Published contract, schema corpus-manifest/v3
  index/
    criteria-index.csv          flat index (for spreadsheet/human review)
    defect-rulebook.json        nonconformity-example rulebook for the 101 Annex 7 items (381 entries) - self-diagnosis/mock-Q&A rules
    evidence-dictionary.json    evidence-example dictionary for the 101 Annex 7 items (399 entries) - evidence-mapping basis
  prompts/                      per-scenario execution prompts (shared system-grounding)
  templates/                    output formats (self-diagnosis/policy draft/remediation/mock Q&A)
  outputs/                      runtime output root (the subdirectories below are created during work)
    qa-log/ checklists/ drafts/ mappings/ remediation/ mock-audit/ diffs/ regwatch/ review-queue/
```

To rebuild the indexes: `python3 tools/build_index.py` (reads docs/ and writes extended/ plus the
generated `docs/{ko,en}/INDEX.md` navigation files).

---

## 6. Guardrails (must be followed)

1. **Source pinning**: attach a citation with the `docs/` item path and section name to every
   claim/judgment. If a citation cannot be produced, do not output, or state explicitly "No basis
   (not in the collection)".
2. **Limit to the collection's scope (hallucination prevention)**: treat only the 228 ISMS-P `docs/`
   .md files, `manifest.json`/`index/`, and the `references/` originals as authoritative sources.
   Leave figures not in the collection (retention periods/thresholds, etc.) blank with a `[To
   verify]` placeholder.
3. **docs/ immutable**: the AI never modifies/creates/deletes `docs/`. All derivatives are written
   only under `extended/`.
4. **Currency boundary**: note the collection's baseline dates (2023.10.31 / 2023.11.23 / 2024.07)
   in outputs, and do not assert revisions not in the collection, such as the 2026 overhaul; flag
   them as "not in the collection, external confirmation required".
5. **Human approval gate**: legal interpretation, certification conformity judgment, policy
   finalization, final met/not met judgment, and remediation-completion judgment are finalized by a
   human. AI output is in a "proposal/candidate" state.
6. **Input-data control (DLP)**: do not put actual personal information/original evidence content
   into external generative-AI paths. Handle evidence only at the level of filename/type/metadata.
7. **Output identity marking**: mark every AI output with an "AI-generated draft / not reviewed"
   watermark and the generation timestamp/model/grounding items.
8. **Style**: use polite Korean, and do not use em-dash (U+2014) or middle dots (U+00B7, U+2219,
   U+318D) (replace with slash/colon/comma/parentheses/'및').

---

## 7. How to use it with Claude Code

- Reflect into the consuming environment's `CLAUDE.md` the conventions "docs/ is a read-only
  authoritative source, outputs go only into extended/, manifest-first routing, path citation on
  every claim" (refer to/copy this layer's [`USAGE.md`](USAGE.md)).
- **Always manifest-first**: when a natural-language question comes in, first read
  `extended/manifest.json` to narrow to the relevant `path`, then Read only that item's `.md`. Avoid
  spraying grep across all of `docs/`.
- **Turn into skills**: define S1 to S7 as slash skills (e.g. `/isms-selfcheck`,
  `/isms-evidence-map`, `/isms-remediation`), and include the contents of [`prompts/`](prompts/) in
  the skill body.
- **Enforce write guardrails via hooks**: in the PreToolUse hook of `settings.json`, block
  Edit/Write whose path is under `docs/` and allow only `extended/`.
- **Audit logging**: use Stop/PostToolUse hooks to append the input/used-item paths/model
  version/timestamp to `extended/outputs/qa-log/`.

## 8. How to use it with OpenAI Codex

- Place this layer's [`USAGE.md`](USAGE.md) content in the consuming environment's root `AGENTS.md`
  so that Codex recognizes it automatically.
- **Seal off the write scope**: restrict the writable paths to `extended/` via the workspace
  sandbox, or reject `docs/` changes in pre/post hooks.
- **Batch processing**: use it for mapping (S4) that compares held-evidence metadata (CSV/JSON) as
  input against `evidence-dictionary.json`, and for generating policy/remediation drafts (S3/S5)
  into `templates/` (outputs are always in "pending approval"/watermarked state).
- **CI gate**: put a lint at the PR stage that checks whether `extended/` outputs carry `docs/` path
  citations, whether em-dash/middle dots are absent, and whether `git diff -- docs/` is empty
  (collection immutable).

---

## 9. Quick-start example

Question: "If an account left unaccessed for 6 months or more is left neglected, which item's
nonconformity is it, and what are the basis and evidence?"

1. In `extended/manifest.json`, find items whose `name` contains "계정/권한" (2.5.x Authentication
   and authorization management).
2. Read the candidate `path` `.md` files and confirm the item whose "Nonconformity examples"
   includes something like "long-unused account".
3. Attach a citation in the form `[Source: docs/.../2.5.x ....md > Nonconformity examples]` to the
   answer, and cite the evidence to present from the "Evidence" section of the same file.
4. If a conformity judgment/legal interpretation is involved, leave it as a review item in
   `extended/outputs/review-queue/`.

---

## Sources

- KISA ISMS-P certification targets: https://isms.kisa.or.kr/main/ispims/target/
- ISMS-P portal certification targets: https://isms-p.or.kr/cert/aply/selectCertTrgtDetail.do
- ISMS-P Certification Scheme Guide (2024.07), ISMS-P Certification Criteria Guide (2023.11.23)
  (references/)
- Network Act (정보통신망법) Articles 47, 47-7, 76 / Personal Information Protection Act (개인정보
  보호법) Article 32-2
- Guidance on preliminary ISMS certification for virtual-asset service providers (KISA)
- Announcement of the full overhaul of the certification scheme (2025.12): MSIT/PIPC press releases
  and related coverage

> The scheme/audit descriptions in this document are based on public materials as of the time of
  writing (June 2026), and the per-item certification-criteria content is based entirely on the
  `docs/` collection (2023 baseline).
