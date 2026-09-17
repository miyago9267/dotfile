# Codex Runtime Adapter -- Miyago

> 共用身份、溝通、truthfulness、安全與一般 engineering rules 來自
> `config/ai/AGENTS.md`。這份檔案只放 Codex-specific 內容。

## Runtime role

- Codex 是主要的 software-engineering runtime，負責 implementation、debugging、
  refactoring、tests 與 local verification。
- 優先直接做小而明確的改動。只有 large、cross-module 或會改變 architecture
  的工作才使用 planning/spec tracking。
- 使用 Codex-native tools、skills、profiles 與 hooks。不要載入 Claude 的
  runtime workflows 或 skill directories。
- 互動式 shell input 使用 Codex-native `ask-tty` skill。shared skill list 裡
  的 Claude-specific `ask-tty` / `tty-respond` instructions 不適用。
- User-facing output 預設使用台灣繁體中文；commands、paths、identifiers 與
  其他 technical tokens 保留原本的 English。

## Codex workflow（Codex 工作流）

- 一般 coding 使用 `codex exec --ignore-user-config -p code`。
- 短時間的 read-only checks 使用 `fast`；browser、GUI、document 或真正大型的
  工作使用 `heavy`。
- 限制 searches 與 tool output；在宣告完成前，先於本機驗證要求的 behavior。
- 對整個 task 套用共用完成宣告規則（Apply the shared completion claim gate）：
  只要仍有 in-scope action 或 acceptance check，intermediate worker result、
  passing check 或 ready plan 都不能算完成。
- project、architecture、incident、deployment、business-logic 或
  historical-decision lookup 使用 `$knowledge-base-router`。

## Codex continuity

- 新 session 若有既有 task，執行：
  `agent-workflow session-start --runtime codex --cwd "$PWD"`.
- 只有 returned experience bundle 和目前 scope 相符時才使用。
- 用 Context Harness checkpoint 記錄有意義且已驗證的 milestones。

## Codex-native skills

- `architecture-review`、`auto-spec`、`context-prompt-discipline`、`diagnose`、
  `human-voice`、`prototype`、`reverse-skill-router`、`sdd` 與 `tdd` 從
  `config/ai/codex/skills/` 載入。
- `final-state-publication` 是預設安裝的唯一 shared skill。

## Pilotfish

Pilotfish orchestration 對這份 Codex adapter 是 active 的。遇到清楚的
bounded workstream 或必要 review 時，主動 dispatch 最合適且成本最低的
native typed role，並把使用者要求的 outcome 跑到 acceptance。單一緊密的
local action 留在 parent；不要每個 command 都建立 child，也不要在 outcome
phase 之間停下來等使用者批准或指定下一步。

Native roles 從 `<CODEX_HOME>/agents/` 載入；matching role 不可用時，留在
parent 內完成可安全處理的工作並明確回報限制。保留既有 role 的 model
bindings、approval、security 與 release gates。`gpt-6-astra` 仍是明確的
main-session／candidate route，不因任務變難自動切換 root model。
