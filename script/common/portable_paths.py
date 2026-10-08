#!/usr/bin/env python3
"""版控內容不寫死機器路徑（docs/specs/portable-paths）。

  --check [--staged]  掃 tracked 檔案與 symlink；有 /Users/<name>、/home/<name>、
                      C:\\Users\\<name> 或絕對目標的 symlink 就 exit 1。
                      --staged 只看 index 裡這次要 commit 的內容（pre-commit 用）。
  --fix               把 FIX_FILES 裡 hook command 的 home 前綴改回可攜形式。
                      herdr、orca、shoal 這類 installer 會回寫絕對路徑，setup 與
                      auto-update 之後跑一次；重跑結果不變。

可攜形式：word 開頭用 ~，雙引號內用 $HOME，單引號改成雙引號再用 $HOME。
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

# 前面不能是 word 字元、$ 或 }：$WORK/home/x、/some/not/home/dir 是路徑片段，不是 home。
HOME_RE = re.compile(
    r"(?<![\w$}])(?:(?:/Users|/home)/(?!linuxbrew\b)[A-Za-z0-9._-]+|[A-Za-z]:\\{1,2}Users\\{1,2}[A-Za-z0-9._-]+)"
)

# --fix 只改這些檔案裡 key 為 "command" 的字串，其他欄位不動。
FIX_FILES = (
    "config/ai/claude/settings.json",
    "config/ai/gemini/hooks.json",
)

# 不檢查的路徑（fnmatch，* 可跨目錄）。每一條都要有理由。
EXEMPT = (
    # 歷史紀錄與備份，不是執行期設定
    "docs/*",
    "work/*",
    "*.before-*",
    "config/ai/memories/extensions/*",
    # 只在單一平台使用的 app 設定
    "config/warp/*",
    "config/windows-terminal/*",
    "config/vscode/*",
    # 專案層 local 權限，內容是各機器核准過的指令
    ".claude/settings.local.json",
    # agy 的 allow/deny 規則：還沒確認 agy 是否展開 ~，deny 規則改壞會靜默失效
    "config/ai/gemini/antigravity-cli/settings.json",
    # 測試 fixture 與第三方產生的檔案：裡面的路徑是假資料或範例
    "*/tests/*",
    "*/test/*",
    "config/zsh/.p10k.zsh",
    # 這支工具與它的測試本身要寫出範例路徑
    "script/common/portable_paths.py",
    "script/common/test_portable_paths.py",
)

SAFE_IN_DQUOTE = re.compile(r"^[^$`\"\\]*$")


def is_exempt(path: str) -> bool:
    return any(fnmatch.fnmatch(path, pat) for pat in EXEMPT)


def portable_command(cmd: str) -> str:
    """把 shell command 裡的 home 前綴改成 ~ 或 $HOME，依所在的引號狀態決定寫法。"""
    out: list[str] = []
    i, n = 0, len(cmd)
    in_dq = False
    while i < n:
        ch = cmd[i]
        if in_dq:
            m = HOME_RE.match(cmd, i)
            if m:
                out.append("$HOME")
                i = m.end()
                continue
            if ch == "\\" and i + 1 < n:
                out.append(cmd[i : i + 2])
                i += 2
                continue
            if ch == '"':
                in_dq = False
            out.append(ch)
            i += 1
            continue
        if ch == "'":
            end = cmd.find("'", i + 1)
            if end == -1:
                out.append(cmd[i:])
                break
            body = cmd[i + 1 : end]
            if HOME_RE.search(body) and SAFE_IN_DQUOTE.match(body):
                out.append('"' + HOME_RE.sub(lambda _: "$HOME", body) + '"')
            else:
                out.append(cmd[i : end + 1])
            i = end + 1
            continue
        if ch == '"':
            in_dq = True
            out.append(ch)
            i += 1
            continue
        if ch == "\\" and i + 1 < n:
            out.append(cmd[i : i + 2])
            i += 2
            continue
        m = HOME_RE.match(cmd, i)
        if m:
            prev = cmd[i - 1] if i else " "
            nxt = cmd[m.end()] if m.end() < n else " "
            # ~ 只在 word 開頭（或 VAR= 之後）且後面接 / 或結束時才會展開
            tilde_ok = (prev.isspace() or prev in "=;&|(") and (nxt == "/" or nxt.isspace() or nxt in ";&|)")
            out.append("~" if tilde_ok else "$HOME")
            i = m.end()
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _rewrite_commands(node):
    """回傳 (新節點, 是否有變更)；只碰 dict 裡 key 為 command 的字串。"""
    changed = False
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "command" and isinstance(value, str):
                new = portable_command(value)
                if new != value:
                    node[key] = new
                    changed = True
            else:
                _, sub = _rewrite_commands(value)
                changed = changed or sub
    elif isinstance(node, list):
        for item in node:
            _, sub = _rewrite_commands(item)
            changed = changed or sub
    return node, changed


def fix_file(path: Path) -> bool:
    """改寫一個 JSON 檔；symlink 會寫進它指向的檔案。回傳是否有變更。"""
    target = path.resolve()
    text = target.read_text(encoding="utf-8")
    data = json.loads(text)
    _, changed = _rewrite_commands(data)
    if not changed:
        return False
    indent = 2
    m = re.search(r"\n( +)\S", text)
    if m:
        indent = len(m.group(1))
    target.write_text(json.dumps(data, indent=indent, ensure_ascii=False) + "\n", encoding="utf-8")
    return True


def _git(root: Path, *args: str) -> bytes:
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True).stdout


def _entries(root: Path, staged: bool) -> list[tuple[str, str]]:
    """回傳 [(mode, path)]。staged 時只列這次 commit 會新增或修改的檔案。"""
    listing = _git(root, "ls-files", "-s", "-z").decode("utf-8", "surrogateescape")
    modes = {}
    for rec in listing.split("\0"):
        if rec:
            meta, path = rec.split("\t", 1)
            modes[path] = meta.split()[0]
    if not staged:
        return [(mode, path) for path, mode in modes.items()]
    names = _git(root, "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR").decode("utf-8", "surrogateescape")
    return [(modes[p], p) for p in names.split("\0") if p and p in modes]


def check(root: Path, staged: bool) -> list[str]:
    problems: list[str] = []
    for mode, path in _entries(root, staged):
        if is_exempt(path):
            continue
        full = root / path
        if mode == "120000":
            if staged:
                target = _git(root, "show", f":{path}").decode("utf-8", "replace")
            elif full.is_symlink():
                target = str(full.readlink())
            else:
                continue
            if target.startswith("/") or re.match(r"[A-Za-z]:[\\/]", target):
                problems.append(f"{path}: symlink 指向絕對路徑 {target}")
            continue
        if mode == "160000":
            continue
        try:
            blob = _git(root, "show", f":{path}") if staged else full.read_bytes()
        except (OSError, subprocess.CalledProcessError):
            continue
        if b"\0" in blob[:8192]:
            continue
        for lineno, line in enumerate(blob.decode("utf-8", "replace").splitlines(), 1):
            m = HOME_RE.search(line)
            if m:
                problems.append(f"{path}:{lineno}: {m.group(0)}")
    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="檢查或修正版控內容裡寫死的 home 路徑。")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true", help="有違規就 exit 1")
    group.add_argument("--fix", action="store_true", help="把 hook command 改回可攜形式")
    parser.add_argument("--staged", action="store_true", help="--check 只看 index 裡這次 commit 的內容")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args(argv)

    if args.fix:
        for rel in FIX_FILES:
            path = args.root / rel
            if not path.exists():
                continue
            print(f"[{'FIX' if fix_file(path) else 'OK'}] {rel}")
        return 0

    problems = check(args.root, args.staged)
    if not problems:
        return 0
    shown = problems[:40]
    print("[portable-paths] 版控內容裡有寫死的機器路徑：", file=sys.stderr)
    for line in shown:
        print(f"  {line}", file=sys.stderr)
    if len(problems) > len(shown):
        print(f"  ... 另有 {len(problems) - len(shown)} 處", file=sys.stderr)
    print(
        "  hook command 可用 python3 script/common/portable_paths.py --fix 修正；\n"
        "  其他請改成 ~、$HOME 或相對路徑。說明見 docs/specs/portable-paths/SPEC.md。",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
