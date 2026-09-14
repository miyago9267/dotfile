---
id: spec-prompt-language-strategy
title: Prompt 語言比例與維護策略
status: implemented
created: 2026-09-14
updated: 2026-09-14
author: Miyago
tags: [prompt, language, traditional-chinese, cross-runtime, maintenance]
priority: high
---

<!-- markdownlint-disable-next-line MD025 -->
# Prompt 語言比例與維護策略

## Background

目前第一方 Agent prompt 的入口已經改成繁中，但 runtime 會按需讀取的
`agents/`、`commands/`、`rules/` 與 native `skills/` 仍有大量 English
正文。只翻入口，不能消除 Miyago 實際維護與 Agent 讀取時的語言落差。

本 spec 把「完成漢化」定義成 canonical `config/ai/` 內所有第一方、會被
runtime 讀取的 prompt 正文完成翻譯，再重生 active entries 並逐項驗證。
這次沿用既有的小批次成果，擴成完整的 source surface；不把 vendor、依賴、
歷史快照或純設定 metadata 混進翻譯範圍。

## Goal

讓第一方 prompt 的規則解釋、判斷準則、角色描述、指令流程與交付語氣以
台灣繁體中文維護。所有 in-scope 檔案完成翻譯、重生、靜態檢查與設定同步
後，才可宣稱本 spec 完成。

## Definition of done

- 所有列入 manifest 的第一方 prompt 檔案，普通說明以台灣繁體中文為主。
- Commands、paths、file names、API names、hook events、model/provider names、
  frontmatter keys、YAML/JSON keys、runtime protocol verdicts 保持可精確比對。
- generated entries 由 source 重生，未手動維護 derived output。
- 語言、同步、syntax、baseline-aware Markdown、symlink 與 diff 檢查全部通過。
- 未執行的 provider live smoke 明確列為邊界，不把靜態證據說成 runtime 行為。

## Language policy

- Authored policy prose 預設使用台灣繁體中文。
- Technical term 第一次出現可用「中文說明（English term）」；後續用自然中文
  或原本的 technical term，不重複貼完整雙語段落。
- Exact technical tokens、命令、路徑、識別字、metadata、事件名與 provider-native
  spelling 保留 English。
- 不用 raw Han/Latin character ratio 當硬門檻；以有意義的規則正文與固定
  language anchors 守門，避免 code、paths、identifiers 造成統計失真。
- 例外檔案在 spec 的 scope table 明列，不能用「看起來像文件」默默擴張範圍。

### Markdown verification boundary

本批只檢查 source 與 spec Markdown 的結構性錯誤；generated entries 以 source
composition、Personal Model 與 adapter comparison 驗證，不另外把 derived output
當成手寫文件 lint。repository 原有的 line length、frontmatter-first、table
parser 與 fence formatting debt 以 baseline-aware 設定排除：`MD012`、`MD013`、
`MD025`、`MD029`、`MD031`、`MD032`、`MD040`、`MD041`、`MD056`、`MD060`。

## Requirements (EARS)

- **R1**: When a first-party in-scope prompt is maintained, its authored
  explanation shall be primarily Traditional Chinese (Taiwan).
- **R2**: When a runtime requires an exact token, the source shall preserve its
  command, path, identifier, metadata key, event name, protocol verdict, or
  provider-native spelling.
- **R3**: When a technical term is introduced, the prompt shall explain it once
  in plain Chinese when context needs it and shall avoid duplicated bilingual
  paragraphs.
- **R4**: When the shared contract changes language, all runtime adapters and
  active skill surfaces shall retain the same behavior, boundaries, safety rules,
  and completion gate; wording may follow the native file format.
- **R5**: When a generated entry is rebuilt, it shall start byte-for-byte with
  the canonical shared contract and retain the current Personal Model block.
- **R6**: When the language guard runs, it shall fail if a manifest file has no
  Chinese authored prose or if synchronization anchors drift.
- **R7**: When this batch is delivered, every in-scope file shall pass syntax,
  Markdown, synchronization, and language-boundary checks.
- **R8**: When a runtime has no verified live smoke path in this batch, the spec
  shall record that boundary explicitly and shall not infer runtime behavior.

## Scope table

### In scope

| Surface | Source set | Why |
| --- | --- | --- |
| Canonical entry | `config/ai/AGENT-ENTRY.md`, `config/ai/AGENTS.md` | Global boundary and shared contract |
| Runtime adapters | `config/ai/{claude,codex,gemini,grok}/*` entry files | Runtime-specific rules |
| Claude prompt surface | `claude/CLAUDE.md`, `loop.md`, `commands/`, `agents/`, `rules/`, `templates/`, first-party `skills/` Markdown | Claude loads these paths directly or on trigger |
| Codex prompt surface | `codex/AGENTS.md`, native `skills/` Markdown | Codex setup links these paths |
| Gemini prompt surface | `gemini/GEMINI.md`, native `skills/`, `policies/` descriptions | Gemini setup links or applies these paths |
| Shared prompt surface | `shared/skills/` instruction Markdown and references used as skill guidance | Shared skills are linked to multiple runtimes |
| Zed entry | `zed/skills/miyago-agent-rules/SKILL.md` | Canonical source contains a first-party runtime skill |
| Activation output | `config/ai/generated/*` and managed runtime links | Derived output must match source |

### Out of scope

