---
spec: prompt-language-strategy
batch: 2
created: 2026-09-14
---

# Progress: Prompt 語言比例與維護策略

> Spec: `docs/specs/prompt-language-strategy/SPEC.md`

## Current status

> Status: implemented — Phase 5

本批已完成 canonical `config/ai/` 第一方 active prompt surface 的漢化、
generated activation 與靜態 acceptance。前一批成果保留；未納入 provider live
smoke、OpenCode 新 adapter、vendor/plugin packaging 與歷史資料。

## Phase 0: Spec、manifest 與 failing guard

> Status: completed

- 已將 goal 從「入口翻譯」擴成「完整 active prompt surface」。
- 已明列 canonical entry、runtime adapters、Claude/Codex/Gemini/shared/Zed
  prompt surface 與 generated activation 的 scope。
- 已建立 `script/common/check_prompt_language.sh`；翻譯前 raw scan 找到 26 個
  candidate，依 scope 排除 support material 後以 24 個 manifest source 的明確
  錯誤取得 failing signal。
- Context Harness 不接受 `prompt-language-strategy` task id，route 也誤選
  `agent-benchmark-waza`；本工作以 repo spec 保存狀態，不寫入錯誤 task。
- Phase 0 與 Phase 1 已完成；Claude、Codex、Gemini、shared 與 Zed 的 active
  prompt surface 已完成翻譯，並已通過 activation 與最終驗收。

## Phase 1: Canonical source 與 adapters

> Status: completed

`AGENT-ENTRY.md` 的 hard boundary 已改成繁中 authored prose，保留 YAML
source contract、canonical paths、`non-entry` 與 fallback boundary。前一批的
`AGENTS.md` 與四個 adapter 也已複核，既有 sync anchors 與 runtime 邊界未漂移。

## Phase 2: Claude prompt surface

> Status: completed

Claude 的 `loop.md`、commands、agents、rules、templates、skills 與必要的
reference/playbook/CLI reference 已完成翻譯。frontmatter schema、工具名、命令名、
操作順序與 capability inventory 保留原格式。

## Phase 3: Codex、Gemini、shared 與 Zed prompt surface

> Status: completed

Codex native skills、Gemini native skill/policy-facing 說明、shared skill references
與 Zed skill 已完成翻譯；保留 commands、paths、identifiers 與 runtime-native tokens。

## Phase 4: Regenerate and activate

> Status: completed

已執行 `bash script/common/update_config.sh`；四個 generated entries、Personal
Model block、runtime adapter 與 Claude/Codex/Gemini/Grok managed symlink 均通過
byte-level composition 與 target comparison。

## Phase 5: Final acceptance

> Status: completed

驗證結果：

- `prompt language: OK (107 files)`。
- `agent rule sync: OK`；shell syntax、YAML frontmatter、TOML、runtime YAML、
  Codex profile hygiene 與 `git diff --check` 全部通過。
- 91 份 source/spec Markdown 以 baseline-aware Markdown lint 通過，0 error；
  generated output 以 composition check 驗證。
- 87 份 source 的 inline technical tokens 通過 preservation check；scope audit
  顯示 98 份 in-scope files，另保留 1 份既有 unrelated user change。
- language guard 的缺中文正文負向案例與 generated prefix 的 stale 負向案例均
  正確失敗。

因此本 spec 可以標成 `implemented`。
