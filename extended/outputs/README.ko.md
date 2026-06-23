# extended/outputs (runtime 산출물)

> English: [README.md](README.md)

AI 에이전트가 만든 모든 산출물은 이 directory 아래에만 작성합니다. `docs/`에는 절대 쓰지 않습니다.
하위 폴더는 작업 시 생성됩니다.

| 폴더 | 용도 | 시나리오 |
|---|---|---|
| `qa-log/` | 인증기준 근거 Q&A 기록 및 감사 로그(입력/사용 경로/모델 버전/일시) | S1 |
| `checklists/` | 사전 셀프 진단 결과 | S2 |
| `drafts/` | 정책/지침 초안(검토용 워터마크 포함) | S3 |
| `mappings/` | 증적-통제 mapping 결과(승인/반려 이력 포함) | S4 |
| `remediation/` | 보완조치 내역서/완료확인서 및 마감 추적(심사 회차별) | S5 |
| `mock-audit/` | 심사 모의 질의응답 | S6 |
| `diffs/`, `regwatch/` | 세트 차이/개정 영향 mapping(자료집 미수록 항목 플래그) | S7 |
| `review-queue/` | 고위험 산출물(법규 해석/적부 판단/정책 확정) 사람 검수 큐 | 공통 |

> 산출물은 실제 운영 데이터를 포함할 수 있으므로, 외부에 올릴 필요가 없다면 `.gitignore`에 `extended/outputs/`를 추가하는 것을 권장합니다. <!-- conventions-allow: 공식 표준 용어(데이터, 네트워크) 원문 보존 -->
