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

Pilotfish orchestration 對這份 Codex adapter 是 active 的。第一次 action 前
先自動分流：一個 command／一個 action 留在便宜的 Luna parent 或
`mech-executor`；設計、工具選擇、結果解讀、多步驟或不確定工作，自動
dispatch 綁定的 strong `executor`，不等 Miyago 口頭要求 multi-role。
清楚的 bounded workstream 或必要 review 也主動 dispatch 最合適且成本最低的
native typed role，並把使用者要求的 outcome 跑到 acceptance。單一緊密的
local action 留在 parent；不要每個 command 都建立 child，也不要在 outcome
phase 之間停下來等使用者批准或指定下一步。cheap path 遇到 unexpected result、
error、retry、target change 或 unlisted next action 時，只升級一次到
`executor`，先補齊 `goal -> target -> exact action -> expected signal -> stop`。

Native roles 從 `<CODEX_HOME>/agents/` 載入；matching role 不可用時，留在
parent 內完成可安全處理的工作並明確回報限制。保留 installed role 的 model
bindings、approval、security 與 release gates；自動升級只切換 typed role，
不切換 root model。`executor`／`verifier` 可使用安裝的 Astra binding，
`mech-executor`／`scout` 維持便宜 Luna，`plan-verifier` 與 security review
維持 Sol。
