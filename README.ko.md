# isms-p-docs

> English: [README.md](README.md)

**ISMS-P 인증기준**을 항목 하나당 Markdown 파일 하나로 정리한 한국어/영어 이중 언어 자료집입니다.

이 repository에는 문서만 있습니다. 애플리케이션도 build 산출물도 infra도 없습니다. 자료집을 쓰는 쪽은
[`extended/manifest.json`](extended/manifest.json)을 읽습니다. 그 파일이 공개 계약입니다.

## 구성

| 기준표 | 언어별 항목 수 | 적용 대상 |
|---|---|---|
| 별표 7 | 101 | 일반 ISMS / ISMS-P 신청기관, 전체 기준 |
| 별표 7의2 | 62 | 정보통신서비스 부문 매출액 300억원 미만 중소기업 |
| 별표 7의3 | 65 | 매출액 300억원 이상 중소기업 중 주요 정보통신설비 미보유 기업 |
| **합계** | **언어별 228** (문서 456개) | |

별표 7의2와 7의3은 별개의 인증이 아닙니다. 중소기업의 인증 부담을 완화한 간편인증 기준이며(정보통신망법
제47조의7, 시행령 제49조의2), 신청기관의 규모와 유형에 따라 셋 중 하나가 적용됩니다.

모든 항목 문서는 동일한 6개 섹션 구조를 지킵니다.

`인증기준` → `주요 확인사항` → `세부 설명` → `관련 법규` → `증적자료` → `결함사례`

## 디렉터리 구조

```
docs/
  ko/                    정본 한국어 문서
    annex7/<no>.md       예: docs/ko/annex7/1.1.1.md
    annex7-2/<no>.md
    annex7-3/<no>.md
    INDEX.md             생성되는 목차
  en/                    비공식 영어 번역. 상대 경로가 한국어 쪽과 동일
extended/                AI agent가 이 자료집을 사용하도록 돕는 layer
  manifest.json          기계가독 색인(공개 계약)
  index/                 flat CSV 색인, 결함사례 rulebook, 증적 사전
  prompts/ templates/    시나리오별 prompt와 산출물 양식
  outputs/               runtime 산출물 root(readme 외에는 git에서 제외)
tools/
  build_index.py         docs/에서 파생 색인 전체를 재생성
  check_corpus.py        읽기 전용 무결성 검사 19종
  test_check_corpus.py   위 두 도구의 test
harness/
  install-hooks.sh       clone에 git hook을 연결(최초 1회, 설치 절 참고)
  check-conventions.sh   문서 규약 검사기(playbook docs/16)
skill/
  isms-p-review/         Claude Code skill: 전달받은 내용을 인증기준과 대조해 점검(시나리오 S8)
    SKILL.md             절차(routing, 읽기, 판정, 보고 양식)
    topic-index.json     일상 어휘를 세트별 항목 번호로 잇는 routing 표
    derive_relaxed_lists.py  topic 수정 뒤 대응(별표7) 행에서 완화 세트 목록을 다시 유도
```

경로는 전부 ASCII라 consumer 쪽에서 URL encoding 문제가 생기지 않습니다.

## 정본과 출처

- **한국어** 문서가 정본입니다. 공식 원문(고시 별표 7 2023.10.5와 대응 세부점검항목 2023.10.31,
  별표 7의2와 7의3 및 대응 세부점검항목 2024.7.24, ISMS-P 인증기준 안내서 2023.11.23)에 근거합니다.
- **영어** 문서는 참고용 비공식 번역입니다. 해석이 갈리면 한국어 정본이 우선합니다.
- 자료집은 발행된 원문을 반영합니다. 이후 개편 사항은 반영되지 않았을 수 있으니, 항목을 근거로 판단하기 전에
  공식 원문과 인증기관 안내를 확인하십시오.

[UPDATES.ko.md](UPDATES.ko.md)에 자료집의 각 부분이 근거한 정확한 판본과, **어떤 상위 법령 변경을
의도적으로 반영하지 않았는지**가 기록돼 있습니다. 일부 항목은 이후 개정된 고시를 2023년 시행판 기준으로
인용하는데, 이는 결함이 아니라 기록된 결정입니다. 인증기준 본문에는 KISA가 인증기준 안내서를
재발간할 때만 그런 변경이 반영되기 때문입니다. 낡아 보이는 인용을 "고치기" 전에 이 파일을 먼저
읽으십시오.

