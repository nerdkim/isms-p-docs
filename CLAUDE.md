# CLAUDE.md

This repository is a **documents-only** reference corpus: the ISMS-P certification criteria, one
Markdown file per item, bilingual in Korean and English. There is no application, no build output,
and no infrastructure here. This file defines the rules AI agents (Claude Code, OpenAI Codex, and
so forth) follow when **maintaining this repository**.

The common engineering standard (interaction, priority, commit, punctuation, terminology,
security) is **not copied into this file**; the playbook docs are the single source. Before
working, read `playbook/docs/README.md` and follow it. This file keeps only what is specific to
this repository. See the managed block at the bottom.

> Project kind: **document corpus** (no application). Branch model: **develop-master** (2-branch).
>
> `AGENTS.md` is a symbolic link to this `CLAUDE.md` (identical content; per playbook `docs/10` the
> real file is `CLAUDE.md`). Claude Code reads `CLAUDE.md`; other agents such as Codex read
> `AGENTS.md`. Edit only this file and both are updated.

## Repository layout

- `docs/` : the per-item criteria documents. `docs/<lang>/<set-slug>/<no>.md`, where `<lang>` is
  `ko` or `en` and the two languages mirror each other with identical relative paths. Annex 7 (101)
  plus Annex 7-2 (62) plus Annex 7-3 (65) is 228 items per language, plus one generated `INDEX.md`
  per language. The Korean side is **authoritative**, based on official source material (detailed
  inspection items 2023.10.31 and 2024.7.24, Certification Criteria Guide 2023.11.23). The English
  side is an **unofficial translation of the Korean original, which prevails**.
- `extended/` : the layer that helps AI agents **use** the corpus. `manifest.json` is the published
  contract; `index/` holds the generated flat index, defect rulebook, and evidence dictionary;
  `prompts/` and `templates/` are the audit-preparation library; `outputs/` is the runtime output
  root. How to use the corpus is described in `extended/README.md` (the plan) and
  `extended/USAGE.md` (operating rules).
- `tools/` : `build_index.py` regenerates every derived index from `docs/`; `check_corpus.py` runs
  read-only integrity checks. Both are dependency-free (Python standard library only).
- `harness/` : the playbook guard set (documentation conventions checker, git hooks). `core.hooksPath`
  is local `.git/config` state and does not travel with a clone, and this repository has no
  `package.json` to hang a `prepare` script on, so the wiring is `bash harness/install-hooks.sh`,
  run once per clone. It is idempotent and writes nothing outside `.git/config`.
- `README.md` / `README.ko.md` : repository introduction (English default, Korean companion).
- `UPDATES.md` / `UPDATES.ko.md` : the source pin **and the known-divergence register**. It records
  which official edition each part of the corpus is based on, and which upstream legal changes are
  deliberately **not** reflected. Read it before treating an apparently out-of-date citation in
  `관련 법규` as a defect: the criteria text only takes on an upstream change when KISA re-issues the
  인증기준 안내서, so the lag is by design.
- `docs/README.md` / `docs/README.ko.md` : the entry point for someone standing inside `docs/`
  (read-only rule, layout, section structure, manifest-first routing). It sits outside the
  `docs/<lang>/**` glob that both builders use, so it is invisible to them.

## Maintenance rules (repository-specific)

Common rules (commit author, branch and GitOps flow, forbidden punctuation, terminology, tests
mandatory) follow the playbook docs. Only repository-specific rules are kept here.

- **English-default meta docs (`X.md` plus `X.ko.md`)**: code, comments, commit messages, and PR
  titles and bodies are written in English. Meta documentation is **bilingual** with the **English
  version as the default `X.md`** and a **Korean companion `X.ko.md`**. This applies to `README` and
  to every file under `extended/` that has a pair. Keep the pair in sync: **edit both language
  versions in the same commit**, and each version links to its counterpart (`> 한국어: [X.ko.md]`
  and `> English: [X.md]`). `CLAUDE.md` and `AGENTS.md` stay **English-only** (single spec;
  `AGENTS.md` is a symlink, per playbook `docs/10`). Exceptions kept Korean-only: the corpus content
  under `docs/` and quotations from Korean official documents and laws.
- Write from fact (official source material); do not invent content that is not in the corpus.
- **Do not "modernize" a legal citation.** The corpus follows the current ISMS-P criteria and guide,
  not the newest upstream statute, and it lags upstream by design. Aligning `관련 법규` to a newer
  notice ahead of a re-issue of the 인증기준 안내서 puts the corpus out of step with its own
  authoritative version. The open divergences and the decision on each are in `UPDATES.md`; when a
  re-issue is confirmed, record the reflection plan there **before** touching `docs/`.
- **Keep Korean and English in sync (important)**: when you add, edit, or delete an item's content,
  **update the corresponding document in the other language in the same commit**. Never leave a
  Korean-only or English-only edit that lets the two versions drift. The correspondence is keyed by
  (set, item number). `tools/check_corpus.py` and CI enforce this.
- **Item documents** keep the 6-section structure (인증기준 / 주요 확인사항 / 세부 설명 / 관련 법규 /
  증적자료 / 결함사례), the metadata table at the top, and the source footer at the bottom. The
  character rules from playbook `docs/16` apply, except that `docs/ko/` and `docs/en/` are a
  confirmed exception listed in `harness/conventions-exclude` (they reproduce authoritative source
  data, not this project's own engineering prose).
- **Regeneration**: `docs/` drives everything derived. Run `python3 tools/build_index.py` after any
  corpus change and commit the result in the same commit. CI regenerates and fails on any diff, so a
  stale `extended/manifest.json` blocks the merge.
- **Do not rename these stable keys**: the standard id `"isms-p"`, the set ids `별표7` / `별표7의2` /
  `별표7의3`, and the schema ids `isms-p-defect-rulebook` / `isms-p-evidence-dictionary`. The web
  viewer and the manifest consumers depend on them.
- **The manifest is a published contract.** `extended/manifest.json` is read by consumers outside
  this repository. Renaming a field or changing a shape breaks them, so bump the `schema` string and
  land the consumer change with it.

## When doing work that uses the corpus

AI work that **uses** the `docs/` corpus (such as ISMS-P audit preparation and response) follows the
plan in `extended/README.md` and the operating rules in `extended/USAGE.md`: source pinning,
manifest-first routing, mandatory citation, human approval gates, and an immutable `docs/`.

## nerdkim 공통 엔지니어링 표준(playbook)

이 repository는 nerdkim 공통 엔지니어링 표준을 따른다. 표준 문서 전체는 함께 두는 `./playbook`에
있다(작업용 참조본이며 git에는 포함하지 않는다). 작업을 시작하기 전에 `playbook/docs/README.md`를 읽고,
거기서 안내하는 규칙(응대 방식, commit, 문장 부호, 용어, 보안 등)을 그대로 따른다. 그 규칙들은 이 파일에
옮겨 적지 않는다. 정본은 언제나 playbook 문서다.

`./playbook`이 없으면 먼저 확보한다: `gh repo clone nerdkim/playbook playbook`(private, gh 인증).
표준을 최신으로 맞추려면 `git -C playbook pull` 후 `bash playbook/install-playbook.sh`를 다시 실행한다.

playbook 버전: v0.1.6 (동기화 기준일 2026-07-21)
