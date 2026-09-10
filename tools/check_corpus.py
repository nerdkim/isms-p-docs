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
  [10] every relative markdown link resolves on disk
  [11] no required section is empty, so deleting a section's body cannot pass
  [12] Korean and English agree on content shape: the same bullet count in each
       of the five bullet-bearing sections, so a one-sided edit that drops or
       duplicates a bullet cannot pass on file existence alone. It gives no
       signal on 인증기준 / Certification criterion, which is prose and carries
       no bullets; [14] covers that section only where the Korean is shared
  [13] the metadata table has one row-label sequence per (set, language), and the
       criterion-type row has a single value per set
  [14] identical Korean text gets identical English: where two items share a
       byte-identical criterion or checkpoint list in Korean, the English must
       match too, so translation noise cannot masquerade as a real relaxation
  [15] a Domain/Section number maps to one name within a (set, language), checked
       against its siblings rather than against the manifest built from it
  [16] one Korean statute citation gets one English rendering across the corpus
  [17] each set holds exactly the number of items the official annex defines, so
       a deleted or invented item cannot pass by agreeing with a manifest that
       was regenerated from the same corpus

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

# The exact H2 sequence every item document carries. There is precisely one form
# per language across all 456 documents, so this is pinned rather than matched on a
# prefix: a prefix walk let '## 결함사례' be renamed to '## 결함사례아님' with every
# gate green, because _body() resolves sections the same way.
EXACT_SECTIONS = {
    "ko": ("인증기준", "주요 확인사항", "세부 설명", "관련 법규",
           "증적자료 (증거자료 예시)", "결함사례"),
    "en": ("Certification criterion", "Key checkpoints", "Detailed explanation",
           "Related laws", "Evidence (examples)", "Nonconformity examples"),
}

# The number of items each official annex defines. These move only when amended
# annexes are promulgated, and UPDATES.md section 1 pins the edition while section
# 2.3 requires the reflection plan to be recorded before docs/ is touched.
EXPECTED_COUNTS = {"별표7": 101, "별표7의2": 62, "별표7의3": 65}

# Short names used for lookups and message text; the headings themselves are pinned
# by EXACT_SECTIONS above.
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

    # [3] exactly the six required sections, in order, spelled exactly.
    found = tuple(headings(text))
    if found != EXACT_SECTIONS[lang]:
        expected = EXACT_SECTIONS[lang]
        extra = [h for h in found if h not in expected]
        missing = [h for h in expected if h not in found]
        detail = []
        if missing:
            detail.append("missing " + ", ".join(f"'{h}'" for h in missing))
        if extra:
            detail.append("unexpected " + ", ".join(f"'{h}'" for h in extra))
        if not detail:
            detail.append("out of order: " + " / ".join(found))
        fail(f"{rel}: section headings are wrong ({'; '.join(detail)})")

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
            cpath = os.path.join(DOCS, "ko", "annex7", cand + ".md")
            if not os.path.exists(cpath):
                fail(f"{os.path.relpath(kp, ROOT)}: 대응(별표7) target {cand}.md does not exist")
                continue
            ct = open(cpath, encoding="utf-8").read()
            if _norm(_body(ct, "세부 설명")) == _norm(_strip_disclaimer(_body(kt, "세부 설명"))):
                src = cand
                break
        if src is None:
            fail(f"{os.path.relpath(kp, ROOT)}: borrowed 세부 설명 matches none of {targets}")
            continue
        for lang in LANGS:
            path = kp.replace(os.sep + "ko" + os.sep, os.sep + lang + os.sep)
            spath = os.path.join(DOCS, lang, "annex7", src + ".md")
            if not os.path.exists(path) or not os.path.exists(spath):
                missing = path if not os.path.exists(path) else spath
                fail(f"{os.path.relpath(missing, ROOT)}: expected document is missing")
                continue
            text = open(path, encoding="utf-8").read()
            stext = open(spath, encoding="utf-8").read()
            for i, name in enumerate(BORROWED[lang]):
                a, b = _body(text, name), _body(stext, name)
                if i == 0:
                    a = _strip_disclaimer(a)
                if i == 3:
                    a, b = _strip_footer(a), _strip_footer(b)
                if _norm(a) != _norm(b):
                    fail(f"{os.path.relpath(path, ROOT)}: borrowed '{name}' differs from "
                         f"its source {src}")


BULLET_RE = re.compile(r"(?m)^\s*(?:[-*]|\d+\.)\s+\S")


def _content(body):
    """Section body with the footer and any leading blockquote disclaimer removed."""
    text = _strip_footer(body)
    return "\n".join(l for l in text.split("\n") if not l.lstrip().startswith(">")).strip()


def _item_pairs():
    """Yield (slug, filename, ko_text, en_text) for every mirrored item document."""
    for path in sorted(glob.glob(os.path.join(DOCS, "ko", "*", "*.md"))):
        if os.path.basename(path) == "INDEX.md":
            continue
        epath = path.replace(os.sep + "ko" + os.sep, os.sep + "en" + os.sep)
        if not os.path.exists(epath):
            continue  # [2] and [6] already report a missing mirror
        yield (os.path.basename(os.path.dirname(path)), os.path.basename(path),
               open(path, encoding="utf-8").read(), open(epath, encoding="utf-8").read())


