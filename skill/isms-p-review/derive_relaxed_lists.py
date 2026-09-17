#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Re-derive the 별표7의2 and 별표7의3 item lists of topic-index.json from its 별표7 lists.

A topic is authored once, as a list of Annex 7 item numbers. The relaxed sets renumber
and drop items, so their lists are not typed by hand: each Annex 7 number is mapped
through the 대응(별표7) row of every relaxed-set document under docs/ko, in the order
of the Annex 7 list, without duplicates. An Annex 7 item with no counterpart simply
contributes nothing, so an empty relaxed list is a fact about the set, not a gap.

Run after editing the 별표7 list of any topic. tools/check_corpus.py check [18] fails
when the committed relaxed lists disagree with this derivation, so the two cannot
drift silently. Dependency-free (Python standard library only).

Usage: python3 skill/isms-p-review/derive_relaxed_lists.py
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
INDEX = os.path.join(HERE, "topic-index.json")
RELAXED = {"별표7의2": "annex7-2", "별표7의3": "annex7-3"}


def reverse_map():
    """{set_id: {annex7_no: [relaxed_no, ...]}} read from the 대응(별표7) rows."""
    out = {set_id: {} for set_id in RELAXED}
    for set_id, slug in RELAXED.items():
        for path in sorted(glob.glob(os.path.join(ROOT, "docs", "ko", slug, "*.md"))):
            name = os.path.basename(path)
            if name == "INDEX.md":
                continue
            text = open(path, encoding="utf-8").read()
            m = re.search(r"(?m)^\| 대응\(별표7\) \| (.*) \|$", text)
            row = m.group(1) if m else ""
            for target in re.findall(r"\(\.\./annex7/([0-9.]+)\.md\)", row):
                out[set_id].setdefault(target, []).append(name[:-3])
    return out


def derive(index, rev):
    changed = 0
    for topic in index["topics"]:
        base = topic["items"].get("별표7", [])
        for set_id in RELAXED:
            expected = []
            for no in base:
                for relaxed in rev[set_id].get(no, []):
                    if relaxed not in expected:
                        expected.append(relaxed)
            if topic["items"].get(set_id) != expected:
                topic["items"][set_id] = expected
                changed += 1
    return changed


def main():
    index = json.load(open(INDEX, encoding="utf-8"))
    changed = derive(index, reverse_map())
    with open(INDEX, "w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print(f"topic-index.json: {len(index['topics'])} topics, {changed} relaxed list(s) rewritten")
    return 0


if __name__ == "__main__":
    sys.exit(main())
