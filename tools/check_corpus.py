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
