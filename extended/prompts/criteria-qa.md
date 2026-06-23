# S1. Criteria-Basis Q&A (Citation-Enforced RAG)

> 한국어: [criteria-qa.ko.md](criteria-qa.ko.md)

Apply `system-grounding.md` first, then use this.

```
[Task] Answer the question below, grounded in the ISMS-P reference collection.

Question: {{user question}}

[Procedure]
1. In extended/manifest.json, find candidate items related to the question (first-pass routing by name/bunya/domain).
2. Read the docs/ .md files of the candidate items and confirm the item that precisely corresponds to the question.
3. Write the answer, appending a [Source: <docs path> > <section>] citation at the end of each sentence.
4. Distinguish and answer which criterion item the nonconformity falls under, what the related laws are, and what evidence to present (cite the Evidence section).
5. If there is no basis in the collection, state "No basis (not in the collection)".

[Output]
- Answer (with citations attached)
- List of item paths used
- Mark "human review required" when an adequacy judgment / legal interpretation is included
Save the output to extended/outputs/qa-log/<date>-<question-summary>.md.
```
