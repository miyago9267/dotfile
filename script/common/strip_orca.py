#!/usr/bin/env python3
"""git clean filter：從 JSON config 移除 Orca 注入的 hook 與 plugin。

Orca 會直接改寫 symlink 到 dotfile 的 config；本 filter 讓 commit 只保留可攜內容，
working copy 仍保留 Orca 設定。輸入不是 JSON 時原樣輸出。
用法：python3 strip_orca.py < file > cleaned
"""
import json
import re
import sys

ORCA = re.compile(r"\.orca/|ORCA_|orca-opencode-status")
DROP = object()


def is_orca(value):
    if isinstance(value, str):
        return bool(ORCA.search(value))
    return isinstance(value, dict) and isinstance(value.get("command"), str) and bool(ORCA.search(value["command"]))


def clean(value):
    if isinstance(value, list):
        out = []
        for item in value:
            if is_orca(item):
                continue
            item = clean(item)
            if item is not DROP:
                out.append(item)
        return DROP if value and not out else out
    if isinstance(value, dict):
        out = {}
        for key, item in value.items():
            item = clean(item)
            if item is DROP:
                if key == "hooks":
                    return DROP
                continue
            out[key] = item
        return DROP if value and not out else out
    return value


def main():
    text = sys.stdin.read()
    try:
        data = json.loads(text)
    except ValueError:
        sys.stdout.write(text)
        return
    data = clean(data)
    sys.stdout.write(json.dumps({} if data is DROP else data, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
