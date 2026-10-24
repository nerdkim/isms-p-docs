#!/usr/bin/env bash
# docs-stop-hook.sh - Claude Code Stop hook: ask once for the documents a change needs (D49, D65).
#
# D49 ends work only when README and the related documents match the change. Which document has to
# change is a judgement no script can make, so this hook judges no document. It notices one thing:
# the turn that is ending changed files other than documents and touched no document. It then keeps
# the session going once with a reminder to update the documents that describe the change, or to
# name the documents checked in the final report (docs/16 s5.3 of the playbook).
#
# The turn's changes are
#   - the files edited with Edit, Write, MultiEdit or NotebookEdit since the last prompt the user
#     typed, read from the session transcript, leaving out an edit whose result was an error, and
#   - the files of commits on local branches whose committer date is after that prompt.
# Only paths inside the project directory count. A document is a Markdown, MDX, reStructuredText or
# AsciiDoc file, or any file under a docs/ directory. CLAUDE.md, AGENTS.md, CLAUDE.local.md and
# everything under .claude/ or .korean-style/ are agent configuration: neither a change nor a
# document here. Edits made only through a shell or by a subagent and left uncommitted are not seen,
# so this is local feedback, not a gate.
#
# Safety valves, as in the playbook's own Stop hook: a stop that re-enters from a Stop hook
# (stop_hook_active) passes, so the reminder never comes twice in a row, and a missing python3,
# unreadable input or an unreadable transcript passes too, so the hook never traps a session.
#
# harness/install.sh adds it to .claude/settings.json (.claude/settings.local.json in a public
# repository) as: bash "$CLAUDE_PROJECT_DIR/harness/docs-stop-hook.sh"
# Exit 0: nothing to say. Exit 2: the reminder on stderr, which Claude Code hands back to Claude.
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0
root="${CLAUDE_PROJECT_DIR:-$PWD}"
input="$(cat 2>/dev/null || true)"

printf '%s' "$input" | python3 -c '
import json
import subprocess
import sys
from pathlib import Path, PurePosixPath

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
DOC_SUFFIXES = {".md", ".mdx", ".markdown", ".rst", ".adoc"}
AGENT_NAMES = {"CLAUDE.md", "AGENTS.md", "CLAUDE.local.md"}
AGENT_DIRS = {".claude", ".korean-style"}
SHOWN = 5
MESSAGE = (
    "[docs-stop-hook] 이번 요청에서 문서가 아닌 파일을 바꿨는데 문서는 고치지 않았습니다(D49). 바꾼 파일: {files}\n"
    "바뀐 명령, 설정, 구조, 동작, 사용법이 적힌 README.md, docs/, GUIDE.md, INSTALL.md, CHANGELOG.md를 찾아 고쳐 주십시오. "
    "아직 commit하지 않았으면 같은 commit에, 이미 commit했으면 바로 다음 commit에 넣어 주십시오. "
    "고칠 문서가 없으면 확인한 문서와 고칠 것이 없는 이유를 최종 보고에 적고 마쳐 주십시오(playbook docs/16 5.3절)."
)


def rows_of(path):
    rows = []
    with open(path, encoding="utf-8") as stream:
        for line in stream:
            try:
                row = json.loads(line)
            except ValueError:
                continue
            if isinstance(row, dict):
                rows.append(row)
    return rows


def parts_of(row):
    content = (row.get("message") or {}).get("content")
    if isinstance(content, str):
        return [{"type": "text", "text": content}]
    if isinstance(content, list):
        return [part for part in content if isinstance(part, dict)]
    return []


def typed_prompt(row):
    """A prompt the user typed: no tool result, and not a message Claude Code added itself."""
    if row.get("type") != "user" or row.get("isMeta") or row.get("isSidechain"):
        return False
    parts = parts_of(row)
    return bool(parts) and not any(part.get("type") == "tool_result" for part in parts)


def last_prompt(rows):
    for index in range(len(rows) - 1, -1, -1):
        if typed_prompt(rows[index]):
            stamp = rows[index].get("timestamp")
            return index, stamp if isinstance(stamp, str) else ""
    return None, ""


def edited(rows, start):
    # An edit a hook or the tool refused (an error result) changed nothing.
    refused = {part.get("tool_use_id") for row in rows[start + 1:] if row.get("type") == "user"
               for part in parts_of(row) if part.get("type") == "tool_result" and part.get("is_error") is True}
    names = []
    for row in rows[start + 1:]:
        if row.get("type") != "assistant" or row.get("isSidechain"):
            continue
        for part in parts_of(row):
            if part.get("type") == "tool_use" and part.get("name") in EDIT_TOOLS and part.get("id") not in refused:
                args = part.get("input") if isinstance(part.get("input"), dict) else {}
                name = args.get("file_path") or args.get("notebook_path")
                if isinstance(name, str) and name:
                    names.append(name)
    return names


def committed(root, stamp):
    if not stamp:
        return []
    git = ["git", "-c", "core.quotePath=false", "-C", str(root)]
    try:
        top = subprocess.run(git + ["rev-parse", "--show-toplevel"], capture_output=True, text=True, timeout=10)
        if top.returncode != 0:
            return []
        log = subprocess.run(git + ["log", "--branches", "--no-merges", "--since=" + stamp, "--format=", "--name-only"],
                             capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return []
    if log.returncode != 0:
        return []
    base = Path(top.stdout.strip())
    return [str(base / line) for line in log.stdout.splitlines() if line.strip()]


def inside(root, name):
    path = Path(name)
    if not path.is_absolute():
        path = root / path
    try:
        return path.resolve().relative_to(root).as_posix()
    except (OSError, ValueError):
        return None


def agent_config(rel):
    parts = PurePosixPath(rel).parts
    return parts[-1] in AGENT_NAMES or any(part in AGENT_DIRS for part in parts[:-1])


def document(rel):
    path = PurePosixPath(rel)
    return "docs" in path.parts[:-1] or path.suffix.lower() in DOC_SUFFIXES


def main():
    root = Path(sys.argv[1]).resolve()
    data = json.loads(sys.stdin.read() or "{}")
    if not isinstance(data, dict) or data.get("stop_hook_active") is True:
        return 0
    transcript = data.get("transcript_path")
    if not isinstance(transcript, str) or not transcript:
        return 0
    rows = rows_of(transcript)
    start, stamp = last_prompt(rows)
    if start is None:
        return 0
    changed = set()
    for name in edited(rows, start) + committed(root, stamp):
        rel = inside(root, name)
        if rel and not agent_config(rel):
            changed.add(rel)
    if not changed or any(document(rel) for rel in changed):
        return 0
    names = sorted(changed)
    files = ", ".join(names[:SHOWN])
    if len(names) > SHOWN:
        files += " 외 {}개".format(len(names) - SHOWN)
    print(MESSAGE.format(files=files), file=sys.stderr)
    return 2


try:
    sys.exit(main())
except Exception:
    sys.exit(0)
' "$root"
status=$?
[ "$status" -eq 2 ] && exit 2
exit 0
