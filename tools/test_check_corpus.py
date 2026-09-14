#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests for the Python guards: tools/check_corpus.py and tools/build_index.py.

The bash guard (harness/check-conventions.sh) has had a test suite from the start;
these two did not, so every failure path they claim to cover was unexercised. A
check that never fails on a broken corpus is indistinguishable from no check.

Each case copies the corpus to a throwaway directory, breaks exactly one thing,
and asserts that check_corpus.py reports it. The repository itself is never
written to.

Dependency-free (Python standard library only).

Usage: python3 tools/test_check_corpus.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COPY_DIRS = ("docs", "extended", "tools", "skill")
COPY_FILES = ("README.md", "README.ko.md", "UPDATES.md", "UPDATES.ko.md", "CLAUDE.md",
              "LICENSE", "LICENSE-CONTENT", "NOTICE")

passed = 0
failed = 0


def report(ok, name, detail=""):
    global passed, failed
    if ok:
        passed += 1
        print(f"  PASS: {name}")
    else:
        failed += 1
        print(f"  FAIL: {name}{(' - ' + detail) if detail else ''}")


def make_corpus(tmp):
    work = os.path.join(tmp, "repo")
    os.makedirs(work)
    for name in COPY_DIRS:
        shutil.copytree(os.path.join(ROOT, name), os.path.join(work, name))
    for name in COPY_FILES:
        src = os.path.join(ROOT, name)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(work, name))
    return work


