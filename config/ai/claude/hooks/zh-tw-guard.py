#!/usr/bin/env python3
"""Stop hook：最後一則回覆若出現簡體中文、英文段落或日文段落，要求用台灣繁體中文重講。
也掛在 SubagentStop 上；subagent 回報只查簡體字。
也掛在 PostToolUse 上：回合中間的說明若用了英文、日文或簡體，不擋，只注入提醒。

只看 prose：code fence、inline code、URL、block quote 與「」內的短引用不計；
逐段（空行分隔）判斷，以 | 開頭的表格行不算。
任何錯誤一律放行（fail open），re-entry 時不再攔。
"""
import json
import os
import re
import sys

# 只收簡體專用字；排除在繁體中也合法的字（如 后、里、于、并、干）。
SIMPLIFIED = set(
    "这们说为进时会过来还对发动开关没问题实现现话让给门间应该经项击处设计无数据库"
    "环杂备东头业务号码写读错个从么样请试测览执统证获载线网络页档录变输选择参权"
)
MIN_HITS = 3
CJK = re.compile(r"[一-鿿]")
# 獨立英文單字；路徑、檔名、identifier、hash 不計。
WORD = re.compile(r"(?<![\w/.\-])[A-Za-z]{2,}(?![\w/\-]|\.\w)")
MIN_EN_WORDS = 8
KANA = re.compile(r"[\u3040-\u30fa\u30fd-\u30ff]")
FURIGANA = re.compile(r"（[\u3040-\u30ff]+）")
MIN_KANA = 8
MIN_KANA_SHARE = 0.5  # kana / (kana + 漢字)；中文說明夾日文例句時 kana 佔比低
BLANK = re.compile(r"（\s*[A-Za-z0-9]?\s*）")  # 填空練習題
# 中文專用字；日文新字體也會用的字不放。
ZH_ONLY = set("這們嗎呢吧啦喔說會沒對麼來斷個為與從還讓給題你妳您他她請樣點檔裡")
TAIL_BYTES = 256 * 1024

STRIP = [
    re.compile(r"```.*?```", re.S),
    re.compile(r"`[^`\n]*`"),
    re.compile(r"\[[^\]\n]*\]\([^)\n]*\)"),
    re.compile(r"https?://\S+"),
    re.compile(r"^\s*>.*$", re.M),
    re.compile(r"「[^」\n]{0,40}」"),
]


def last_text(payload: dict) -> str:
    text = payload.get("last_assistant_message")
    if text:
        return text
    path = payload.get("agent_transcript_path")
    if not path:
        return ""
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as f:
            lines = f.readlines()
        for line in reversed(lines):
            rec = json.loads(line)
            msg = rec.get("message") if isinstance(rec.get("message"), dict) else rec
            if msg.get("role") != "assistant" and rec.get("type") != "assistant":
                continue
            content = msg.get("content")
            if isinstance(content, str) and content:
                return content
            if isinstance(content, list):
                parts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
                if any(parts):
                    return "\n".join(parts)
    except Exception:
        return ""
    return ""


def clean(text: str) -> str:
    for pattern in STRIP:
        text = pattern.sub("", text)
    return text


def paragraphs(text: str) -> list:
    out = []
    for para in re.split(r"\n\s*\n", clean(text)):
        lines = [ln for ln in para.splitlines() if not ln.lstrip().startswith("|")]
        para = "\n".join(lines).strip()
        if para:
            out.append(para)
    return out


def is_english(para: str) -> bool:
    return not CJK.search(para) and len(WORD.findall(para)) >= MIN_EN_WORDS


def is_japanese(para: str) -> bool:
    kana = len(KANA.findall(para))
    return (
        kana >= MIN_KANA
        and kana >= MIN_KANA_SHARE * (kana + len(CJK.findall(para)))
        and not FURIGANA.search(para)
        and not BLANK.search(para)
        and not any(ch in ZH_ONLY for ch in para)
    )


def snippet(para: str) -> str:
    return re.sub(r"\s+", " ", para)[:30]


def find_problem(text: str, check_lang: bool = True):
    """回傳 (問題描述, 違規段落前 30 字)；沒問題回傳 None。"""
    paras = paragraphs(text)
    hits = [ch for p in paras for ch in p if ch in SIMPLIFIED]
    if len(hits) >= MIN_HITS:
        first = next(p for p in paras if any(ch in SIMPLIFIED for ch in p))
        return f"出現簡體字（{''.join(dict.fromkeys(hits))[:10]}）", snippet(first)
    if not check_lang:
        return None
    for p in paras:
        if is_english(p):
            return "有英文段落", snippet(p)
        if is_japanese(p):
            return "有日文段落", snippet(p)
    whole = "\n".join(paras)
    if not CJK.search(whole) and len(WORD.findall(whole)) >= MIN_EN_WORDS:
        return "整則是英文", snippet(whole)
    return None


def tail_records(path: str) -> list:
    with open(os.path.expanduser(path), "rb") as f:
        size = f.seek(0, os.SEEK_END)
        start = max(0, size - TAIL_BYTES)
        f.seek(start)
        raw = f.read().decode("utf-8", errors="ignore")
    lines = raw.splitlines()
    if start > 0 and lines:
        lines = lines[1:]
    recs = []
    for line in lines:
        try:
            recs.append(json.loads(line))
        except Exception:
            continue
    return recs


def post_tool_use(payload: dict) -> None:
    tid = payload.get("tool_use_id")
    path = payload.get("transcript_path")
    if not tid or not path:
        return
    recs = [r for r in tail_records(path) if isinstance(r, dict) and isinstance(r.get("message"), dict)
            and r["message"].get("role") == "assistant" and isinstance(r["message"].get("content"), list)]
    mid = None
    for r in recs:
        if any(isinstance(b, dict) and b.get("type") == "tool_use" and b.get("id") == tid for b in r["message"]["content"]):
            mid = r["message"].get("id")
            same = [r]
            break
    else:
        return
    if mid:
        same = [r for r in recs if r["message"].get("id") == mid]
    blocks = [b for r in same for b in r["message"]["content"] if isinstance(b, dict)]
    uses = [b for b in blocks if b.get("type") == "tool_use"]
    if not uses or uses[0].get("id") != tid:
        return
    for b in blocks:
        if b.get("type") == "text":
            found = find_problem(b.get("text") or "")
            if found:
                problem = found[0].replace("有", "用了").replace("整則是", "用了")
                print(json.dumps({"hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": f"剛才那段說明{problem}，接下來的說明改用台灣繁體中文。",
                }}, ensure_ascii=False))
                return


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    if payload.get("hook_event_name") == "PostToolUse":
        try:
            post_tool_use(payload)
        except Exception:
            pass
        return
    if payload.get("stop_hook_active"):
        return
    found = find_problem(last_text(payload), payload.get("hook_event_name") != "SubagentStop")
    if not found:
        return
    problem, quote = found
    print(json.dumps({
        "decision": "block",
        "reason": (
            f"上一則回覆{problem}，違規段落開頭：「{quote}」。"
            "請把整則回覆完整用台灣繁體中文重講，內容與結論不變，code、指令與 identifiers 保持原樣；"
            "若是刻意引用的外文原文，請放進 code fence 或 `>` 引用。"
        ),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
