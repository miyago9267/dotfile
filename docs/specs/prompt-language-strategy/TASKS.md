---
spec: prompt-language-strategy
batch: 2
created: 2026-09-14
---

# Tasks: Prompt 語言比例與維護策略

> Spec: `docs/specs/prompt-language-strategy/SPEC.md`
> Batch: 2 — 完成 canonical `config/ai/` 第一方 active prompt surface

## 前置條件

- [x] 確認 canonical source 是 `config/ai/`
- [x] 保留前一批入口、shared contract、`human-voice` 與 generated output
- [x] 確認 Context Harness 沒有本 task id；不寫入不相干 task
- [x] 確認不讀取或修改 `/Users/miyago/Project/AI/monika`
- [x] 建立本批固定 prompt manifest

## Phase 0: Spec、manifest 與 failing guard

- [x] 擴大 `SPEC.md` 的 goal、scope、phase 與 definition of done
- [x] 重建 `TASKS.md`、`TESTS.md`、`PROGRESS.md`
- [x] 建立 language manifest checker，排除 generated/vendor/歷史資料
- [x] 翻譯前執行 checker，取得剩餘 English prompt 的 failing signal

## Phase 1: Canonical source 與 adapters

- [x] 翻譯 `config/ai/AGENT-ENTRY.md` 的 authored prose
- [x] 複核 `config/ai/AGENTS.md` 與四個 runtime adapter 的既有翻譯
- [x] 確認 existing sync anchors 與 runtime 邊界未漂移

## Phase 2: Claude prompt surface

- [x] 翻譯 `claude/loop.md`、`commands/`、`agents/` 與 `rules/`
- [x] 翻譯 `claude/templates/` 與 first-party skill Markdown
- [x] 翻譯 skill 使用的 first-party reference、playbook 與 CLI reference
- [x] 保留 frontmatter schema、工具名、命令名與原操作順序

## Phase 3: Codex、Gemini、shared 與 Zed prompt surface

- [x] 翻譯 Codex native skills
- [x] 翻譯 Gemini native skills 與 prompt-facing policy 說明
- [x] 翻譯 shared skills 的 instruction 與必要 references
- [x] 翻譯 Zed 的 `miyago-agent-rules` skill

## Phase 4: Regenerate and activate

- [x] 執行 `bash script/common/update_config.sh`
- [x] 確認四個 generated entries 由 shared source 開頭
- [x] 確認 Personal Model block 未變更
- [x] 確認 Claude/Codex/Gemini/Grok managed symlink 指向正確 source

## Phase 5: Final acceptance

- [x] language manifest checker
- [x] `bash script/common/check_agent_rule_sync.sh`
- [x] shell syntax 與 JSON/TOML/YAML parse checks
- [x] baseline-aware Markdown lint 與 `git diff --check`
- [x] inline technical token preservation 與 scope audit
- [x] 只有全部 acceptance 通過後才將 spec 標成 `implemented`

## 保留的既有變更

- [x] 不修改 `config/nvim/lua/config/completion.lua` 的既有 user change
- [x] 不自動 commit 或 push，本批只交付 working tree 與驗證證據
