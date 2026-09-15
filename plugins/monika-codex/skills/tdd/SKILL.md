---
name: tdd
description: "Codex risk-based testing：high-risk behavior 使用 TDD，其餘優先 targeted verification。"
user-invocable: true
when_to_use: "Bug fix 或 behavior change 適合先寫 failing test 時使用。"
tags: [codex, tdd, tests, verification]
effort: medium
shell: optional
runtime-scope: codex-native
---

# Codex Risk-Based Testing（依風險測試）

優先 targeted verification，不自動對所有 task 套用完整 TDD。

## 這些情況使用 TDD

- Reproducible bug fixes。
- Public API 或 core business logic changes。
- Security、auth、finance、data migration 或 high-risk logic。

## 先 patch，再 verification

- Small UI/text/config/script changes。
- 有明確 local checks 的 mechanical refactors。
- Second opinion 或 review-only tasks。

## 測試品質（Test Quality）

- 透過 public interfaces 測試 observable behavior。
- 可以使用時，測試名稱採用 project 的 domain vocabulary。
- 優先使用能走過真實 call paths 的 integration-style seams。
- 避免 tests 綁定 private methods、internal helper names 或 incidental data shape。
- 只有在真正的 external boundaries 或 slow/unreliable dependencies 使用 mocks。

## Red-Green 循環

- 一次處理一個 vertical slice：一個 behavior、一個 failing test、一個 minimal
  implementation。
- 不要先寫完所有 tests，再一次寫完所有 implementation。
- 每個 new test 聚焦在上一個 cycle 得到的資訊。
- 只有 green 後才 refactor。

## 預算（Budget）

- 用一次 focused search 找到 test command。
- 先跑 targeted tests；除非 touched area 需要，不要跑 full suites。
- 回報 tests run 與 unverified risk。
