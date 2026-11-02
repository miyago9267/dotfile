#!/usr/bin/env python3
"""Stop hook：最後一則回覆若出現簡體中文，或整則幾乎只有英文，要求用台灣繁體中文重講。

只看 prose：code fence、inline code、URL、block quote 與「」內的短引用不計。
任何錯誤一律放行（fail open），re-entry 時不再攔。
"""
import json
import re
import sys

# 只收簡體專用字；排除在繁體中也合法的字（如 后、里、于、并、干）。
SIMPLIFIED = set(
    "这们说为进时会过来还对发动开关没问题实现现话让给门间应该经项击处设计无数据库"
    "环杂备东头业务号码写读错个从么样请试测览执统证获载线网络页档录变输选择参权"
)
MIN_HITS = 3
CJK = re.compile(r"[一-鿿]")
WORD = re.compile(r"[A-Za-z]{2,}")
MIN_EN_WORDS = 8

STRIP = [
    re.compile(r"```.*?```", re.S),
    re.compile(r"`[^`\n]*`"),
    re.compile(r"https?://\S+"),
    re.compile(r"^\s*>.*$", re.M),
    re.compile(r"「[^」\n]{0,40}」"),
]


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    if payload.get("stop_hook_active"):
        return
    text = payload.get("last_assistant_message") or ""
    for pattern in STRIP:
        text = pattern.sub("", text)
    hits = [ch for ch in text if ch in SIMPLIFIED]
    if len(hits) >= MIN_HITS:
        sample = "".join(dict.fromkeys(hits))[:10]
        problem = f"出現簡體字（{sample}）"
    elif not CJK.search(text) and len(WORD.findall(text)) >= MIN_EN_WORDS:
        problem = "整則是英文"
    else:
        return
    print(json.dumps({
        "decision": "block",
        "reason": (
            f"上一則回覆{problem}。請把同一則回覆完整改寫成台灣繁體中文，"
            "內容與結論不變，code、指令與 identifiers 保持原樣。"
        ),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