- `config/ai/claude/mcp/**` and its `node_modules/**`, binary assets, fixtures and
  generated dependency documentation.
- `config/ai/claude/coralline/**`, launcher/UI support documentation and other
  bundled upstream material.
- `config/ai/codex/coralline/**`, Gemini skill example references and Grok
  launcher README; these are support material rather than prompt instructions.
- `config/ai/claude-plugin/**` and `config/ai/codex-plugin/**`; these are separate
  packaging source/artifact surfaces and require their own release verification.
- `config/ai/generated/**` hand edits; these files are regenerated from source.
- `config/ai/memories/extensions/skysight/resources/**`, historical memory snapshots,
  `*before*` files, and other archival evidence.
- `runtime-bindings.yaml`, JSON/TOML/YAML keys, provider metadata and shell/code
  identifiers, except where a prompt-facing description is explicitly in the
  manifest.
- OpenCode live behavior or a new OpenCode adapter.
- Provider routes, models, permissions, hooks, credentials, setup architecture,
  and `dev-discipline` lifecycle.
- Provider live parity claims for Claude, Codex, Gemini, Grok, Zed or OpenCode.

## Phase plan

### Phase 0: Spec、manifest 與 failing guard

> Status: completed

更新本 spec、TASKS、TESTS、PROGRESS，建立固定 in-scope manifest 與語言檢查。
先在尚未翻譯的 native prompt 上取得可重現的 failing signal。

### Phase 1: Canonical source 與 adapters

> Status: completed

複核並完成 `AGENT-ENTRY.md`、shared contract 與四個 runtime adapter；保留
既有 compatibility anchors、runtime 邊界、Persona 與 completion gate。

### Phase 2: Claude prompt surface

> Status: completed

翻譯 Claude 的 loop、commands、agents、rules、templates，以及 manifest 列出
的第一方 skills 與其必要 reference/playbook。保留 frontmatter schema、工具名、
命令名與原有操作順序。

### Phase 3: Codex、Gemini、shared 與 Zed prompt surface

> Status: completed

翻譯 Codex/Gemini native skills、shared skills 的 instruction/reference、Gemini
policy-facing 說明與 Zed skill；不改 runtime binding 或工具能力。

### Phase 4: Regenerate and activate

> Status: completed

執行 `script/common/update_config.sh`，確認 generated entries、Personal Model、
managed symlink 與實際 source chain 都沒有漂移。

### Phase 5: Final acceptance

> Status: completed

執行 language manifest guard、existing sync checker、shell syntax、Markdown、
JSON/TOML/YAML parse、inline token preservation、generated prefix、symlink 與
`git diff --check`。所有結果寫回 TASKS、TESTS、PROGRESS。

## Architecture

```text
config/ai/AGENT-ENTRY.md + AGENTS.md
  canonical boundary + shared Traditional Chinese policy
        |
        +--> runtime adapters and native prompt surfaces
        |      Chinese authored prose + exact technical tokens
        |
        +--> script/common/update_config.sh
               |
               +--> config/ai/generated/* active entries
               +--> managed runtime links
```

## ADR

### ADR-1: 翻譯完整的 active prompt surface

- 決策：本批不只翻入口；凡是 canonical `config/ai/` 中會被 runtime 讀取的
  第一方 prompt instruction，都列入 manifest 並完成漢化。
- 原因：入口翻完仍讓 Agent 在 skill、command、subagent description 裡讀到
  大段 English，無法解決實際維護與語氣問題。

### ADR-2: Exact technical tokens 保留 English

- 決策：commands、paths、identifiers、metadata、事件名與 provider-native
  tokens 保留 English；普通說明改用繁中。
- 原因：loader、checker、runtime tool contract 可能精確比對這些字串。

### ADR-3: 以語義守門取代字元比例

- 決策：checker 驗證 manifest、中文正文錨點、必要 English anchors 與生成
  同步；不設 raw Han/Latin 百分比門檻。
- 原因：程式碼、路徑與識別字會扭曲比例，不能代表規則正文可維護性。

### ADR-4: Packaging 與歷史資料保持邊界

- 決策：vendor、依賴、插件 packaging、歷史快照、純 metadata 不在本批翻譯。
- 原因：它們有不同來源、release 或資料保存生命週期；混入會破壞 scope 與
  驗證可信度。

## Risks

<!-- markdownlint-disable MD013 -->
| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| 翻譯改變規則語意 | high | 逐段對照既有硬限制，保留 anchors，逐面 review |
| loader 需要的 English token 被翻掉 | high | manifest guard、inline token comparison、syntax checks |
| native surface 遺漏 | high | 固定 manifest 對照 setup symlink 與 skill source tree |
| generated entry 與 source 漂移 | high | 只改 source，執行 setup 並做 byte-for-byte prefix 驗證 |
| 靜態檢查通過但 provider 語氣未改善 | medium | 不把 source proof 當 live behavior proof，保留 smoke boundary |
| 翻譯碰到外部或歷史資料 | medium | scope table 排除，checker 不掃 excluded paths |
<!-- markdownlint-enable MD013 -->

## Rollback

本批只修改列入 manifest 的 tracked source、檢查器與 spec 文件。若 acceptance
失敗，保留 failing evidence，按檔案 diff 回退對應語言改動；不刪除 runtime 外部
檔案、不重建 plugin artifact，也不碰 Personal Model source。
