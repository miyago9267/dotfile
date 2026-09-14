---
spec: prompt-language-strategy
batch: 2
created: 2026-09-14
---

# Tests: Prompt 語言比例與維護策略

> Spec: `docs/specs/prompt-language-strategy/SPEC.md`

## 驗收條件 (EARS)

### R1: In-scope prompt 以繁中維護

- **When**: language manifest checker 讀取第一方 prompt source
- **Shall**: 每個 manifest 檔案都有繁中 authored prose，普通規則說明以台灣
  繁體中文為主
- **驗證方式**: checker 逐檔檢查中文正文錨點與排除清單
- **狀態**: [x]

### R2: Exact technical tokens 保留

- **When**: 翻譯 prompt 正文與 metadata
- **Shall**: commands、paths、identifiers、metadata、hook events、protocol
  verdicts 與 provider-native tokens 仍可精確比對
- **驗證方式**: old `HEAD` 與 current manifest 的 inline-code token comparison、
  runtime-specific checker 與 diff review
- **狀態**: [x]

### R3: 跨 runtime 語義一致

- **When**: shared contract、adapters 與 native surface 完成翻譯
- **Shall**: safety、scope、SDD/TDD、completion gate 與 runtime ownership 不漂移
- **驗證方式**: existing sync checker anchors、四個 generated shared prefix 與
  source-to-adapter diff review
- **狀態**: [x]

### R4: 不重複完整雙語段落

- **When**: manifest 檔案完成翻譯
- **Shall**: English 只留在必要 technical token、compatibility anchor、
  frontmatter 或程式碼，不保留整段 English policy 作為第二份正文
- **驗證方式**: changed-file review；對含大量 English 的檔案檢查其用途與 scope
- **狀態**: [x]

### R5: Active configuration 已同步

- **When**: 執行 config-only update
- **Shall**: generated entries、runtime symlink 與 manifest source chain 指向
  本批內容，Personal Model、provider route 與 credentials 不變
- **驗證方式**: setup output、symlink target、generated prefix、Personal Model
  comparison 與 sync checker
- **狀態**: [x]

### R6: 完成宣告有完整證據

- **When**: 交付本批工作
- **Shall**: 所有 in-scope action、integration step 與 acceptance check 都通過；
  未驗證的 live provider behavior 另列為 scope boundary
- **驗證方式**: TASKS、TESTS、PROGRESS 與實際 command output 一致
- **狀態**: [x]

## 測試案例

### 正常路徑

| # | 測試 | 預期結果 | 狀態 |
| --- | --- | --- | --- |
| 1 | 翻譯前執行 language guard | 指出尚未漢化的 manifest 檔案並失敗 | [x] |
| 2 | 翻譯後執行 language guard | 所有 manifest source 通過 | [x] |
| 3 | 執行 `update_config.sh` | generated entries 重生且 symlink 維持正確 | [x] |
| 4 | 執行 `check_agent_rule_sync.sh` | 輸出 `agent rule sync: OK` | [x] |

### 邊界案例

| # | 測試 | 預期結果 | 狀態 |
| --- | --- | --- | --- |
| 1 | 檢查 code/path/metadata 中的 English | 必要 token 保留，不被 language guard 誤判 | [x] |
| 2 | 檢查 Personal Model block | 內容與來源相同，未被翻譯或改寫 | [x] |
| 3 | 掃描 excluded paths | vendor、依賴、歷史與 generated output 不列為待翻譯 source | [x] |
| 4 | 檢查未納入 OpenCode 的路徑 | 不宣稱 OpenCode live behavior 已完成 | [x] |

### 錯誤處理

<!-- markdownlint-disable MD013 -->
| # | 測試 | 預期結果 | 狀態 |
| --- | --- | --- | --- |
| 1 | 移除 manifest 檔案的中文正文 | checker 失敗並指出目標檔 | [x] |
| 2 | 讓 generated prefix 與 source 不同 | activation check 拒絕 stale generated entry | [x] |
| 3 | 保留一個 technical token 的原文 | token comparison 通過，不要求翻譯識別字 | [x] |
| 4 | 任一 acceptance 尚未通過 | 交付狀態保持 `in-progress` | [x] |
<!-- markdownlint-enable MD013 -->

## Runtime boundary

本批證明 source composition、manifest、generated output、symlink 與靜態檢查。
沒有重新執行四家 provider 的完整 live fixture，也不以本機 source proof 推論
provider 語氣或 live behavior parity。
