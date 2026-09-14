---
name: diagnose
description: "Codex hard-bug diagnosis loop：修復前先建立可重現的 pass/fail signal。Miyago 回報 broken behavior、failing tests、crashes、flaky behavior、regressions，或要求 debug/diagnose 時使用。"
user-invocable: true
when_to_use: "Bug 或 regression 需要 structured reproduction、hypothesis testing、instrumentation 與 regression verification 時使用。"
tags: [codex, debug, diagnose, regression, tests]
effort: medium
shell: preferred
runtime-scope: codex-native
---

# Codex Diagnose（診斷）

透過 feedback loop debug，不要只盯著 code 猜。

## 流程（Flow）

1. 用一句話定義 observed failure。
2. 建立成本最低的 deterministic pass/fail signal：
   - targeted failing test
   - 帶 fixture input 的 CLI command
   - 對 local server 發送 HTTP request
   - replayed log、trace、payload 或 fixture
   - 只有 bug 是 UI behavior 時才使用 browser script
3. 用該 signal 重現使用者的 failure。若出現不同 failure，再縮小範圍。
4. 列出 3-5 個可 falsify 的 hypotheses，依可能性排序。
5. 一次測試一個 hypothesis。優先 debugger/REPL inspection，再看 targeted logs。
6. 有正確 seam 時，把 minimal repro 轉成 regression test。
7. 修復 issue，再重新執行 minimal signal 與 original scenario。
8. 移除 temporary instrumentation 與 throwaway harnesses。

## Instrumentation（觀測插桿）

- Temporary logs 加上像 `[DEBUG-a4f2]` 這樣的 unique prefix。
- 每個 probe 只改一個 variable。
- Performance regression 先量測再修：baseline timing、profiler output、query
  plan 或 equivalent。

## 沒有 Loop 時

停止並說明已嘗試什麼。只有 local attempts 用盡後，才索取 missing artifact：

- failing input
- logs 或 stack trace
- HAR/network capture
- 帶 timestamps 的 screen recording
- 可重現 issue 的 environment 存取權

沒有 reproduction path 時，不要把 speculative fix 說成 complete。

## 完成條件（Done Criteria）

- Original failure 不再重現。
- Regression test 已存在，或已明確回報 missing test seam。
- Temporary `[DEBUG-...]` instrumentation 已移除。
- Verification commands 與 unverified risk 已回報。
