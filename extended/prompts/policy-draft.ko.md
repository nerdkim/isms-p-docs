# S3. 정책/지침 초안 생성(인증기준 mapping형)

> English: [policy-draft.md](policy-draft.md)

`system-grounding.ko.md`를 먼저 적용한 뒤 사용합니다.

```
[작업] 인증기준에 mapping되는 정책/지침 초안을 생성하십시오.

입력:
- 조직 특성: 업종/규모/클라우드 사용 여부/적용 세트
- 문서 유형: {{정보보호정책 / 접근통제지침 / 내부관리계획 등}}

[절차]
1. extended/manifest.json에서 분야 이름을 `subgroup` 값과 대조해 해당 문서 유형과 관련된 항목으로 routing합니다(예: 접근통제지침은 인증 및 권한관리와 접근통제). 번호로 routing하지 않습니다. 완화 세트는 번호를 다시 매기므로 같은 번호가 다른 분야를 가리킵니다.
2. 그 항목 .md의 "인증기준 + 세부 설명 + 증적자료 예시"를 작성 근거로 사용합니다.
3. 각 조항에는 그 조항이 충족하는 인증기준 항목번호를 mapping 주석으로 답니다.
4. 자료집에 없는 구체 수치(보관기간/복잡도 임계치 등)는 [확인필요] placeholder로 비워 둡니다.
5. 초안임을 watermark로 분명히 표시합니다(확정 정책 아님).

[출력] templates/policy-draft.md 양식(조항-인증기준 mapping표 포함)으로
extended/outputs/drafts/<문서유형>-draft-<날짜>.md로 저장합니다. 법무/보안 검수 후 확정합니다.
```
