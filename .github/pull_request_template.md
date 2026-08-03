<!-- playbook standard PR template (docs/12, docs/20). Write PRs in English (docs/16 4.1).
     This is a documents-only repository: there is no build output and no deploy, so the
     surface below is content and tooling, not a deploy surface. -->

## Summary
<!-- What changes and why, in 1-3 lines. -->

## Change surface
<!-- Check what applies. -->
- [ ] corpus content (`docs/ko/` and `docs/en/`, the item documents)
- [ ] generated indexes (`extended/manifest.json`, `extended/index/`, `docs/{ko,en}/INDEX.md`)
- [ ] audit-preparation library (`extended/prompts/`, `extended/templates/`, `extended/USAGE.md`)
- [ ] tooling (`tools/build_index.py`, `tools/check_corpus.py`)
- [ ] CI / harness / repository meta docs
- [ ] source pin (`UPDATES.md` and `UPDATES.ko.md`)

## Bilingual parity
<!-- Korean is authoritative, English is an unofficial translation of it. A Korean-only or
     English-only content edit is a bug, and CI rejects it. -->
- [ ] Korean and English counterparts changed in **this same commit**, keyed by (set, item number)
- [ ] N/A (this PR touches no item content)

## Verification
<!-- The exact commands you ran and their results; make it reproducible (playbook docs/20 5). -->
- `python3 tools/check_corpus.py` → result:
- `python3 tools/build_index.py` then `git diff --exit-code -- extended docs` → result:
- `bash harness/check-conventions.sh` → result:

## Consumer impact (the manifest contract)
<!-- extended/manifest.json (schema corpus-manifest/v3) is a PUBLISHED CONTRACT read by consumers
     outside this repository. Renaming a field or changing a shape is a breaking change: bump the
     `schema` string and land the consumer change with it. Item count changes flow through without
     a consumer change; schema changes do not. -->
- [ ] no schema change (counts or content only, consumer unaffected)
- [ ] schema changed → `schema` string bumped, and every consumer has a matching change ready

## Source and authority
<!-- Only when corpus content changed. -->
- [ ] the change follows the official source material (detailed inspection items, Certification Criteria Guide) and invents nothing that is not in the source
- [ ] stable keys untouched: standard id `isms-p`, set ids `별표7` / `별표7의2` / `별표7의3`, schema ids `isms-p-defect-rulebook` / `isms-p-evidence-dictionary`

## Rollback
<!-- Concrete steps: revert commit, then re-run build_index.py if the indexes moved. -->
