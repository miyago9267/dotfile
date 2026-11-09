---
id: spec-vendor-personas
title: Vendor Personas（各 runtime 用該 vendor 的 AI 娘）
status: approved
created: 2026-11-06
updated: 2026-11-06
author: Miyago
tags: [persona, runtime, shared-contract]
priority: medium
---

# Vendor Personas

## Background

以前所有 runtime 共用同一個 persona「Claude 大小姐」。Codex、Gemini、Grok 的 model 不是 Claude，
讓它們都自稱 Claude 大小姐很怪。改成：每個 vendor 的專屬 runtime 用該 vendor 的社群 AI 娘，
語氣與溝通規則仍然共用。

## Decisions

- **兩層結構**：語氣與溝通規則（台灣繁中、語助詞、情緒延續、精簡、做事產出平實）留在
  `config/ai/AGENTS.md`，所有 runtime 共用；角色細節（名字、外觀、自稱、口頭禪、喜好、梗）屬於 persona。
- **預設 persona 是 Claude 大小姐**，描述原封不動留在 shared contract。runtime adapter 可以指定
  vendor persona，只取代角色細節。每個 runtime 只有一個 persona，不疊第二套。
- **對照表**

  | Runtime | Persona |
  | --- | --- |
  | Claude、astra（舊 alias）、pi、OpenCode、Zed，以及其他 model 可由使用者切換的 runtime | Claude 大小姐（預設） |
  | Codex | 白龍娘（Codex 工程變體） |
  | Gemini / agy | 哈基米（Gemini 貓娘） |
  | Grok | 金髮吸血鬼娘 |
  | deepseek-harness、deepseek-tui | 大肥魚（鯨魚娘） |

- **Astra** 是 Codex 的 model profile，但 Miyago 指定維持大小姐：Astra overlay 明說不啟用 Codex adapter 的白龍娘。
- **多 model 的 runtime 維持大小姐**：model 隨時會換，綁死單一 vendor persona 會失真。
- **DeepSeek 目前沒有安裝，也沒有 adapter 檔**，persona 只記在 `runtime-bindings.yaml`
  （`identity.vendor_personas` 與各 runtime 的 `persona` / `persona_brief`），安裝後再落地成 adapter。
- **Grok 不走調情或 companion 路線，與 xAI 官方角色 Ani 無關**，在 Grok adapter 明寫。
- **來源與性質**：形象取自 B 站畫師 ZipZipPipe（胖次狐）的社群 AI 娘二創，非各 vendor 官方設定，
  只當語氣風味。僅為個人非商業使用，不外發、不做成產品；角色圖像與設定的權利屬原作者。
- DeepSeek persona 不使用「以貓娘回答」之類的迷因。

## Touched files

`config/ai/AGENTS.md`、`AGENT-ENTRY.md`、`runtime-bindings.yaml`、`memories/MEMORY.md`；
adapters：`codex/AGENTS.md`（含 legacy `AGENTS.runtime.md`、`AGENT_RULES_SHARED.md`）、`gemini/GEMINI.md`、
`grok/AGENTS.md`、`astra/AGENTS.md`；`gemini/hooks/tool-narration-reminder.sh` 改成 persona-neutral；
`config/ai/generated/*` 重新組合；`script/common/check_agent_rule_sync.sh` 加 persona 斷言。

## Acceptance

- **R1**: When a generated entry is built, the Codex / Gemini / Grok entries shall contain exactly their own vendor persona section.
- **R2**: The Claude and Astra entries shall keep the Claude 大小姐 default persona and contain no vendor persona section from another runtime (Astra carries the Codex adapter text but its overlay disables the persona).
- **R3**: Regenerating entries shall not change the personal-model block.
- Verify: `bash script/common/check_agent_rule_sync.sh`.

## Non-goals

- 不為 DeepSeek 建 adapter 檔、不改 OpenCode / pi / Zed 的 persona。
- 不改 Claude 的 `persona-reminder.sh`。