def check_nonempty():
    """[11] no required section may be empty.

    Presence alone is not enough: a heading can stand with nothing under it, which
    would let a criterion's text be deleted with every other gate staying green.
    """
    for lang in LANGS:
        for path in sorted(glob.glob(os.path.join(DOCS, lang, "*", "*.md"))):
            if os.path.basename(path) == "INDEX.md":
                continue
            text = open(path, encoding="utf-8").read()
            for title in REQUIRED_SECTIONS[lang]:
                body = _body(text, title)
                if body is None:
                    continue  # [3] already reports the missing section
                if not _content(body):
                    fail(f"{os.path.relpath(path, ROOT)}: section '{title}' has an empty body")


def check_parity_shape():
    """[12] Korean and English must agree on content shape, not merely both exist.

    Matching keys is not parity: a one-sided edit that drops or duplicates a
    bullet leaves both files in place and passes [2] and [6]. The bullet count per
    section is a cheap invariant that such an edit breaks.

    Scope, stated plainly so the coverage is not overread: this constrains the
    five bullet-bearing sections. 인증기준 / Certification criterion is prose with
    no bullets, so both sides count zero and the check is silent there. [14]
    guards that section wherever the Korean is shared between items, which leaves
    the items with a unique Korean criterion without an automated ko/en check on
    it.
    """
    for slug, name, kt, et in _item_pairs():
        for kn, en in zip(REQUIRED_SECTIONS["ko"], REQUIRED_SECTIONS["en"]):
            kb, eb = _body(kt, kn), _body(et, en)
            if kb is None or eb is None:
                continue  # [3] already reports it
            nk = len(BULLET_RE.findall(_strip_footer(kb)))
            ne = len(BULLET_RE.findall(_strip_footer(eb)))
            if nk != ne:
                fail(f"docs/*/{slug}/{name}: section '{kn}' has {nk} bullets in ko "
                     f"but '{en}' has {ne} in en")


def check_metadata_uniformity():
    """[13] the metadata table must be uniform within a (set, language).

    The Korean side carries one fixed form per set, so a divergence is drift in
    the other language rather than a real difference. Catching it here is what
    keeps the English table from fanning out into variants of one fixed value.
    """
    fixed_row = {"ko": "기준 구분", "en": "Criterion type"}
    for lang in LANGS:
        slugs = sorted({os.path.basename(os.path.dirname(x))
                        for x in glob.glob(os.path.join(DOCS, lang, "*", "*.md"))})
        for slug in slugs:
            base_order = base_path = None
            value = value_path = None
            for path in sorted(glob.glob(os.path.join(DOCS, lang, slug, "*.md"))):
                if os.path.basename(path) == "INDEX.md":
                    continue
                head = open(path, encoding="utf-8").read().split("\n## ", 1)[0]
                rows = re.findall(r"(?m)^\|\s*([^|]+?)\s*\|\s*(.+?)\s*\|\s*$", head)
                rows = [(a, b) for a, b in rows
                        if a not in ("구분", "Field") and not a.startswith("---")]
                order = tuple(a for a, _ in rows)
                if base_order is None:
                    base_order, base_path = order, path
                elif order != base_order:
                    fail(f"{os.path.relpath(path, ROOT)}: metadata row order {list(order)} "
                         f"differs from {list(base_order)} in "
                         f"{os.path.relpath(base_path, ROOT)}")
                for a, b in rows:
                    if a != fixed_row[lang]:
                        continue
                    if value is None:
                        value, value_path = b, path
                    elif b != value:
                        fail(f"{os.path.relpath(path, ROOT)}: '{a}' row is '{b}' but "
                             f"{os.path.relpath(value_path, ROOT)} has '{value}' "
                             f"(one value per set and language)")


def check_shared_text():
    """[14] identical Korean text must get identical English.

    The relaxed sets reuse Annex 7 wording verbatim, so where the Korean is
    byte-identical the English has to be too. Otherwise independent translation
    of the same sentence leaves a difference that reads like a real relaxation.
    Items whose Korean genuinely differs, such as Annex 7-2 1.1.2, never group
    together here, so a deliberate difference cannot be flagged.
    """
    pairs = (("인증기준", "Certification criterion"),
             ("주요 확인사항", "Key checkpoints"))
    groups = {}
    for slug, name, kt, et in _item_pairs():
        for kn, en in pairs:
            kb, eb = _body(kt, kn), _body(et, en)
            if kb is None or eb is None:
                continue
            groups.setdefault((kn, _norm(kb)), []).append((slug, name, en, _norm(eb)))
    for (kn, _ktext), members in sorted(groups.items()):
        variants = {m[3] for m in members}
        if len(variants) < 2:
            continue
        where = ", ".join(f"{m[0]}/{m[1]}" for m in sorted(members)[:6])
        fail(f"section '{kn}' is byte-identical in Korean across {len(members)} items "
             f"but its English has {len(variants)} different renderings ({where})")


