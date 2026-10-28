#!/usr/bin/env bash
# ui-design-hook.sh - Claude Code PreToolUse hook: screen work starts from ui-ux-pro-max and the web
# standard (D73).
#
# D61 asked every session to call the design skills before building or reshaping a screen, and an
# instruction alone was skipped: in the week after it, sessions edited thousands of .tsx and .css
# lines and called ui-ux-pro-max a handful of times, and web apps drifted into hex colors and pixel
# values the daisyUI tokens exist to replace. So this hook asks at the moment it matters. When Claude
# is about to Write, Edit or MultiEdit a screen file and has not called the ui-ux-pro-max skill since
# the last prompt the user typed, the call is refused once with what to do: call the skill, then
# build with the docs/09 s7 standard (daisyUI components and semantic tokens, the palette moved into
# the `@plugin "daisyui/theme"` override, Pretendard, Tailwind's default scale).
#
# A screen file is a .tsx, .jsx or .css file under apps/web/src, apps/desktop/src or apps/mobile/src,
# other than a test or story. A typed prompt is a user message that is not a tool result, not text
# Claude Code adds itself (isMeta, sidechain) and not a background task notification.
#
# Safety valves, as in harness/docs-stop-hook.sh: the refusal comes once per prompt, so a wording fix
# or a small bug fix goes through on the retry; a PC without the plugin (no ui-ux-pro-max entry in
# ~/.claude/plugins/installed_plugins.json) is not asked for it; and a missing python3, unreadable
# input or an unreadable transcript lets the call through, so the hook never traps a session. It is
# local feedback, not a gate.
#
# harness/install.sh adds it to .claude/settings.json (.claude/settings.local.json in a public
# repository) as a PreToolUse hook for Write|Edit|MultiEdit:
#   bash "$CLAUDE_PROJECT_DIR/harness/ui-design-hook.sh"
# Exit 0 always; a refusal is the JSON decision on stdout.
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0
root="${CLAUDE_PROJECT_DIR:-$PWD}"
plugins="${UI_DESIGN_HOOK_PLUGINS:-$HOME/.claude/plugins/installed_plugins.json}"
input="$(cat 2>/dev/null || true)"

printf '%s' "$input" | python3 -c '
import json
import re
import sys
from pathlib import Path

EDIT_TOOLS = {"Write", "Edit", "MultiEdit"}
SCREEN = re.compile(r"^apps/(web|desktop|mobile)/src/.+\.(tsx|jsx|css)$")
NOT_SCREEN = re.compile(r"\.(test|spec|stories)\.[a-z]+$")
SKILL = re.compile(r"^(ui-ux-pro-max:)?ui-ux-pro-max$")
MARK = "[ui-design-hook]"
MESSAGE = (
    MARK + " 이번 요청에서 ui-ux-pro-max skill을 부르지 않은 채 화면 파일({file})을 고치려 합니다(D73). "
    "화면이나 component를 새로 만들거나 구성, 색, 글꼴, 상호작용을 크게 바꾸는 작업이면 먼저 Skill 도구로 ui-ux-pro-max:ui-ux-pro-max를 부르고, "
    "`--stack react`와 `--domain ux`로 접근성, form, 반응형, 상호작용 기준을 찾아 주십시오. "
    "구현은 playbook docs/09 7절 표준으로 합니다. daisyUI component class를 먼저 쓰고, 색은 daisyUI semantic token으로만 씁니다. "
    "skill이 낸 palette는 src/index.css의 @plugin \"daisyui/theme\" override 한 곳에 token으로 옮기고, component에 hex 색이나 임의 px 값을 적지 않습니다. "
    "글꼴은 Pretendard, 간격과 글자 크기는 Tailwind 기본 scale입니다. skill이 shadcn/ui 같은 다른 UI library나 Google Fonts를 권해도 이 표준으로 옮깁니다. "
    "문구 수정이나 작은 bug 수정이면 같은 수정을 다시 실행해 주십시오."
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


def text_of(part):
    content = part.get("content") if part.get("type") == "tool_result" else part.get("text")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(item.get("text", "") for item in content if isinstance(item, dict) and isinstance(item.get("text"), str))
    return ""


def typed_prompt(row):
    if row.get("type") != "user" or row.get("isMeta") or row.get("isSidechain"):
        return False
    parts = parts_of(row)
    if not parts or any(part.get("type") == "tool_result" for part in parts):
        return False
    return not " ".join(text_of(part) for part in parts).lstrip().startswith("<task-notification>")


def plugin_installed(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return False
    plugins = data.get("plugins") if isinstance(data, dict) else None
    return isinstance(plugins, dict) and any(str(name).startswith("ui-ux-pro-max@") for name in plugins)


def main():
    root, plugins = Path(sys.argv[1]).resolve(), sys.argv[2]
    data = json.loads(sys.stdin.read() or "{}")
    if not isinstance(data, dict) or data.get("tool_name") not in EDIT_TOOLS:
        return 0
    args = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
    name = args.get("file_path")
    if not isinstance(name, str) or not name:
        return 0
    path = Path(name)
    if not path.is_absolute():
        path = root / path
    try:
        rel = path.resolve().relative_to(root).as_posix()
    except (OSError, ValueError):
        return 0
    if not SCREEN.match(rel) or NOT_SCREEN.search(rel) or not plugin_installed(plugins):
        return 0
    transcript = data.get("transcript_path")
    if not isinstance(transcript, str) or not transcript:
        return 0
    rows = rows_of(transcript)
    start = next((i for i in range(len(rows) - 1, -1, -1) if typed_prompt(rows[i])), None)
    if start is None:
        return 0
    for row in rows[start + 1:]:
        for part in parts_of(row):
            if row.get("type") == "assistant" and part.get("type") == "tool_use" and part.get("name") == "Skill":
                skill = (part.get("input") or {}).get("skill") if isinstance(part.get("input"), dict) else None
                if isinstance(skill, str) and SKILL.match(skill.strip().lstrip("/")):
                    return 0
            if row.get("type") == "user" and part.get("type") == "tool_result" and MARK in text_of(part):
                return 0
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                             "permissionDecisionReason": MESSAGE.format(file=rel)}}, ensure_ascii=False))
    return 0


try:
    sys.exit(main())
except Exception:
    sys.exit(0)
' "$root" "$plugins"
exit 0
