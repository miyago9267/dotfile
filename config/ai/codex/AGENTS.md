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

Pilotfish orchestration 是 active 的。第一次 action 前自動分流：單一 command、
普通工具與不確定工作留在 Luna parent 或 `mech-executor`；一般設計、工具選擇、
QA 與 bounded implementation 用 Sol `sol-executor`；只有高信心的架構、跨系統
權衡、衝突證據，或 Sol 回報 deep boundary 時才用 strong `executor`。cheap path
遇到 unexpected result、error、retry 或 target change 時先升級一次到
`sol-executor`。

Native roles 從 `<CODEX_HOME>/agents/` 載入；role 不可用時留在 parent 做可安全
處理的部分並回報限制。保留 installed role 的 model bindings 與 approval、
security、release gates；自動升級只切換 typed role，不切換 root model。
