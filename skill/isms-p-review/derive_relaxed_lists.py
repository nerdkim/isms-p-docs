#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Re-derive the 별표7의2 and 별표7의3 parts of topic-index.json from its 별표7 lists.

A topic is authored once, as a list of Annex 7 item numbers. The relaxed sets renumber
and drop items, so their lists are not typed by hand: each Annex 7 number is mapped
through the 대응(별표7) row of every relaxed-set document under docs/ko, in the order
of the Annex 7 list, without duplicates. An Annex 7 item with no counterpart contributes
nothing to the list, and the topic's `no_counterpart` record names it per relaxed set,
so a reader can tell when a set lacks the control the topic is mainly about (its first
Annex 7 item): the derived list then holds only items that answer to the topic's other
Annex 7 items. A topic whose every Annex 7 item has a counterpart carries no record.

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
RECORD = "no_counterpart"

ReverseMap = dict[str, dict[str, list[str]]]


def reverse_map() -> ReverseMap:
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


def derived_list(base: list[str], mapping: dict[str, list[str]]) -> list[str]:
    """The relaxed counterparts of the Annex 7 list, in list order, without duplicates."""
    out = []
    for no in base:
        for relaxed in mapping.get(no, []):
            if relaxed not in out:
                out.append(relaxed)
    return out


def derive_topic(topic: dict, rev: ReverseMap) -> dict:
    """Return a copy of the topic with its relaxed lists and no-counterpart record re-derived."""
    base = topic["items"].get("별표7", [])
    items = {**topic["items"], **{s: derived_list(base, rev[s]) for s in RELAXED}}
    missing = {s: [no for no in base if no not in rev[s]] for s in RELAXED}
    record = {s: nos for s, nos in missing.items() if nos}
    kept = {k: v for k, v in topic.items() if k not in ("items", RECORD)}
    return {**kept, "items": items, **({RECORD: record} if record else {})}


def main() -> int:
    index = json.load(open(INDEX, encoding="utf-8"))
    rev = reverse_map()
    topics = [derive_topic(t, rev) for t in index["topics"]]
    lists = sum(1 for old, new in zip(index["topics"], topics) for s in RELAXED
                if old["items"].get(s) != new["items"][s])
    records = sum(1 for old, new in zip(index["topics"], topics)
                  if old.get(RECORD) != new.get(RECORD))
    with open(INDEX, "w", encoding="utf-8") as fh:
        json.dump({**index, "topics": topics}, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    print(f"topic-index.json: {len(topics)} topics, {lists} relaxed list(s) and "
          f"{records} {RECORD} record(s) rewritten")
    return 0


if __name__ == "__main__":
    sys.exit(main())
