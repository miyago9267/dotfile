---
name: final-state-publication
description: 從目前已接受的 final state 產生 PRs、comments、summaries、checkpoints 與 memory entries，不使用對話中的修正歷史。要寫入或發布 durable artifact 時使用；一般直接回覆不要使用。
metadata:
  short-description: 發布 final state，不帶入 transcript residue
---

# Final-State Publication（最終狀態發布）

把 interactive task 轉成 durable artifact 時使用此 skill。Artifact 必須描述已
接受的 current state，不描述抵達它的過程。

## 來源邊界

把 conversation 當成 execution context。裡面可能有 guesses、被拒絕的
interpretations、abandoned edits 與 self-corrections；它不是 publication source。

用最小且 authoritative 的 input set 建立 artifact：

1. 目前 accepted task intent 與 acceptance criteria；
2. current source 與 final diff；
3. direct validation evidence；
4. repository 或 destination-specific templates。

這些 inputs 無法建立的 claim，標記為 `unverified` 或省略。不要只因為 claim
早先出現在 conversation history，就從那裡撿回來。

## 狀態正規化

使用者 correction 改變 requested outcome 時，替換 working state 中受影響的
field。不要把 correction 升格成新 requirement，也不要在 final description
保留已拒絕的 interpretation。

以正面且獨立的方式描述 result。Removed 或 rejected item 只有在其缺席本身是
independent acceptance、safety、compatibility、legal 或 domain constraint 時，
才寫入 artifact；否則就是 iteration residue。

## 發布規則

- 說明 change 現在會做什麼。
- 只保留會影響 maintenance、operation、review 或 acceptance，且無法從 diff
  直接讀出的 rationale。
- 省略 prior attempts、correction steps、abandoned approaches、removed content，
  以及解釋工作「不是什麼」的內容。
- 不要發明固定 section set；使用 destination template 與能表達 final result
  的最小結構。
- PRs、comments、summaries 與 memory 不要放 routine process narration。

發布前套用這個 test：

> 讀者不看 conversation，也能理解並 review 這份 artifact 嗎？

如果答案是 no，就用 current accepted state 取代 historical narration，或把
missing fact 標為 unknown。每個 negative statement 都要確認它是 durable
constraint，而不是 previous correction 的 evidence。

## Context 隔離

可以時，使用只包含上述 authoritative inputs 的 fresh publication context。
不要把完整 transcript 貼給 PR 或 summary writer。沒有 fresh context 時，撰寫
前仍要套用相同 boundary，丟掉只存在於 transcript 的 material。
