#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Corpus integrity checks for this repository. Read-only: nothing is written.

Checks
  [1] manifest present and self-consistent (counts match the item list)
  [2] Korean and English mirror each other exactly, keyed by (set, item number)
  [3] every item document carries the six required sections, in order
  [4] the H1 heading matches the file name (the item number is the stable key)
  [5] every item document ends with a source footer
  [6] every path recorded in the manifest exists on disk, and no document on disk
      is missing from the manifest
  [7] each document's own Domain/Section (영역/분야) row equals what the manifest
      publishes for that item, so the contract and the document cannot disagree
  [8] the source footer has exactly one form per (set, language)
  [9] Annexes 7-2/7-3 borrow the guide sections verbatim from their Annex 7 source,
      in BOTH languages

Exit code 0 when the corpus is intact, 1 otherwise.

Usage: python3 tools/check_corpus.py
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
MANIFEST = os.path.join(ROOT, "extended", "manifest.json")

LANGS = ("ko", "en")

REQUIRED_SECTIONS = {
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

problems = []


def fail(msg):
    problems.append(msg)


def headings(text):
    return [m.group(1).strip() for m in re.finditer(r"(?m)^##\s+(.+)$", text)]


def check_document(path, lang):
    rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
    text = open(path, encoding="utf-8").read()

    # [4] H1 carries the item number, and it matches the file name.
    expected_no = os.path.splitext(os.path.basename(path))[0]
    first = text.split("\n", 1)[0]
    m = re.match(r"^#\s+(\d+\.\d+\.\d+)\s+\S", first)
    if not m:
        fail(f"{rel}: first line is not a '# <no> <name>' heading")
    elif m.group(1) != expected_no:
        fail(f"{rel}: H1 item number {m.group(1)} does not match the file name {expected_no}")

    # [3] the six required sections, in order.
    found = headings(text)
    required = REQUIRED_SECTIONS[lang]
    cursor = 0
    for title in required:
        while cursor < len(found) and not found[cursor].startswith(title):
            cursor += 1
        if cursor == len(found):
            fail(f"{rel}: missing or out-of-order section '{title}'")
            break
        cursor += 1

    # [5] source footer.
    if not re.search(r"(?m)^---\s*\n>\s*\S", text):
        fail(f"{rel}: missing the trailing source footer ('---' followed by a '>' line)")


# ---------------------------------------------------------------------------
# [7][8][9] helpers
# ---------------------------------------------------------------------------
BORROWED = {
    "ko": ["세부 설명", "관련 법규", "증적자료", "결함사례"],
    "en": ["Detailed explanation", "Related laws", "Evidence", "Nonconformity examples"],
}
META_ROW = {"ko": ("영역", "분야"), "en": ("Domain", "Section")}
FOOTER_RE = re.compile(r"(?ms)\n---\s*\n>.*\Z")


def _sections(text):
    parts = re.split(r"(?m)^(##\s+.+)$", text)
    out = [("", parts[0])]
    for i in range(1, len(parts), 2):
        out.append((parts[i], parts[i + 1]))
    return out


def _body(text, heading):
    for h, b in _sections(text):
        if h.startswith("## " + heading):
            return b
    return None


def _strip_disclaimer(body):
    lines = (body or "").split("\n")
    i = 0
    while i < len(lines) and not lines[i].strip():
        i += 1
    j = i
    while j < len(lines) and lines[j].lstrip().startswith(">"):
        j += 1
    return "\n".join(lines[j:])


def _strip_footer(body):
    m = FOOTER_RE.search(body or "")
    return (body or "")[: m.start()] if m else (body or "")


def _norm(s):
    return re.sub(r"\s+", " ", s or "").strip()


def _row(text, label):
    m = re.search(r"(?m)^\|\s*" + re.escape(label) + r"\s*\|\s*(.+?)\s*\|", text)
    return m.group(1).strip() if m else ""


def check_labels(manifest):
    """[7] the document's own Domain/Section row must equal the manifest value."""
    for it in manifest["items"]:
        path = os.path.join(ROOT, it["path"])
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8").read()
        dom_label, sec_label = META_ROW[it["lang"]]
        want_dom = f"{it['groupNo']}. {it['group']}"
        want_sec = f"{it['subgroupNo']} {it['subgroup']}"
        if _row(text, dom_label) != want_dom:
            fail(f"{it['path']}: {dom_label} row is '{_row(text, dom_label)}' "
                 f"but the manifest publishes '{want_dom}'")
        if _row(text, sec_label) != want_sec:
            fail(f"{it['path']}: {sec_label} row is '{_row(text, sec_label)}' "
                 f"but the manifest publishes '{want_sec}'")


def check_footers():
    """[8] one source-footer form per (set, language)."""
    seen = {}
    for lang in LANGS:
        for path in sorted(glob.glob(os.path.join(DOCS, lang, "*", "*.md"))):
            if os.path.basename(path) == "INDEX.md":
                continue
            slug = os.path.basename(os.path.dirname(path))
            m = re.search(r"(?ms)^---\s*\n(>.*?)\n*\Z", open(path, encoding="utf-8").read())
            if not m:
                continue
            key = (lang, slug)
            first = seen.setdefault(key, (m.group(1).strip(), path))
            if m.group(1).strip() != first[0]:
                fail(f"{os.path.relpath(path, ROOT)}: source footer differs from "
                     f"{os.path.relpath(first[1], ROOT)} (one form per set and language)")


def check_borrowed():
    """[9] relaxed sets borrow the guide sections verbatim, in both languages."""
    for kp in sorted(glob.glob(os.path.join(DOCS, "ko", "annex7-*", "*.md"))):
        if os.path.basename(kp) == "INDEX.md":
            continue
        kt = open(kp, encoding="utf-8").read()
        row = re.search(r"(?m)^\|\s*대응\(별표7\)\s*\|\s*(.+?)\s*\|", kt)
        if not row:
            fail(f"{os.path.relpath(kp, ROOT)}: no 대응(별표7) row")
            continue
        targets = re.findall(r"\]\(\.\./annex7/([0-9.]+)\.md\)", row.group(1))
        src = None
        for cand in targets:
            ct = open(os.path.join(DOCS, "ko", "annex7", cand + ".md"), encoding="utf-8").read()
            if _norm(_body(ct, "세부 설명")) == _norm(_strip_disclaimer(_body(kt, "세부 설명"))):
                src = cand
                break
        if src is None:
            fail(f"{os.path.relpath(kp, ROOT)}: borrowed 세부 설명 matches none of {targets}")
            continue
        for lang in LANGS:
            path = kp.replace(os.sep + "ko" + os.sep, os.sep + lang + os.sep)
            text = open(path, encoding="utf-8").read()
            stext = open(os.path.join(DOCS, lang, "annex7", src + ".md"), encoding="utf-8").read()
            for i, name in enumerate(BORROWED[lang]):
                a, b = _body(text, name), _body(stext, name)
                if i == 0:
                    a = _strip_disclaimer(a)
                if i == 3:
                    a, b = _strip_footer(a), _strip_footer(b)
                if _norm(a) != _norm(b):
                    fail(f"{os.path.relpath(path, ROOT)}: borrowed '{name}' differs from "
                         f"its source {src}")


def main():
    if not os.path.exists(MANIFEST):
        print("extended/manifest.json is missing. Run: python3 tools/build_index.py", file=sys.stderr)
        return 1
    manifest = json.load(open(MANIFEST, encoding="utf-8"))

    # [1] manifest self-consistency.
    items = manifest["items"]
    counts = manifest["counts"]
    for lang in LANGS:
        actual = sum(1 for it in items if it["lang"] == lang)
        if actual != counts.get(lang):
            fail(f"manifest counts.{lang} is {counts.get(lang)} but the item list holds {actual}")
    if counts.get("total") != len(items):
        fail(f"manifest counts.total is {counts.get('total')} but the item list holds {len(items)}")
    for section in manifest["standard"]["sections"]:
        for lang in LANGS:
            actual = sum(
                1 for it in items if it["lang"] == lang and it["section"] == section["id"]
            )
            if actual != section["count"][lang]:
                fail(
                    f"manifest section {section['id']} count.{lang} is "
                    f"{section['count'][lang]} but the item list holds {actual}"
                )

    # [2] Korean and English mirror each other.
    keys = {lang: {(it["section"], it["no"]) for it in items if it["lang"] == lang} for lang in LANGS}
    for lang, other in (("ko", "en"), ("en", "ko")):
        for key in sorted(keys[lang] - keys[other]):
            fail(f"{key[0]} {key[1]} exists in {lang} but is missing in {other}")

    # [6] manifest and disk agree.
    on_disk = set()
    for lang in LANGS:
        for path in glob.glob(os.path.join(DOCS, lang, "**", "*.md"), recursive=True):
            if os.path.basename(path) == "INDEX.md":
                continue
            on_disk.add(os.path.relpath(path, ROOT).replace(os.sep, "/"))
            check_document(path, lang)
    in_manifest = {it["path"] for it in items}
    for missing in sorted(in_manifest - on_disk):
        fail(f"{missing}: recorded in the manifest but not present on disk")
    for extra in sorted(on_disk - in_manifest):
        fail(f"{extra}: present on disk but missing from the manifest")

    check_labels(manifest)
    check_footers()
    check_borrowed()

    if problems:
        for p in problems:
            print(f"FAIL {p}")
        print(f"\nRESULT: FAIL ({len(problems)} problems)")
        return 1
    print(
        f"RESULT: PASS ({counts['total']} documents, "
        + ", ".join(f"{lang} {counts[lang]}" for lang in LANGS)
        + ")"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
