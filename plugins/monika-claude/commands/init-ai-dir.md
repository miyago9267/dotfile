---
name: init-ai-dir
description: 在當前專案初始化 .ai/ canonical 目錄，並生成各 LLM 的入口檔案
command: /init-ai-dir
---

# Init AI Dir

在當前專案目錄執行以下動作：

## 步驟 1：建立 `.ai/` 目錄結構

用 Bash 建立：

```bash
mkdir -p .ai/specs
```

## 步驟 2：生成 `.ai/PROJECT.md`

詢問使用者或根據現有檔案推斷，生成 PROJECT.md。

若專案已有 `package.json` / `bun.lockb` / `go.mod` 等，用 Bash 讀取來推斷技術棧。

格式：

```markdown
# Project: {name}

## 技術棧

- Runtime: ...
- Framework: ...
- 套件管理: ...

## 目錄結構

\`\`\`text
(實際目錄)
\`\`\`

## 重要檔案

- ...

## 常用指令

- ...
```

## 步驟 3：生成 `.ai/RULES.md`

從全域設定中提取與本專案相關的規則，轉換成 LLM-agnostic 格式。

## 步驟 4：生成各 LLM 入口

### `.claude/CLAUDE.md`（若不存在）

```markdown
# Project Rules

請先讀取 `.ai/PROJECT.md` 了解目錄結構。
請先讀取 `.ai/RULES.md` 了解工作規則。
```

### `.cursor/rules/main.mdc`（若使用 Cursor）

```text
---
description: Main project rules
alwaysApply: true
---

請先讀取 `.ai/PROJECT.md` 了解目錄結構。
請先讀取 `.ai/RULES.md` 了解工作規則。
```

### `.codex/AGENTS.md`（若使用 Codex）

```markdown
# Agent Instructions

讀取 `.ai/PROJECT.md` 了解目錄結構。
讀取 `.ai/RULES.md` 了解工作規則。
```

## 步驟 5：確認

列出建立的檔案，問使用者是否需要調整任何內容。
