---
description: 全面驗證 -- 依序執行 build / type check / lint / test，回報是否可以 PR。
---

# /verify [模式]

對當前 codebase 執行完整驗證流程。

## 執行順序

1. **Build** — 建置失敗立即停止並回報
2. **Type check** — 列出所有型別錯誤（附 file:line）
3. **Lint** — 回報 warning 和 error
4. **Test** — 執行全部測試，回報通過率和覆蓋率
5. **Console.log 掃描** — 找出遺留的 debug log
6. **Git status** — 確認未提交的變更範圍

## 輸出格式

```text
VERIFICATION: [PASS/FAIL]

Build:    [OK/FAIL]
Types:    [OK/X errors]
Lint:     [OK/X issues]
Tests:    [X/Y passed, Z% coverage]
Logs:     [OK/X console.logs]

Ready for PR: [YES/NO]
```

## 模式

- `/verify` 或 `/verify full` — 完整檢查（預設）
- `/verify quick` — 只跑 build + type check
- `/verify pre-commit` — 提交前適用的檢查
- `/verify pre-pr` — 完整 + 安全掃描
