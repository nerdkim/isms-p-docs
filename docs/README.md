# docs/ : the criteria corpus

> 한국어: [README.ko.md](README.ko.md)
>
> Repository overview: [../README.md](../README.md) and source basis: [../UPDATES.md](../UPDATES.md)

This directory is the corpus itself: the ISMS-P certification criteria, one Markdown file per item,
in Korean and English. The indexes under `extended/` and the two `INDEX.md` files here are generated
from these files; the rest of the repository documents them, guards them, or helps agents use them.

## Read-only

Treat this directory as **immutable while using the corpus**. `tools/build_index.py` and
`tools/check_corpus.py` leave item documents untouched. During maintenance the builder regenerates
`docs/ko/INDEX.md` and `docs/en/INDEX.md`. An agent answering questions with the corpus must never
create, edit, or delete anything under `docs/`; save assessment outputs under `extended/outputs/`.

Maintainers do edit these files, of course. That is a different activity, and it comes with its own
rules: see [../CLAUDE.md](../CLAUDE.md) and the bilingual-parity rule below.

## Layout

`docs/<lang>/<set-slug>/<no>.md`, where `<lang>` is `ko` or `en`. The two languages mirror each
other with **identical relative paths**, so an item's counterpart is found by swapping one path
segment. All paths are ASCII, so there are no URL-encoding surprises for consumers.

```
docs/
  ko/                  authoritative Korean documents
    annex7/1.1.1.md    Annex 7,    101 items
    annex7-2/*.md      Annex 7-2,   62 items
    annex7-3/*.md      Annex 7-3,   65 items
    INDEX.md           generated table of contents
  en/                  unofficial English translation, same relative paths
    annex7/1.1.1.md
    ...
    INDEX.md
```

228 items per language, 456 documents in total.

| Set (stable id) | Slug | Items | Applies to | Index |
|---|---|:--:|---|---|
| Annex 7 (`별표7`) | `annex7` | 101 | general ISMS and ISMS-P applicants, full set | [Index](en/INDEX.md) |
| Annex 7-2 (`별표7의2`) | `annex7-2` | 62 | small enterprises, and medium enterprises with previous-year ICT-service revenue under KRW 30 billion | same |
| Annex 7-3 (`별표7의3`) | `annex7-3` | 65 | medium enterprises with ICT-service revenue of KRW 30 billion or more that run no major ICT facilities of their own and use hosting or cloud services certified under ISMS, ISMS-P or CSAP | same |

Annexes 7-2 and 7-3 are not separate certifications. They are relaxed sets that ease the
certification burden for small and medium enterprises (Network Act (정보통신망법) Article 47-7(1);
Enforcement Decree Article 55-7(1), numbered 49-2(1) until 2026.9.30, the number that Notice
Article 23(3) and (4) still cite). Neither set is open to ISPs, IDCs, tertiary general hospitals,
universities, financial companies or virtual-asset service providers (KISA's certification scheme
guide, 2024.07), and the Decree also keeps out a medium enterprise with 1 million or more daily
users (Article 55-7(2)). For an ISMS certification (as opposed to ISMS-P), every set leaves out its
3.x items, and Annex 7-2 also leaves out item 1.1.2 (Notice Article 23(3)2); each document's
applicability row and the manifest's `appliesTo` record this.

In both relaxed sets the criterion and key checkpoints are the official relaxed text; the other
four sections are reused from the Annex 7 control named in the `대응(별표7)` row, and an item whose
criterion merges two Annex 7 controls carries both controls' material, in row order (check [9]
holds every copy identical to its sources after whitespace normalization).

## Document structure

Every item document carries a metadata table, then the same six sections in the same order, then a
source footer:

`Certification criterion` → `Key checkpoints` → `Detailed explanation` →
`Related laws` → `Evidence` → `Nonconformity examples`

`check_corpus.py` fails when a document is missing a section or reorders them, so the structure is
safe to depend on.

## Authority

The **Korean** documents are authoritative. The **English** documents are an unofficial translation
for reference; where the two diverge, the Korean original prevails.

The two languages must change **in the same commit**. A Korean-only or English-only content edit is
a defect. CI rejects one that breaks file pairing, bullet counts or a shared rendering, but a
sentence reworded on one side only passes CI, so review has to catch it. The correspondence is
keyed by (set, item number).

Which official edition each part is based on, and which upstream legal changes are deliberately
**not** reflected, is recorded in [../UPDATES.md](../UPDATES.md). Read it before treating an
apparently out-of-date citation as a bug.

## For AI agents: route through the manifest

Do not grep `docs/` blindly. Start from [`../extended/manifest.json`](../extended/manifest.json),
which indexes every document with its `no`, `path`, set, and per-section counts. Narrow to the
relevant items first, then read only those files.

The full operating rules (source pinning, mandatory citation, human approval gates, immutable
`docs/`) are in [../extended/USAGE.md](../extended/USAGE.md); the plan is in
[../extended/README.md](../extended/README.md).
