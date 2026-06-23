#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Deterministic builder: parse docs/ and regenerate every derived index in this repository.

docs/ is the authoritative corpus and is read-only here; this script never writes into it
except for the generated per-language INDEX.md navigation files.

Inputs
  docs/{ko,en}/{annex7,annex7-2,annex7-3}/<no>.md

Outputs
  extended/manifest.json                    corpus manifest (schema corpus-manifest/v3).
                                            This file is the published contract that downstream
                                            consumers (the web viewer, AI agents) read.
  extended/index/criteria-index.csv         flat index for spreadsheet/human review
  extended/index/defect-rulebook.json       Annex 7 (ko) nonconformity-case rulebook
  extended/index/evidence-dictionary.json   Annex 7 (ko) evidence-example dictionary
  docs/{ko,en}/INDEX.md                     human-facing table of contents

Usage: python3 tools/build_index.py
"""
import csv
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
EXT = os.path.join(ROOT, "extended")
IDX = os.path.join(EXT, "index")

LANGS = ("ko", "en")

# ---------------------------------------------------------------------------
# Corpus constants. The set id ("별표7") is the stable data key: never rename it.
# ---------------------------------------------------------------------------
SET_SLUG = {"별표7": "annex7", "별표7의2": "annex7-2", "별표7의3": "annex7-3"}
SLUG_SET = {v: k for k, v in SET_SLUG.items()}
SET_ORDER = ["별표7", "별표7의2", "별표7의3"]

DOMAINS_KO = {
    "1": "관리체계 수립 및 운영",
    "2": "보호대책 요구사항",
    "3": "개인정보 처리단계별 요구사항",
}
DOMAINS_EN = {
    "1": "Establishment and operation of the management system",
    "2": "Requirements for protection measures",
    "3": "Requirements by personal information processing phase",
}
BUNYA_EN = {
    "1.1": "Laying the foundation of the management system",
    "1.2": "Risk management",
    "1.3": "Operation of the management system",
    "1.4": "Inspection and improvement of the management system",
    "2.1": "Policy, organization, and asset management",
    "2.2": "Human resource security",
    "2.3": "External party security",
    "2.4": "Physical security",
    "2.5": "Authentication and authorization management",
    "2.6": "Access control",
    "2.7": "Application of cryptography",
    "2.8": "Security in information system introduction and development",
    "2.9": "System and service operation management",
    "2.10": "System and service security management",
    "2.11": "Incident prevention and response",
    "2.12": "Disaster recovery",
    "3.1": "Protection measures when collecting personal information",
    "3.2": "Protection measures when retaining and using personal information",
    "3.3": "Protection measures when providing personal information",
    "3.4": "Protection measures when destroying personal information",
    "3.5": "Protection of data subject rights",
}

# Section headings counted per item, by language.
SECTIONS = {
    "ko": {
        "checkpoints": ["주요 확인사항"],
        "laws": ["관련 법규"],
        "evidence": ["증적자료", "증거자료"],
        "defects": ["결함사례"],
    },
    "en": {
        "checkpoints": ["Key checkpoints"],
        "laws": ["Related laws"],
        "evidence": ["Evidence"],
        "defects": ["Nonconformity examples"],
    },
}

# The six-section document structure, published so consumers can validate a document.
ITEM_SECTIONS = {
    "ko": ["인증기준", "주요 확인사항", "세부 설명", "관련 법규", "증적자료", "결함사례"],
    "en": [
        "Certification criterion",
        "Key checkpoints",
        "Detailed explanation",
        "Related laws",
        "Evidence",
        "Nonconformity examples",
    ],
}

# ---------------------------------------------------------------------------
# Presentation metadata. Published in the manifest so a consumer renders the corpus
# without hardcoding knowledge of ISMS-P. Basis for the set split: Network Act Article
# 47-7 and Enforcement Decree Article 49-2 (easing the SME certification burden).
# ---------------------------------------------------------------------------
STANDARD_LABEL = {"ko": "ISMS-P 인증기준", "en": "ISMS-P Certification Criteria"}
STANDARD_BLURB = {
    "ko": "정보보호 및 개인정보보호 관리체계(ISMS-P) 인증기준. 공식 원문 근거.",
    "en": "ISMS-P certification criteria. Based on official source documents.",
}
SET_META = [
    {
        "id": "별표7",
        "order": 0,
        "slug": "annex7",
        "label": {"ko": "별표 7", "en": "Annex 7"},
        "menu": {"ko": "일반 ISMS/ISMS-P", "en": "General ISMS/ISMS-P"},
        "sub": {"ko": "ISMS / ISMS-P 인증기준", "en": "ISMS / ISMS-P criteria"},
        "track": {"ko": "전체 기준", "en": "Full set"},
        "applies": {
            "ko": "일반 ISMS / ISMS-P 신청기관 (전체 기준 적용)",
            "en": "General ISMS/ISMS-P applicants (full set applies)",
        },
    },
    {
        "id": "별표7의2",
        "order": 1,
        "slug": "annex7-2",
        "label": {"ko": "별표 7의2", "en": "Annex 7-2"},
        "menu": {"ko": "간편인증 (300억 미만)", "en": "Simplified (< KRW 30bn)"},
        "sub": {"ko": "간편인증 (완화된 기준)", "en": "Simplified (relaxed set)"},
        "track": {"ko": "간편인증", "en": "Simplified"},
        "applies": {
            "ko": "정보통신서비스 부문 매출액 300억원 미만 중소기업",
            "en": "SMEs with ICT-service revenue under KRW 30 billion",
        },
    },
    {
        "id": "별표7의3",
        "order": 2,
        "slug": "annex7-3",
        "label": {"ko": "별표 7의3", "en": "Annex 7-3"},
        "menu": {"ko": "간편인증 (300억 이상)", "en": "Simplified (>= KRW 30bn)"},
        "sub": {"ko": "간편인증 (완화된 기준)", "en": "Simplified (relaxed set)"},
        "track": {"ko": "간편인증", "en": "Simplified"},
        "applies": {
            "ko": "정보통신서비스 부문 매출액 300억원 이상 중소기업 중 주요 정보통신설비 미보유 기업",
            "en": (
                "SMEs with ICT-service revenue at or above KRW 30 billion that do not hold "
                "major ICT facilities"
            ),
        },
    },
]
SECTIONS_NOTE = {
    "ko": (
        "별표 7은 전체(일반) 인증기준이고, 별표 7의2와 7의3은 중소기업의 인증 부담을 완화한 "
        "간편인증 기준입니다(정보통신망법 제47조의7, 시행령 제49조의2). 신청기관은 규모와 유형에 "
        "따라 세 기준 중 하나가 적용되며, 서로 다른 인증이 아니라 적용 대상이 다른 기준표입니다."
    ),
    "en": (
        "Annex 7 is the full (general) set of criteria, while Annexes 7-2 and 7-3 are simplified "
        "sets that ease the certification burden for SMEs (Network Act Article 47-7, Enforcement "
        "Decree Article 49-2). One of the three applies depending on the applicant's size and type; "
        "they are not different certifications but the same certification with a different "
        "applicable set."
    ),
}
SOURCE = {
    "ko": {
        "criteria_checklist": "고시 별표7 세부점검항목(2023.10.31), 별표7의2/7의3 세부점검항목(2024.7.24)",
        "criteria_guide": "ISMS-P 인증기준 안내서(2023.11.23)",
    },
    "en": {
        "criteria_checklist": "Detailed inspection items: Annex 7 (2023.10.31), Annex 7-2/7-3 (2024.7.24)",
        "criteria_guide": "ISMS-P Certification Criteria Guide (2023.11.23)",
    },
}
PROVENANCE = {
    "ko": (
        "한국어 문서가 정본이며 공식 원문에 근거합니다. 영어 문서는 한국어 정본의 비공식 번역으로, "
        "해석이 갈릴 경우 한국어 정본이 우선합니다."
    ),
    "en": (
        "The Korean documents are authoritative and based on the official source material. The "
        "English documents are an unofficial translation; where they diverge, the Korean original "
        "prevails."
    ),
}


# ---------------------------------------------------------------------------
# Markdown parsing helpers
# ---------------------------------------------------------------------------
def section_body(text, title):
    """Return the body of the '## <title>' section, up to the next '## ' or '---'."""
    m = re.search(
        r"(?m)^##\s+" + re.escape(title) + r"\b[^\n]*\n(.*?)(?=\n##\s|\n---|\Z)", text, re.S
    )
    return m.group(1).strip() if m else ""


def first_section_body(text, titles):
    for t in titles:
        body = section_body(text, t)
        if body:
            return body
    return ""


def bullets(text):
    """Top-level '- ' bullets, skipping italic placeholder lines such as _(none)_."""
    out = []
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("- "):
            v = s[2:].strip()
            if v and not (v.startswith("_") and v.endswith("_")):
                out.append(v)
    return out


def numbered(text):
    return [
        re.sub(r"^\d+\.\s*", "", line.strip())
        for line in text.split("\n")
        if re.match(r"^\d+\.\s", line.strip())
    ]


def counts_for(text, lang):
    sec = SECTIONS[lang]
    return (
        numbered(first_section_body(text, sec["checkpoints"])),
        bullets(first_section_body(text, sec["laws"])),
        bullets(first_section_body(text, sec["evidence"])),
        bullets(first_section_body(text, sec["defects"])),
    )


def meta_row(text, label):
    """Read a value out of the '| <label> | <value> |' metadata table row."""
    m = re.search(r"(?m)^\|\s*" + re.escape(label) + r"\s*\|\s*(.+?)\s*\|", text)
    return m.group(1).strip() if m else ""


def item_sort_key(no):
    return [int(n) for n in no.split(".")]


# ---------------------------------------------------------------------------
# Item parsing
# ---------------------------------------------------------------------------
def parse_item(path, lang, ko_by_key):
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    slug = rel.split("/")[2]  # docs / <lang> / <slug> / <no>.md
    section = SLUG_SET.get(slug, slug)

    text = open(path, encoding="utf-8").read()
    head = re.match(r"^#\s+(\d+\.\d+\.\d+)\s+(.*?)(?:\s+_\(.*\)_)?\s*$", text.split("\n", 1)[0])
    no = head.group(1) if head else os.path.splitext(os.path.basename(path))[0]
    name = head.group(2).strip() if head else no

    if lang == "ko":
        # Domain/bunya come from the in-file metadata table (set-specific).
        dom = re.match(r"^(\d+)\.\s*(.*)$", meta_row(text, "영역"))
        group_no = dom.group(1) if dom else no.split(".", 1)[0]
        group = dom.group(2).strip() if dom else DOMAINS_KO.get(group_no, "")
        bun = re.match(r"^(\d+\.\d+)\s+(.*)$", meta_row(text, "분야"))
        subgroup_no = bun.group(1) if bun else ".".join(no.split(".")[:2])
        subgroup = bun.group(2).strip() if bun else ""
        applies = ["ISMS-P"] if group_no == "3" else ["ISMS", "ISMS-P"]
    else:
        # English items mirror the Korean structure one-to-one, keyed by (set, no).
        ko = ko_by_key.get((section, no), {})
        group_no = ko.get("groupNo", no.split(".", 1)[0])
        group = DOMAINS_EN.get(group_no, ko.get("group", ""))
        subgroup_no = ko.get("subgroupNo", ".".join(no.split(".")[:2]))
        subgroup = BUNYA_EN.get(subgroup_no, ko.get("subgroup", ""))
        applies = ko.get("appliesTo", ["ISMS", "ISMS-P"])

    checks, laws, evidence, defects = counts_for(text, lang)
    return {
        "lang": lang,
        "section": section,
        "no": no,
        "name": name,
        "groupNo": group_no,
        "group": group,
        "subgroupNo": subgroup_no,
        "subgroup": subgroup,
        "appliesTo": applies,
        "path": rel,
        "counts": {
            "checkpoints": len(checks),
            "evidence": len(evidence),
            "defects": len(defects),
            "hasLaws": bool(laws),
        },
        "_laws": laws,
        "_evidence": evidence,
        "_defects": defects,
    }


def collect(lang, ko_by_key):
    files = [
        f
        for f in glob.glob(os.path.join(DOCS, lang, "**", "*.md"), recursive=True)
        if os.path.basename(f) != "INDEX.md"
    ]
    items = [parse_item(f, lang, ko_by_key) for f in files]
    items.sort(key=lambda x: (SET_ORDER.index(x["section"]), item_sort_key(x["no"])))
    return items


# ---------------------------------------------------------------------------
# INDEX.md
# ---------------------------------------------------------------------------
def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def build_docs_index(items, lang):
    base = f"docs/{lang}"
    if lang == "ko":
        heading = "ISMS-P 인증기준 (한국어)"
        subtitle = f"총 {len(items)}개 항목 (별표 7 / 7의2 / 7의3). 공식 원문 기반 정본입니다."
    else:
        heading = "ISMS-P Certification Criteria (English)"
        subtitle = (
            f"{len(items)} items across Annex 7 / 7-2 / 7-3. Unofficial English translation "
            "of the Korean original; the Korean original prevails."
        )
    lines = [f"# {heading}", "", subtitle, ""]
    label = {m["id"]: m["label"][lang] for m in SET_META}
    for setname in SET_ORDER:
        lst = [it for it in items if it["section"] == setname]
        if not lst:
            continue
        lines += [f"## {label[setname]} ({len(lst)})", ""]
        cur_group = cur_sub = None
        for it in lst:
            if it["groupNo"] != cur_group:
                cur_group = it["groupNo"]
                cur_sub = None
                lines += [f"### {it['groupNo']}. {it['group']}", ""]
            if it["subgroupNo"] != cur_sub:
                cur_sub = it["subgroupNo"]
                lines += [f"#### {it['subgroupNo']} {it['subgroup']}", ""]
            href = os.path.relpath(os.path.join(ROOT, it["path"]), os.path.join(ROOT, base))
            lines.append(f"- [{it['no']} {it['name']}]({href})")
        lines.append("")
    return write(f"{base}/INDEX.md", "\n".join(lines).rstrip() + "\n")


# ---------------------------------------------------------------------------
def main():
    ko = collect("ko", {})
    ko_by_key = {(it["section"], it["no"]): it for it in ko}
    en = collect("en", ko_by_key)

    def public(it):
        return {k: v for k, v in it.items() if not k.startswith("_")}

    all_items = [public(it) for it in ko] + [public(it) for it in en]

    def set_count(set_id, lang):
        src = ko if lang == "ko" else en
        return sum(1 for it in src if it["section"] == set_id)

    sections = [
        {
            **{k: v for k, v in meta.items() if k != "order"},
            "count": {lang: set_count(meta["id"], lang) for lang in LANGS},
        }
        for meta in sorted(SET_META, key=lambda m: m["order"])
    ]

    counts = {"ko": len(ko), "en": len(en), "total": len(all_items)}
    manifest = {
        "schema": "corpus-manifest/v3",
        "description": (
            "Machine-readable index of the ISMS-P certification-criteria corpus in this "
            "repository. Consumers locate, cite, and render items from this file."
        ),
        "standard": {
            "id": "isms-p",
            "label": STANDARD_LABEL,
            "blurb": STANDARD_BLURB,
            "nav": "sets",
            "langs": list(LANGS),
            "sections": sections,
            "sectionsNote": SECTIONS_NOTE,
            "source": SOURCE,
            "provenance": PROVENANCE,
            "itemSections": ITEM_SECTIONS,
        },
        "counts": counts,
        "items": all_items,
    }
    os.makedirs(IDX, exist_ok=True)
    with open(os.path.join(EXT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")

    with open(os.path.join(IDX, "criteria-index.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "lang", "set", "no", "name", "domain", "bunya", "applies_to",
                "n_checkpoints", "has_related_laws", "n_evidence", "n_defect_cases", "path",
            ]
        )
        for it in ko + en:
            c = it["counts"]
            w.writerow(
                [
                    it["lang"], it["section"], it["no"], it["name"], it["group"], it["subgroup"],
                    "/".join(it["appliesTo"]), c["checkpoints"], "Y" if c["hasLaws"] else "N",
                    c["evidence"], c["defects"], it["path"],
                ]
            )

    # Annex 7 (ko) is the full control set: the basis for self-assessment tooling.
    b7 = [it for it in ko if it["section"] == "별표7"]
    rulebook = {
        "schema": "isms-p-defect-rulebook/v1",
        "description": (
            "Defect-case rulebook for the 101 Annex 7 criteria. Source of check rules for "
            "self-assessment and mock Q&A."
        ),
        "source": SOURCE["ko"]["criteria_guide"],
        "total_defect_cases": sum(len(it["_defects"]) for it in b7),
        "items": {
            it["no"]: {
                "name": it["name"],
                "bunya": f"{it['subgroupNo']} {it['subgroup']}",
                "path": it["path"],
                "defects": it["_defects"],
            }
            for it in b7
        },
    }
    evidence = {
        "schema": "isms-p-evidence-dictionary/v1",
        "description": (
            "Evidence-example dictionary for the 101 Annex 7 criteria. Reference dictionary for "
            "evidence-to-control mapping."
        ),
        "source": SOURCE["ko"]["criteria_guide"],
        "total_evidence_examples": sum(len(it["_evidence"]) for it in b7),
        "items": {
            it["no"]: {
                "name": it["name"],
                "bunya": f"{it['subgroupNo']} {it['subgroup']}",
                "path": it["path"],
                "evidence": it["_evidence"],
            }
            for it in b7
        },
    }
    for name, payload in (("defect-rulebook.json", rulebook), ("evidence-dictionary.json", evidence)):
        with open(os.path.join(IDX, name), "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=1)
            f.write("\n")

    written = [build_docs_index(ko, "ko"), build_docs_index(en, "en")]

    print(f"manifest v3: {counts['total']} items  {json.dumps(counts, ensure_ascii=False)}")
    print(f"defect-rulebook: {rulebook['total_defect_cases']} cases / {len(b7)} items (Annex 7 ko)")
    print(
        f"evidence-dictionary: {evidence['total_evidence_examples']} examples / {len(b7)} items "
        "(Annex 7 ko)"
    )
    for w in written:
        print("wrote", w)


if __name__ == "__main__":
    main()
