---
name: handoff
description: 將當前 session 完整狀態輸出為 handoff，讓下一個 session 零解釋繼承
command: /handoff
---

# Handoff — 跨 Session Context 傳遞

## 原則

Handoff 必須讓下一個 AI 不需要問任何問題就能繼續工作。
做法：自動收集客觀狀態，AI 只補充「原因」和「下一步」。

## 步驟 1：自動收集狀態（用 Bash 執行）

```bash
echo "=== CWD ===" && pwd
echo "=== GIT STATUS ===" && git status --short 2>/dev/null || echo "not a git repo"
echo "=== RECENT COMMITS ===" && git log --oneline -5 2>/dev/null || echo ""
echo "=== MODIFIED FILES (full diff stat) ===" && git diff HEAD --stat 2>/dev/null || echo ""
echo "=== UNSTAGED ===" && git diff --name-only 2>/dev/null || echo ""
echo "=== STAGED ===" && git diff --cached --name-only 2>/dev/null || echo ""
echo "=== ACTIVE SPECS ===" && find docs/specs .ai/specs -name "*.md" 2>/dev/null | head -10 || echo "no specs dir"
```

## 步驟 2：寫入 `.ai/HANDOFF.md`

格式如下，每個區塊都必須填，不能空著：

```markdown
# Handoff: {專案名稱}

**From:** {絕對路徑}
**Date:** {YYYY-MM-DD HH:MM}
**Branch:** {git branch 或 N/A}

---

## 任務背景（30 字內）

{正在做什麼，為什麼做}

## 目前狀態

**完成的：**

- {具體的，帶檔案路徑}

**未完成的：**

- {具體的，帶預計要動的檔案}

**卡住的（若有）：**

- {問題描述 + 嘗試過的方法}

---

## 接手後的第一件事

> {一句話，告訴下一個 AI 第一步做什麼。要具體，例如：「讀 src/api/users.ts 第 42 行的 TODO，然後實作 validateUser()」}

## 需要先讀的檔案（依順序）

1. {最重要的檔案路徑} — {一句話說為什麼}
2. {次要檔案} — {原因}
3. ...

## 相關 Spec

- {spec 路徑} — {當前 phase/進度}

---

## 決策記錄（本 session 做的選擇）

- {決策內容} — {原因，不要重問}

## 已知地雷

- {任何接手者踩到會浪費時間的問題}

---

## Git 狀態快照

**Modified files:**
{貼上步驟 1 的 git status 輸出}
```

## 步驟 3：確認輸出

```text
Handoff 已寫入 .ai/HANDOFF.md
接手方式：在新 session 執行 /pickup
```
