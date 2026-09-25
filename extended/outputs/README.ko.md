# extended/outputs (runtime 산출물)

> English: [README.md](README.md)

AI agent가 만든 모든 산출물은 이 directory 아래에만 작성합니다. `docs/`에는 절대 쓰지 않습니다.
하위 folder는 작업 시 생성됩니다.

| folder | 용도 | 시나리오 |
|---|---|---|
| `qa-log/` | 인증기준 근거 Q&A 기록 및 감사 log(입력/사용 경로/모델 버전/일시) | S1 |
| `checklists/` | 사전 셀프 진단 결과 | S2 |
| `drafts/` | 정책/지침 초안(검토용 watermark 포함) | S3 |
| `mappings/` | 증적-통제 mapping 결과(승인/반려 이력 포함) | S4 |
| `remediation/` | 보완조치 내역서/완료확인서 및 마감 추적(심사 회차별) | S5 |
| `mock-audit/` | 심사 모의 질의응답 | S6 |
| `diffs/`, `regwatch/` | 세트 차이/개정 영향 mapping(자료집 미수록 항목 표시) | S7 |
| `spot-checks/` | 제출 내용 점검 결과 사본(항목별 판정과 인용). 사용자가 기록을 요청할 때만 작성 | S8 |
| `review-queue/` | 고위험 산출물(법규 해석/적부 판단/정책 확정) 사람 검수 queue | 공통 |

> `extended/outputs/` 아래의 파일은 이 README 두 개를 빼고 모두 이미 git에서 무시됩니다. 이 directory를 설명하려고 두 README만 일부러 git으로 추적합니다(`.gitignore` 참고). 산출물은 실제 운영 data를 포함할 수 있으므로 버전 관리에 넣지 마십시오.
