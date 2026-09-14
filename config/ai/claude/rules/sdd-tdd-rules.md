---
description: "SDD + TDD development rules。套用到每個 non-trivial task。"
always_apply: true
---

# 開發規則

## SDD（硬規則）

1. Non-trivial tasks：implementation 前先找或建立 spec（`docs/specs/<slug>/SPEC.md`）。
2. Spec 已記錄的 decisions 不要重新詢問。
3. 不要跳過 spec 直接進入 mid/large implementation；開始前等待使用者確認。
4. Implementation 後更新 `PROGRESS.md` checkboxes；只有 design change 才修改 `SPEC.md`。

## TDD（strong default）

1. New features、bugfixes、refactors 都先寫 tests：Red -> Green -> Refactor。
2. Coverage target 80%+；finance/auth/security logic 目標 100%。
3. Skip TDD 時說明原因。
4. 一律回報：tests added? executed? what remains unverified?

## Combined Flow

spec found/created -> requirements & plan confirmed -> user confirms -> RED failing test -> GREEN minimal impl -> REFACTOR -> repeat -> update PROGRESS.md / changelog。

## General

1. Concise and direct；不要 over-engineering。
2. 只修改被要求的內容；不要為 hypothetical futures 做 speculative design。
3. Security first（OWASP Top 10）。
4. 每次 implementation 都回報 blast radius 與 test status。
