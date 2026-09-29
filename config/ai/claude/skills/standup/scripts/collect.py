#!/usr/bin/env python3
"""收集最近 N 個工作天 Miyago 在 ITRD / DevOps 範圍的工作證據（read-only）。

來源：
  1. git commits（所有 branch，author 符合 AUTHOR_RE）
  2. Claude Code session 的使用者提問（~/.claude/projects）
輸出：依日期分組的 Markdown。
"""
import argparse
import datetime as dt
import json
import os
import re
import subprocess
from collections import defaultdict
from pathlib import Path

HOME = Path.home()
GIT_ROOTS = [
    HOME / "Project/Active/ITRD",
    HOME / "Project/Active/DevOps",
    HOME / "Project/Note/itrd-knowledge-base",
    HOME / "Project/Note/sre-knowledge-base",
]
AUTHOR_RE = r"miyago"
# Claude project 目錄名是 cwd 把 / 換成 -
SESSION_RE = re.compile(r"ITRD|DevOps|itrd-knowledge-base|sre-knowledge-base", re.I)
NOISE_RE = re.compile(r"^\s*(<|\[|/|Caveat:|This session is being continued)")


def since_date(workdays: int, today: dt.date) -> dt.date:
    d, left = today, workdays
    while left > 0:
        d -= dt.timedelta(days=1)
        if d.weekday() < 5:
            left -= 1
    return d


def find_repos():
    seen = set()
    for root in GIT_ROOTS:
        if not root.exists():
            continue
        for dirpath, dirnames, _ in os.walk(root):
            depth = len(Path(dirpath).relative_to(root).parts)
            if ".git" in dirnames:
                real = os.path.realpath(dirpath)
                if real not in seen:
                    seen.add(real)
                    yield Path(dirpath)
            dirnames[:] = [
                n for n in dirnames
                if depth < 4 and not n.startswith(".") and n not in ("node_modules", "vendor")
            ]


def git_commits(since: dt.date):
    out = defaultdict(list)  # date -> [(repo, subject)]
    for repo in find_repos():
        try:
            log = subprocess.run(
                ["git", "-C", str(repo), "log", "--all", "--no-merges",
                 f"--since={since.isoformat()} 00:00", f"--author={AUTHOR_RE}",
                 "-i", "--format=%ad\t%s", "--date=short"],
                capture_output=True, text=True, timeout=20,
            ).stdout
        except subprocess.TimeoutExpired:
            continue
        name = str(repo.relative_to(HOME / "Project"))
        seen = set()
        for line in log.splitlines():
            day, _, subj = line.partition("\t")
            if (day, subj) in seen:
                continue
            seen.add((day, subj))
            out[day].append((name, subj))
    return out


def user_text(msg):
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return " ".join(p.get("text", "") for p in c if isinstance(p, dict) and p.get("type") == "text")
    return ""


def claude_sessions(since: dt.date, per_session: int):
    out = defaultdict(list)  # date -> [(project, prompt)]
    base = HOME / ".claude/projects"
    if not base.exists():
        return out
    cutoff = dt.datetime.combine(since, dt.time()).timestamp()
    for proj in base.iterdir():
        if not proj.is_dir() or not SESSION_RE.search(proj.name):
            continue
        label = re.sub(r"^-Users-[^-]+-Project-", "", proj.name)
        for f in proj.glob("*.jsonl"):
            if f.stat().st_mtime < cutoff:
                continue
            got = 0
            with f.open(errors="ignore") as fh:
                for line in fh:
                    if '"type":"user"' not in line:
                        continue
                    try:
                        rec = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if rec.get("isSidechain") or rec.get("isMeta"):
                        continue
                    text = " ".join(user_text(rec.get("message", {})).split())
                    if len(text) < 6 or NOISE_RE.match(text):
                        continue
                    ts = rec.get("timestamp", "")[:10]
                    if not ts or ts < since.isoformat():
                        continue
                    out[ts].append((label, text[:160]))
                    got += 1
                    if got >= per_session:
                        break
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=3, help="回溯幾個工作天（預設 3）")
    ap.add_argument("--per-session", type=int, default=2, help="每個 session 取幾則提問")
    ap.add_argument("--no-sessions", action="store_true")
    a = ap.parse_args()

    today = dt.date.today()
    since = since_date(a.days, today)
    commits = git_commits(since)
    sessions = {} if a.no_sessions else claude_sessions(since, a.per_session)

    print(f"# Standup evidence  {since} ~ {today}（{a.days} 個工作天）\n")
    days = sorted(set(commits) | set(sessions), reverse=True)
    if not days:
        print("not enough data：這段期間沒有 commit 或 session 紀錄。")
        return
    for day in days:
        wd = "一二三四五六日"[dt.date.fromisoformat(day).weekday()]
        print(f"## {day}（{wd}）")
        if commits.get(day):
            print("### commits")
            for repo, subj in sorted(commits[day]):
                print(f"- `{repo}` {subj}")
        if sessions.get(day):
            print("### claude sessions")
            for proj, text in sorted(set(sessions[day])):
                print(f"- `{proj}` {text}")
        print()


if __name__ == "__main__":
    main()
