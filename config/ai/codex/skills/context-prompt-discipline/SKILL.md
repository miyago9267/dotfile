---
name: context-prompt-discipline
description: "Codex context/prompt engineering guardrail：避免 broad searches、large logs、oversized tool output 與 vague delegation prompts 造成 token 使用失控。進行 research、diagnostics、log/session analysis、subagent prompts、second opinions，或任何可能產生大量 context 的 task 時使用。"
alwaysApply: true
user-invocable: true
when_to_use: "在可能拉入 large context 或 delegate open-ended analysis 的 commands/prompts 前套用。"
tags: [codex, context, prompt, tokens, usage, discipline]
effort: low
shell: optional
runtime-scope: codex-native
---

# Context / Prompt Discipline（context／prompt 紀律）

保持 model 的 working context 小、相關，而且按 phase 組織。

## Large Commands 前

先判斷 command 是否可能回傳超過 10k tokens。若會，先採用下列其中一種形式：

- `rg --files ... | sed -n '1,120p'`
- `rg -l PATTERN DIR`
- `rg -n --max-count 20 PATTERN DIR`
- `find DIR ... | sed -n '1,160p'`
- 用 `jq`／`awk` 將 JSON/JSONL/logs 整理成 summary table
- 將 raw output redirect 到 `/tmp/...`，只讀 top-N 或 aggregate stats

High-risk targets：

- `~/.codex`, `~/.claude`, `$HOME`, `~/Library`
- `sessions`, `archived_sessions`, `logs`, `cache`, `node_modules`
- binary `strings`, minified bundles, generated files
- CI logs, rollout traces, JSONL transcripts

對這些 targets 執行 broad `rg PATTERN DIR` 時，必須設定 output cap 或接 summary
pipeline。

## 工具輸出預算（Tool Output Budget）

- Exploration commands：優先使用 `max_output_tokens <= 12000`。
- 已知的小檔案 read：使用一般 output。
- 未知的 logs/JSONL/binaries：先寫入 temp file 或先做 summary。
- Command 意外回傳巨大 output 時，停止擴大讀取 adjacent files；先整理已知內容，
  再從 anchors 繼續。

## Context 交接（Context Handoff）

在 phase boundary 將 state 壓縮成：

1. Goal
2. 已驗證事實
3. Decisions
4. 已修改檔案／相關 anchors
5. 下一個最小動作

用這份 handoff 取代整份 exploration transcript 的延續。Current thread 若大多
是 investigation residue，建議 `/compact` 或開新 session。

## Prompt 形狀（Prompt Shape）

給 subagents、`codex exec` 或其他 model 的 prompts 必須包含：

- objective
- scope boundaries
- explicit exclusions
- output format
- budget limit
- verification expectation

不合格：

```text
研究所有相關 code，告訴我該做什麼。
```

合格：

```text
只在 src/auth 中找 login token refresh path。
最多回傳 5 個條列：files、key functions、likely bug、missing test。
不要檢查 node_modules 或 generated files。
```

## Second Opinion 預設值

Review snippets：

- 只要求檢查 correctness/security regressions。
- 限制最多 5 個 findings。
- 要求提供 file/line references。
- 禁止 broad refactors 與 style preferences。
- 不要要求它重新摘要完整問題。

## 完成條件（Done Criteria）

Session 結束時留下的 context 應少於消耗的量：

- raw tool output 已整理成 summary
- final answer 只保留 relevant anchors
- large findings 在需要時記錄到 durable note/spec
- 第一次 anchor pass 後沒有重複 broad search