def check_label_consistency():
    """[15] a Domain/Section number maps to one name within a (set, language).

    Check [7] compares each document's row against a manifest value derived from
    that same row, so a wrong row agrees with itself. This compares the row
    against its siblings instead, which is independent of the manifest: one
    mistyped 분야 name conflicts with the other items sharing its number. The
    numbers deliberately differ BETWEEN sets, because the relaxed sets renumber,
    so the check is per set.
    """
    row_for = {"ko": ("영역", "분야"), "en": ("Domain", "Section")}
    seen = {}
    for lang in LANGS:
        for path in sorted(glob.glob(os.path.join(DOCS, lang, "*", "*.md"))):
            if os.path.basename(path) == "INDEX.md":
                continue
            slug = os.path.basename(os.path.dirname(path))
            head = open(path, encoding="utf-8").read().split("\n## ", 1)[0]
            for kind, label in zip(("Domain", "Section"), row_for[lang]):
                value = _row(head, label)
                if not value:
                    continue
                number = value.split(".")[0] if kind == "Domain" else value.split(" ")[0]
                key = (lang, slug, kind, number)
                first = seen.setdefault(key, (value, path))
                if value != first[0]:
                    fail(f"{os.path.relpath(path, ROOT)}: {label} '{value}' disagrees with "
                         f"'{first[0]}' in {os.path.relpath(first[1], ROOT)} "
                         f"(same number within {slug}/{lang})")


def check_citation_renderings():
    """[16] one Korean statute citation gets one English rendering.

    Related laws is a list of citations, and the same Korean statute and article
    appeared under several English names (capitalisation, a stray article, "/"
    against ", "). A reader cannot tell whether two differently named citations
    are the same provision, so the rendering has to be single-valued. Keyed on the
    Korean line, so a genuinely different citation is never grouped.
    """
    section = {"ko": "관련 법규", "en": "Related laws"}
    renderings = {}
    for slug, name, kt, et in _item_pairs():
        kb, eb = _body(kt, section["ko"]), _body(et, section["en"])
        if kb is None or eb is None:
            continue
        klines = [l.strip() for l in _strip_footer(kb).splitlines() if l.strip().startswith("-")]
        elines = [l.strip() for l in _strip_footer(eb).splitlines() if l.strip().startswith("-")]
        if len(klines) != len(elines):
            fail(f"docs/*/{slug}/{name}: 'Related laws' lists {len(klines)} citations in ko "
                 f"but {len(elines)} in en")
            continue
        for korean, english in zip(klines, elines):
            first = renderings.setdefault(korean, (english, f"{slug}/{name}"))
            if english != first[0]:
                fail(f"docs/en/{slug}/{name}: citation '{korean}' is rendered "
                     f"'{english}' but '{first[0]}' in docs/en/{first[1]} "
                     f"(one English rendering per Korean citation)")


def check_expected_counts():
    """[17] each set must hold exactly the number of items its official annex defines.

    Checks [2] and [6] compare the corpus against extended/manifest.json, but the
    manifest is generated FROM the corpus, so deleting an item from both languages
    and rebuilding leaves the two in perfect agreement and every gate green. The
    only way out of that circle is a number written down independently, which is
    what EXPECTED_COUNTS is.
    """
    slug_for = {"별표7": "annex7", "별표7의2": "annex7-2", "별표7의3": "annex7-3"}
    for set_id, expected in sorted(EXPECTED_COUNTS.items()):
        slug = slug_for[set_id]
        for lang in LANGS:
            paths = [p for p in glob.glob(os.path.join(DOCS, lang, slug, "*.md"))
                     if os.path.basename(p) != "INDEX.md"]
            if len(paths) != expected:
                fail(f"docs/{lang}/{slug}: holds {len(paths)} items but {set_id} defines "
                     f"{expected} (see UPDATES.md section 1; if an amended annex really "
                     f"changed the count, record the reflection plan there first)")


def check_links():
    """[10] every relative markdown link resolves.

    A footer written as `[별표 7](2023.10.5)` is valid link syntax, so a plain
    text edit can silently turn prose into a broken hyperlink.
    """
    targets = sorted(glob.glob(os.path.join(ROOT, "docs", "**", "*.md"), recursive=True))
    targets += [os.path.join(ROOT, n) for n in ("README.md", "README.ko.md",
                                                "UPDATES.md", "UPDATES.ko.md", "CLAUDE.md")]
    targets += glob.glob(os.path.join(ROOT, "extended", "**", "*.md"), recursive=True)
    for path in targets:
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r"\[([^\]]*)\]\(([^)]+)\)", text):
            target = m.group(2).split("#")[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), target))):
                fail(f"{os.path.relpath(path, ROOT)}: link target '{target}' does not exist "
                     f"(link text '{m.group(1)}')")


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
    check_nonempty()
    check_parity_shape()
    check_metadata_uniformity()
    check_shared_text()
    check_label_consistency()
    check_citation_renderings()
    check_expected_counts()
    check_links()

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
