---
name: architecture-review
description: "Codex architecture review 詞彙與流程；在不做 broad rewrite 的前提下找 deep-module 與 testability 機會。Miyago 詢問 architecture、refactoring opportunities、codebase design、coupling、seams、module boundaries，或如何讓 code 更容易測試／導覽時使用。"
user-invocable: true
when_to_use: "用於 read-only architecture assessment，或 implementation 前規劃 focused refactor。"
tags: [codex, architecture, refactor, design, testability]
effort: medium
shell: preferred
runtime-scope: codex-native
---

# Codex Architecture Review（架構審查）

尋找會影響 locality、leverage 與 testability 的 architectural friction。除非
Miyago 明確要求，review 時不要直接 refactor。

## 詞彙

- **Module**：具有 interface 與 implementation 的任何單位：function、class、
  package、route、feature slice。
- **Interface**：caller 必須知道的一切：types、invariants、error modes、順序、
  config 與 performance expectations。
- **Implementation**：藏在 interface 後面的 code。
- **Seam**：不用修改 caller 就能改變 behavior 的位置。
- **Adapter**：seam 上的具體 implementation。
- **Depth**：小 interface 背後承載多少有用 behavior。
- **Locality**：changes 與 bugs 集中在同一處。
- **Leverage**：一個 module implementation 讓多個 callers 或 tests 受益。

## 審查流程（Review Flow）

1. 如果存在，讀取相關的 `CONTEXT.md`、`CONTEXT-MAP.md` 與 `docs/adr/`；不存在
   時安靜繼續。
2. 只檢查和指定範圍有關的 modules。
3. 找出 friction：
   - 理解一個概念必須在許多 shallow files 之間跳來跳去
   - callers 必須知道 implementation details
   - tests 繞過 public interface
   - extracted helpers 沒有隱藏任何 complexity
   - 一個 seam 只有一個 adapter，沒有真正的 variation
   - change 需要在許多 callers 協調修改
4. 套用 deletion test：刪除 module 後若 complexity 消失，通常是 pass-through；
   若 complexity 擴散到 callers，代表該 module 有保留價值。
5. 提出 candidates，包含 file references、risk、expected benefit 與建議的
   first move。

## 輸出形狀（Output Shape）

先列 findings，依 impact 排序：

- 問題（Problem）
- 證據（Evidence）
- 建議變更（Suggested change）
- 為什麼能改善 locality、leverage 或 testability
- 驗證策略（Verification strategy）

每個 recommendation 標記為 `Strong`、`Worth exploring` 或 `Speculative`。

## 邊界（Boundaries）

- 提出和 ADR 衝突的 architecture work 時，必須明說衝突。
- 不要為 hypothetical future cases 發明 abstractions。
- 除非 selected refactor 很大或 cross-module，否則不要建立 broad specs。
- 優先選一個能創造更好 test seam 的 focused refactor，避免 sweeping cleanup。