def run_check(work):
    proc = subprocess.run([sys.executable, os.path.join(work, "tools", "check_corpus.py")],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def case(name, mutate, expect):
    """Break one thing, then require check_corpus to exit 1 and say so."""
    with tempfile.TemporaryDirectory() as tmp:
        work = make_corpus(tmp)
        mutate(work)
        code, out = run_check(work)
        if code == 0:
            report(False, name, "check_corpus PASSED a corpus it should have rejected")
        elif expect not in out:
            report(False, name, f"rejected, but no message matching {expect!r}")
        else:
            report(True, name)


def main():
    print("== baseline ==")
    with tempfile.TemporaryDirectory() as tmp:
        work = make_corpus(tmp)
        code, out = run_check(work)
        report(code == 0, "an untouched copy of the corpus passes", out.strip()[-300:])

    print("== [11] empty section body ==")

    def empty_section(work):
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.1.md")
        t = read(p)
        t = re.sub(r"(?ms)^## 인증기준\n.*?(?=^## )", "## 인증기준\n\n", t)
        write(p, t)

    case("an emptied section body is rejected", empty_section, "empty body")

    print("== [12] one-sided content edit ==")

    def drop_bullet_ko(work):
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.1.md")
        lines = read(p).split("\n")
        for i, line in enumerate(lines):
            if line.startswith("- "):
                del lines[i]
                break
        write(p, "\n".join(lines))

    case("a bullet dropped in Korean only is rejected", drop_bullet_ko, "bullets in ko")

    def add_bullet_en(work):
        p = os.path.join(work, "docs", "en", "annex7", "1.1.1.md")
        lines = read(p).split("\n")
        for i, line in enumerate(lines):
            if line.startswith("- "):
                lines.insert(i, "- an extra bullet that Korean does not have")
                break
        write(p, "\n".join(lines))

    case("a bullet added in English only is rejected", add_bullet_en, "in en")

    print("== [13] metadata drift ==")

    def drift_criterion_type(work):
        p = os.path.join(work, "docs", "en", "annex7-2", "1.1.1.md")
        t = read(p).replace("| Criterion type | Annex 7-2 (special provisions for certification, "
                            "relaxed certification criteria) |",
                            "| Criterion type | Annex 7-2 (certification special case, relaxed) |")
        write(p, t)

    case("a divergent criterion-type value is rejected", drift_criterion_type,
         "one value per set and language")

    def reorder_rows(work):
        p = os.path.join(work, "docs", "en", "annex7-2", "1.1.1.md")
        t = read(p)
        m = re.search(r"(?m)^\| Korean source \| .*\|\n", t)
        t = t.replace(m.group(0), "")
        t = t.replace("| Domain |", m.group(0) + "| Domain |", 1)
        write(p, t)

    case("a reordered metadata table is rejected", reorder_rows, "metadata row order")

    print("== [14] shared Korean text, divergent English ==")

    def diverge_shared_english(work):
        # 1.1.1 is byte-identical in Korean across all three sets, so the English
        # must match. Re-translate one of them and the group splits.
        p = os.path.join(work, "docs", "en", "annex7-2", "1.1.1.md")
        t = read(p)
        t = re.sub(r"(?ms)^## Certification criterion\n.*?(?=^## )",
                   "## Certification criterion\n\nAn independently reworded rendering of the same "
                   "Korean sentence.\n\n", t)
        write(p, t)

    case("an independently reworded English twin is rejected", diverge_shared_english,
         "different renderings")

    print("== [15] label disagreeing with its siblings ==")

    def diverge_label(work):
        p = os.path.join(work, "docs", "ko", "annex7", "2.5.1.md")
        t = read(p)
        t = re.sub(r"(?m)^\|\s*분야\s*\|\s*.+?\s*\|$", "| 분야 | 2.5 접근통제 |", t, count=1)
        write(p, t)

    case("a 분야 name disagreeing with its siblings is rejected", diverge_label,
         "same number within")

    print("== [16] one Korean citation, two English renderings ==")

    def diverge_citation(work):
        # Re-render one citation line in a single document; the 83 other documents
        # citing the same Korean provision still carry the canonical form.
        p = os.path.join(work, "docs", "en", "annex7", "1.1.3.md")
        t = read(p)
        old_line = "- Personal Information Protection Act Article 29 (Duty of Safety Measures)"
        assert old_line in t, "test fixture moved: expected a PIPA Article 29 citation"
        write(p, t.replace(old_line,
                           "- Personal Information Protection Act Art. 29 (Safety Measure Duty)", 1))

    case("a re-rendered citation line is rejected", diverge_citation,
         "one English rendering per Korean citation")

    print("== pre-existing checks still bite ==")

    def remove_section(work):
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.2.md")
        write(p, read(p).replace("## 결함사례", "## 사례 모음"))

    case("[3] a renamed required section is rejected", remove_section,
         "section headings are wrong")

    def rename_section_keeping_prefix(work):
        # The heading walk used to match on a prefix, so this rename passed every
        # gate: [3] accepted it and _body() still resolved the section.
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.4.md")
        write(p, read(p).replace("## 결함사례", "## 결함사례아님"))

    case("[3] a rename that keeps the required prefix is rejected",
         rename_section_keeping_prefix, "section headings are wrong")

    def break_h1(work):
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.3.md")
        write(p, read(p).replace("# 1.1.3 ", "# 9.9.9 ", 1))

    case("[4] an H1 number not matching the file name is rejected", break_h1,
         "does not match the file name")

    def drop_footer(work):
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.4.md")
        t = read(p)
        write(p, re.sub(r"(?ms)\n---\s*\n>.*\Z", "\n", t))

    case("[5] a missing source footer is rejected", drop_footer, "source footer")

    def diverge_footer(work):
        p = os.path.join(work, "docs", "ko", "annex7", "1.1.5.md")
        write(p, read(p).replace("(2023.10.31)", "(2099.1.1)"))

    case("[8] a footer differing within a set is rejected", diverge_footer, "source footer differs")

    def break_borrowed(work):
        p = os.path.join(work, "docs", "ko", "annex7-2", "1.1.1.md")
        t = read(p)
        t = re.sub(r"(?ms)^## 세부 설명\n(.*?)(?=^## )",
                   "## 세부 설명\n\nrewritten so it no longer matches its Annex 7 source.\n\n", t)
        write(p, t)

    case("[9] a borrowed section that stops matching its source is rejected", break_borrowed,
         "borrowed")

    def break_link(work):
        # A link outside the 대응(별표7) row, so only check_links can fire: the
        # mapping row would also trip check_borrowed and its crash guard.
        p = os.path.join(work, "docs", "README.md")
        t = read(p)
        assert "../UPDATES.md" in t, "test fixture moved: expected a link to ../UPDATES.md"
        write(p, t.replace("../UPDATES.md", "../UPDATES-does-not-exist.md"))

    case("[10] a link target that does not exist is rejected", break_link,
         "link target '../UPDATES-does-not-exist.md'")

    def delete_mirror(work):
        os.remove(os.path.join(work, "docs", "en", "annex7", "2.1.1.md"))

    case("[2]/[6] a deleted English mirror is rejected", delete_mirror,
         "recorded in the manifest but not present on disk")

    print("== [1] manifest self-consistency ==")

    def perturb_manifest_counts(work):
        p = os.path.join(work, "extended", "manifest.json")
        data = json.load(open(p, encoding="utf-8"))
        data["counts"]["total"] = data["counts"]["total"] + 1
        with open(p, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=1)

    case("a manifest whose counts disagree with its item list is rejected",
         perturb_manifest_counts, "manifest counts.total is")

    print("== [7] document label against the manifest ==")

    def desync_label(work):
        # Edit the 영역 row without rebuilding, so the document and the published
        # contract disagree.
        p = os.path.join(work, "docs", "ko", "annex7", "1.2.1.md")
        t = read(p)
        m = re.search(r"(?m)^\|\s*영역\s*\|\s*(.+?)\s*\|$", t)
        assert m, "test fixture moved: expected an 영역 metadata row"
        write(p, t.replace(m.group(0), "| 영역 | 9. 존재하지 않는 영역 |", 1))

    case("a metadata label disagreeing with the manifest is rejected", desync_label,
         "but the manifest publishes")

    print("== [17] the official item counts ==")

    def delete_item_and_rebuild(work):
        # The failure mode [17] exists for: remove an item from BOTH languages and
        # rebuild, so corpus and manifest agree perfectly and [2]/[6] see nothing.
        for lang in ("ko", "en"):
            os.remove(os.path.join(work, "docs", lang, "annex7", "2.1.3.md"))
        subprocess.run([sys.executable, os.path.join(work, "tools", "build_index.py")],
                       capture_output=True, text=True, cwd=work)

    case("a deleted criteria item is rejected even after a rebuild",
         delete_item_and_rebuild, "defines")

    print("== [18] the skill routing table ==")

    def topic_path(work):
        return os.path.join(work, "skill", "isms-p-review", "topic-index.json")

    def unroute_item(work):
        # Remove 1.1.4 from every topic and every set: the skill could never reach it.
        idx = json.loads(read(topic_path(work)))
        for topic in idx["topics"]:
            topic["items"]["별표7"] = [n for n in topic["items"]["별표7"] if n != "1.1.4"]
            for set_id in ("별표7의2", "별표7의3"):
                topic["items"][set_id] = [n for n in topic["items"][set_id] if n != "1.1.4"]
        write(topic_path(work), json.dumps(idx, ensure_ascii=False))

    case("[18] an item that no topic routes to is rejected", unroute_item, "appears in no topic")

    def phantom_item(work):
        idx = json.loads(read(topic_path(work)))
        idx["topics"][0]["items"]["별표7"].append("9.9.9")
        write(topic_path(work), json.dumps(idx, ensure_ascii=False))

    case("[18] a topic pointing at an item that does not exist is rejected", phantom_item,
         "does not exist in the corpus")

    def drift_relaxed_list(work):
        # Edit the Annex 7 list of one topic without re-deriving the relaxed lists.
        idx = json.loads(read(topic_path(work)))
        for topic in idx["topics"]:
            if "1.1.1" in topic["items"]["별표7"]:
                topic["items"]["별표7"] = [n for n in topic["items"]["별표7"] if n != "1.1.1"]
                break
        # 1.1.1 stays routable through other topics, so only the derivation fails.
        write(topic_path(work), json.dumps(idx, ensure_ascii=False))

    case("[18] a relaxed list that no longer follows the 대응(별표7) rows is rejected",
         drift_relaxed_list, "does not match the 대응(별표7) rows")

    def missing_index(work):
        os.remove(topic_path(work))

    case("[18] a missing routing table is rejected", missing_index, "topic-index.json is missing")

    print("== [9] merged relaxed items ==")

    def drop_second_source(work):
        # 별표 7의2 2.3.1 merges Annex 7 2.4.1 and 2.4.2; deleting 2.4.2's evidence bullets
        # leaves the item consistent with 2.4.1 alone, which used to pass.
        p = os.path.join(work, "docs", "ko", "annex7-2", "2.3.1.md")
        src = read(os.path.join(work, "docs", "ko", "annex7", "2.4.2.md"))
        ev = re.search(r"(?ms)^## 증적자료[^\n]*\n(.*?)(?=^## )", src).group(1)
        t = read(p)
        for line in ev.strip().split("\n"):
            if line.startswith("- "):
                t = t.replace(line + "\n", "", 1)
        write(p, t)

    case("[9] a merged relaxed item that drops its second source's material is rejected",
         drop_second_source, "borrowed '증적자료' differs")

    print("== [19] one English rendering per Korean checkpoint ==")

    def diverge_checkpoint(work):
        # 별표 7의2 2.4.2 keeps Annex 7 2.5.2's checkpoints verbatim in Korean.
        p = os.path.join(work, "docs", "en", "annex7-2", "2.4.2.md")
        t = read(p)
        t = re.sub(r"(?m)^1\. (.+)$", lambda m: "1. " + m.group(1).replace("identifier", "ID", 1), t, count=1)
        write(p, t)

    case("[19] an identical Korean checkpoint rendered differently in English is rejected",
         diverge_checkpoint, "one English rendering per Korean checkpoint")

    print("== the crash guard ==")

    def dangling_mapping(work):
        # A 대응(별표7) target that does not exist used to raise FileNotFoundError,
        # aborting the run and discarding every problem already collected.
        p = os.path.join(work, "docs", "ko", "annex7-2", "1.1.3.md")
        t = read(p)
        t = re.sub(r"\(\.\./annex7/[0-9.]+\.md\)", "(../annex7/9.9.9.md)", t)
        write(p, t)
        # plus an unrelated defect that must still be reported
        q = os.path.join(work, "docs", "ko", "annex7", "1.1.6.md")
        write(q, read(q).replace("# 1.1.6 ", "# 8.8.8 ", 1))

    with tempfile.TemporaryDirectory() as tmp:
        work = make_corpus(tmp)
        dangling_mapping(work)
        code, out = run_check(work)
        report(code == 1 and "does not exist" in out and "8.8.8" in out,
               "a dangling 대응(별표7) target reports instead of crashing, "
               "and other problems survive", out.strip()[-300:])

    print("== build_index.py determinism ==")
    with tempfile.TemporaryDirectory() as tmp:
        work = make_corpus(tmp)
        outs = []
        for _ in range(2):
            subprocess.run([sys.executable, os.path.join(work, "tools", "build_index.py")],
                           capture_output=True, text=True, cwd=work)
            snap = {}
            for base, _dirs, files in os.walk(os.path.join(work, "extended")):
                for f in sorted(files):
                    fp = os.path.join(base, f)
                    with open(fp, "rb") as fh:
                        snap[os.path.relpath(fp, work)] = fh.read()
            for lang in ("ko", "en"):
                fp = os.path.join(work, "docs", lang, "INDEX.md")
                with open(fp, "rb") as fh:
                    snap[os.path.relpath(fp, work)] = fh.read()
            outs.append(snap)
        report(outs[0] == outs[1], "two consecutive builds produce byte-identical output")

        code, _ = run_check(work)
        report(code == 0, "a freshly rebuilt corpus still passes every check")

    print()
    print(f"RESULT: {passed} passed, {failed} failed.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
