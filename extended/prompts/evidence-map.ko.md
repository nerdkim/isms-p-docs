# S4. 증적-통제 mapping 및 갭 리포트

> English: [evidence-map.md](evidence-map.md)

`system-grounding.ko.md`를 먼저 적용한 뒤 사용합니다.

```
[작업] 보유 증적을 인증기준 항목에 mapping하고 누락 증적을 도출하십시오.

입력:
- 적용 세트: {{별표7 / 별표7의2 / 별표7의3}}
- 보유 증적 목록(메타데이터: 파일명/유형/담당/주기 등, 본문은 입력하지 않음): {{입력}}

[절차]
1. extended/index/evidence-dictionary.json 의 항목별 "증적 예시"를 mapping 기준 사전으로 사용한다.
참고: defect-rulebook.json 과 evidence-dictionary.json 은 별표 7(한국어)만 담고 있고, 키가 세트 간
비교가 되지 않는 맨 항목번호다. 별표 7의2나 7의3 작업에서는 각 항목 자신의 .md(주요 확인사항 / 증적자료 /
결함사례)에서 룰을 가져온다.
2. 보유 증적을 각 항목의 증적 예시와 대조하여 항목별로 충족 / 부족 / 누락 으로 분류한다.
3. 누락/부족 항목은 어떤 증적 예시가 비었는지 명시하고, 근거로 해당 증적자료 섹션을 인용한다.
4. 각 mapping은 사람이 승인/반려할 수 있는 "후보" 상태로 만든다(실제 증적 진위 검증은 사람 몫).

[출력]
- mapping 결과(JSON): 항목번호 -> 보유증적 -> 충족상태 -> 근거경로
- 누락 증적 To-Do 리스트
extended/outputs/mappings/evidence-control-map-<조직>-<날짜>.json 로 저장한다.
```
