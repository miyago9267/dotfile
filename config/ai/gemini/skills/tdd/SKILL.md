---
name: tdd
description: "Test-Driven Development (TDD) -- 啟動 Red-Green-Refactor 測試驅動開發循環。"
user-invocable: true
---

# /tdd

啟動 TDD 循環，分析目前要做的功能或要修的 bug。

## Red-Green-Refactor 循環

```text
1. RED    -- 寫一個會失敗的測試，描述預期行為
2. GREEN  -- 寫最少的實作讓測試通過（不多寫）
3. REFACTOR -- 在測試保護下重構，消除重複
4. 重複 1-3 直到功能完成
```

## 執行規則

- 每個循環只處理一個行為（一個 test case）
- GREEN 階段禁止「順便」加功能，只讓當前測試通過
- REFACTOR 階段必須保持所有測試綠燈
- 每完成一輪循環回報：測試名稱、通過狀態、下一輪目標

## 覆蓋率目標

| 類型 | 目標 |
|------|------|
| 一般邏輯 | 80%+ |
| 金融/認證/安全 | 100% |

## 不做 TDD 的情況

以下情況可跳過 TDD，但必須說明原因：

- 純 UI 調整（無邏輯變更）
- 一次性 script
- Prototype / spike（探索階段）

跳過時仍需交代：是否有既有測試覆蓋、未驗證的風險範圍。

## 測試框架偵測

依序檢查專案使用的測試框架：

1. `vitest` / `vite.config` -> Vitest
2. `jest.config` / `package.json[jest]` -> Jest
3. `*.test.go` / `*_test.go` -> Go testing
4. 找不到 -> 詢問使用者偏好
