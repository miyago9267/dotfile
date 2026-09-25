#!/usr/bin/env python3
"""Stop hook：有 /goal 時，禁止用白話問句把下一步丟回給 Miyago。

/goal 生效期間，最後一則回覆若以「下一步：告訴我…」「要不要…？」這類交棒句結尾，
要求模型三選一：可逆的 agent-owned 步驟直接做；真正的決策改用 AskUserQuestion 給選項；
有具名外部 blocker 就用「阻塞：」開頭寫清楚再停。
只在 goal 生效時作用；re-entry、解析失敗一律放行（fail open）。
"""
import json
import re
import sys

TAIL_CHARS = 240

HANDOFF = re.compile(
    r"下一步[:：]|要不要|要我|需要你|由你決定|你決定|你要|你想|回我|告訴我|回「|"
    r"是否要|請確認|確認一下|還是要|等你|want me to|should i|shall i|let me know|"
    r"[?？]\s*$",
    re.I,
)
BLOCKED = re.compile(r"(^|\n)\s*\**阻塞[:：]")
GOAL_CMD = re.compile(r"<command-name>/goal</command-name>.*?<command-args>(.*?)</command-args>", re.S)


def active_goal(transcript_path: str) -> str | None:
    """從 transcript 找最後一次 /goal 設定，met 或 clear 之後視為沒有 goal。"""
    goal = None
    try:
        with open(transcript_path, encoding="utf-8") as fh:
            for line in fh:
                if "goal" not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                att = entry.get("attachment") or {}
                if att.get("type") == "goal_status":
                    goal = None if att.get("met") else att.get("condition") or goal
                    continue
                msg = entry.get("message") or {}
                content = msg.get("content") if isinstance(msg, dict) else None
                if entry.get("type") == "user" and isinstance(content, str):
                    m = GOAL_CMD.search(content)
                    if m:
                        args = m.group(1).strip()
                        goal = None if args in ("", "clear") else args
    except OSError:
        return None
    return goal


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    if payload.get("stop_hook_active"):
        return
    text = (payload.get("last_assistant_message") or "").strip()
    if not text or BLOCKED.search(text):
        return
    goal = active_goal(payload.get("transcript_path") or "")
    if not goal:
        return
    if not HANDOFF.search(text[-TAIL_CHARS:]):
        return
    # exit 2 + stderr 才確定會送到模型（stingray 在 2.1.278 實測）
    sys.stderr.write(
        (
            f"/goal 還在生效（{goal}），上一則回覆用問句把下一步丟回給 Miyago。擇一處理，不要解釋這條提醒：\n"
            "1. 下一步是 in-scope、可逆、你自己能做的 → 現在就做，做到 goal 達成或真的卡住。\n"
            "2. 需要 Miyago 決定（產品意圖、權限、破壞性、外部或花錢）→ 呼叫 AskUserQuestion，"
            "給 2-4 個選項，推薦的放第一個並標 (Recommended)，不要用白話問句。\n"
            "3. 有具名外部 blocker → 一行「阻塞：<確切缺口>」後停止。"
        )
        + "\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
