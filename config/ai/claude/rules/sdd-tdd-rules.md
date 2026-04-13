---
description: "SDD + TDD 開發行為規則。適用於所有非 trivial 任務。"
always_apply: true
---

# 開發行為規則

## SDD（硬規則）

1. 非 trivial 任務必須先找或建 spec（`docs/specs/<slug>/SPEC.md`），再實作
2. 不得重問 spec 中已記錄的決策
3. 不得跳過 spec 直接進入中大型實作
4. 實作完必須更新 `PROGRESS.md` 的 checkbox；Spec 只在設計變更時更新
5. 中大型實作前必須等使用者確認

## TDD（強烈建議）

1. 新功能、修 bug、重構時優先先寫測試
2. 遵循 Red -> Green -> Refactor 循環
3. 覆蓋率目標 80%+，金融/認證/安全邏輯 100%
4. 不做 TDD 時必須說明原因
5. 回報時交代：測試是否新增、是否執行、未驗證範圍

## SDD + TDD 整合流程

```text
1. [SDD] 找到或建立 Spec
2. [SDD] 確認需求和實作計畫
3. [SDD] 使用者確認 -> 開始實作
4. [TDD] 寫失敗的測試（RED）
5. [TDD] 寫最少的實作（GREEN）
6. [TDD] 重構（REFACTOR）
7. [TDD] 重複 4-6 直到完成
8. [SDD] 更新 PROGRESS.md / Changelog
```

## 通用原則

1. 簡潔直接，不過度工程
2. 只改被要求改的東西
3. 不為假設性未來需求設計
4. 安全優先（OWASP Top 10）
5. 每次實作交代影響範圍和測試狀態
