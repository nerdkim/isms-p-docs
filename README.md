# isms-p-docs

> 한국어: [README.ko.md](README.ko.md)

A bilingual reference corpus of the Korean **ISMS-P** certification criteria, one Markdown file
per item, in **Korean and English**.

This repository holds documents only. There is no application here, no build output, and no
infrastructure. A consumer reads [`extended/manifest.json`](extended/manifest.json), which is the
published contract for this corpus.

## Contents

| Set | Items per language | Applies to |
|---|---|---|
| 별표 7 (Annex 7) | 101 | General ISMS / ISMS-P applicants, full set |
| 별표 7의2 (Annex 7-2) | 62 | SMEs with ICT-service revenue under KRW 30 billion |
| 별표 7의3 (Annex 7-3) | 65 | SMEs at or above KRW 30 billion without major ICT facilities |
| **Total** | **228 per language** (456 documents) | |

Annexes 7-2 and 7-3 are not separate certifications. They are simplified sets that ease the
certification burden for SMEs (Network Act Article 47-7, Enforcement Decree Article 49-2); which
set applies depends on the applicant's size and type.

Every item document keeps the same six sections:

`인증기준` → `주요 확인사항` → `세부 설명` → `관련 법규` → `증적자료` → `결함사례`

## Layout

```
docs/
  ko/                    authoritative Korean documents
    annex7/<no>.md       e.g. docs/ko/annex7/1.1.1.md
    annex7-2/<no>.md
    annex7-3/<no>.md
    INDEX.md             generated table of contents
  en/                    unofficial English translation, same relative paths
extended/                the layer that helps AI agents use this corpus
  manifest.json          machine-readable index (the published contract)
  index/                 flat CSV index, defect rulebook, evidence dictionary
  prompts/ templates/    per-scenario prompts and output formats
  outputs/               runtime output root (git-ignored except the readmes)
tools/
  build_index.py         regenerate every derived index from docs/
  check_corpus.py        read-only integrity checks
harness/
  install-hooks.sh       wire this clone to the git hooks (run once, see Setup)
  check-conventions.sh   documentation conventions checker (playbook docs/16)
```

All paths are ASCII, so there are no URL-encoding surprises for consumers.

## Authority and provenance

- The **Korean** documents are authoritative. They are based on the official source material: the
  detailed inspection items of the Notice (Annex 7, 2023.10.31; Annexes 7-2 and 7-3, 2024.7.24) and
  the ISMS-P Certification Criteria Guide (2023.11.23).
- The **English** documents are an unofficial translation for reference. Where the two diverge, the
  Korean original prevails.
- The collection reflects the published source documents. Later revisions of the certification
  scheme may not be reflected; verify against the official source and the certification body's
  guidance before relying on an item.

[UPDATES.md](UPDATES.md) records the exact source edition behind each part of the corpus, **and**
which upstream legal changes are deliberately not reflected. Several items cite a notice as it stood
in 2023 even though it has since been amended, and that is a recorded decision rather than a defect:
the criteria text only takes on such a change when KISA re-issues the 인증기준 안내서. Read it before
"fixing" a citation that looks out of date.

## The manifest contract

`extended/manifest.json` (schema `corpus-manifest/v3`) is what downstream consumers read. It
carries the standard's presentation metadata plus one entry per document:

```json
{
  "schema": "corpus-manifest/v3",
  "standard": {
    "id": "isms-p",
    "nav": "sets",
    "langs": ["ko", "en"],
    "sections": [{ "id": "별표7", "slug": "annex7", "label": { "ko": "별표 7", "en": "Annex 7" },
                   "count": { "ko": 101, "en": 101 } }],
    "source": { "ko": { "criteria_checklist": "...", "criteria_guide": "..." } },
    "itemSections": { "ko": ["인증기준", "..."], "en": ["Certification criterion", "..."] }
  },
  "counts": { "ko": 228, "en": 228, "total": 456 },
  "items": [{
    "lang": "ko", "section": "별표7", "no": "1.1.1", "name": "경영진의 참여",
    "groupNo": "1", "group": "관리체계 수립 및 운영",
    "subgroupNo": "1.1", "subgroup": "관리체계 기반 마련",
    "appliesTo": ["ISMS", "ISMS-P"], "path": "docs/ko/annex7/1.1.1.md",
    "counts": { "checkpoints": 2, "evidence": 5, "defects": 2, "hasLaws": false }
  }]
}
```

**Stable keys, never renamed**: the standard id `isms-p`, the set ids `별표7` / `별표7의2` /
`별표7의3`, and the schema ids `isms-p-defect-rulebook` and `isms-p-evidence-dictionary`. Consumers
key on them.

## Setup

This repository holds documents only, so there is no package manager and no install step to hang
the git-hook wiring on. `core.hooksPath` lives in `.git/config`, which is local state that does not
travel with a clone, so run this **once per clone**:

```bash
bash harness/install-hooks.sh
```

It is idempotent, writes nothing outside `.git/config`, and activates `pre-commit` (documentation
conventions), `commit-msg` (message rules), and `pre-push` (blocks a direct push to master). The
hooks are a convenience guardrail and are bypassable; the authoritative gate is CI
(`.github/workflows/docs.yml`), which runs the same checkers.

Everything else needs only Python 3 (standard library only) and bash.

## Maintaining

```bash
python3 tools/build_index.py    # regenerate extended/ and the docs/{ko,en}/INDEX.md files
python3 tools/check_corpus.py   # read-only integrity checks
bash harness/check-conventions.sh
```

Both builders are deterministic and reproducible: CI regenerates and fails on any diff, so the
committed indexes always match the corpus.

When you add, edit, or delete an item, **update the counterpart document in the other language in
the same commit**. The correspondence is keyed by (set, item number). A Korean-only or English-only
edit is a bug, and CI rejects it.

## License

- Code and tooling: MIT. See [LICENSE](LICENSE).
- The corpus (original explanations, English translation, and the compilation under `docs/`):
  CC BY 4.0. See [LICENSE-CONTENT](LICENSE-CONTENT) and [NOTICE](NOTICE).

These licenses cover this project's own work only. The official ISMS-P source material (KISA and
the Personal Information Protection Commission) remains the property of its owners and is not
relicensed here.