## manifest 계약

`extended/manifest.json`(schema `corpus-manifest/v3`)이 consumer가 읽는 파일입니다. 표준의 표시용
metadata와 문서 하나당 entry 하나를 담습니다.

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

**절대 이름을 바꾸지 않는 고정 키**: 표준 id `isms-p`, 기준표 id `별표7` / `별표7의2` / `별표7의3`,
schema id `isms-p-defect-rulebook`과 `isms-p-evidence-dictionary`. consumer가 이 값들을 키로 씁니다.

## 설치

이 repository에는 문서만 있어서 package manager도, git hook을 연결할 install 단계도 없습니다.
`core.hooksPath`는 `.git/config`에 있고 이는 clone과 함께 따라오지 않는 local 상태이므로,
**clone마다 한 번씩** 다음을 실행하십시오.

```bash
bash harness/install-hooks.sh
```

여러 번 실행해도 안전하고, `.git/config` 밖에는 아무것도 쓰지 않습니다. `pre-commit`(문서 규약),
`commit-msg`(commit message 규칙), `pre-push`(master 직접 push 차단)를 활성화합니다. hook은 우회할
수 있는 편의용 guardrail이고, 기준이 되는 gate는 같은 검사기를 실행하는
CI(`.github/workflows/docs.yml`)입니다.

나머지는 Python 3(표준 library만)과 bash만 있으면 됩니다.

## Claude Code로 작업하기

Claude Code는 이 repository의 유지보수 규칙을 담은 단일 파일 [CLAUDE.md](CLAUDE.md)를 읽습니다.
[AGENTS.md](AGENTS.md)는 이 파일을 가리키는 symlink이므로 다른 agent도 같은 규칙을 읽습니다. 유지보수
전에 `playbook/docs/README.md`를 읽으십시오. local playbook clone은 작업에 필요한 참조본이며,
임시 파일이 아니므로 지우지 않습니다.

review skill은 `skill/isms-p-review/`에 있습니다. 이 directory를 `~/.claude/skills/`에 symlink로 한 번
연결하면 어느 project에서든 `/isms-p-review` 뒤에 점검할 내용이나 파일 경로를 붙여 이 skill을 부를 수
있습니다.

```bash
ln -s "$PWD/skill/isms-p-review" ~/.claude/skills/isms-p-review
```

skill이 이 symlink를 따라 자료집 root를 찾으므로 skill 사본은 하나만 두십시오. 자료집을 유지보수할 때는
`CLAUDE.md`를 따릅니다. 내용을 점검할 때는 [extended/USAGE.ko.md](extended/USAGE.ko.md)를 따르며
인증기준 원문을 고치지 않습니다. [사용 계획](extended/README.ko.md#7-claude-code-사용법)을 참고하십시오.

## 유지보수

```bash
python3 tools/build_index.py    # extended/와 docs/{ko,en}/INDEX.md 재생성
python3 tools/check_corpus.py   # 읽기 전용 무결성 검사
python3 tools/test_check_corpus.py  # 위 두 도구의 test
bash harness/check-conventions.sh
```

두 builder 모두 결정적이고 재현 가능합니다. CI가 색인을 재생성해 diff가 있으면 실패하므로, commit된
색인은 항상 자료집과 일치합니다.

항목을 추가/수정/삭제할 때는 **같은 commit에서 다른 언어의 대응 문서도 함께 고칩니다**. 대응 관계는
(기준표, 항목번호)로 잡힙니다. 한국어만 또는 영어만 고친 상태는 결함이며 CI가 막습니다.

## 라이선스

- 코드와 도구: MIT. [LICENSE](LICENSE) 참고.
- 자료집(원저작 설명, 영어 번역, `docs/` 편집과 구성): CC BY 4.0. [LICENSE-CONTENT](LICENSE-CONTENT)와
  [NOTICE](NOTICE) 참고.

위 라이선스는 본 프로젝트의 자체 저작물에만 적용됩니다. 공식 ISMS-P 자료(한국인터넷진흥원 KISA,
개인정보보호위원회)는 각 소유자의 권리에 따르며 여기서 재라이선스하지 않습니다.
