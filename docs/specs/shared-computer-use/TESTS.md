---
spec: shared-computer-use
batch: 1
created: 2026-10-04
---

# Tests: 共通 Computer Use MCP 與 Jev 決策層

> Spec: `docs/specs/shared-computer-use/SPEC.md`

## 驗收條件 (EARS)

### R1: 四個 runtime 都列得出 server

- **When**: 列出各 runtime 的 MCP server
- **Shall**: 顯示 `open-computer-use` 並指向 launcher
- **驗證方式**: `claude mcp list`、`codex mcp list`、`agy mcp list`；`OPENCODE_CONFIG*`
  未設定時 `opencode debug config` 顯示 `mcp.open-computer-use` 與 `ask` 規則（驗收 c）
- **狀態**: [x] 通過（2026-10-04，四個 runtime 的列表都指向 launcher；經 launcher 的 MCP handshake 回傳 `open-computer-use 0.3.6` 與九個工具）

### R2 / R3: launcher 驗版本與簽章，不符就不啟動

- **When**: launcher 啟動
- **Shall**: 版本與 Team ID 都符合才 exec；不符或缺 binary 時非零結束且不 exec
- **驗證方式**: stub 測試（驗收 h）
- **狀態**: [x] 通過（2026-10-04，stub 測試 51 項全過）

### R4: launcher 清掉 `OPEN_COMPUTER_USE_*`

- **When**: parent 設了 `OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS=1`
- **Shall**: child 的環境沒有任何 `OPEN_COMPUTER_USE_*`
- **驗證方式**: stub 測試（驗收 g）
- **狀態**: [x] 通過（2026-10-04，stub 測試）

### R5 / R6: setup script 可預演、可還原

- **When**: `--dry-run`，或 `--apply` 之後 `--remove`
- **Shall**: `--dry-run` 不改任何東西；來回之後三個 registry 列表回到原樣，
  `git -C ~/dotfile status --porcelain config/opencode*` 為空
- **驗證方式**: 前後比對列表與 git 狀態（驗收 e）
- **狀態**: [x] 通過（2026-10-04，來回後三個 registry 與 `config/opencode*` 還原，`~/.codex/config.toml` 逐 byte 相同）

### R7: 實際操作 app

- **When**: Claude Code 與 raw Codex 各自經 MCP 對 TextEdit 輸入一段字
- **Shall**: `get_app_state` 讀得回同一段字
- **驗證方式**: 兩個 runtime 各一次真實 tool call（驗收 d）；前置為
  `open-computer-use doctor` 回報兩項權限皆已授權（驗收 a），且
  `open-computer-use call list_apps` 與 `call get_app_state` 無錯誤（驗收 b）
- **狀態**: [x] 通過（2026-10-04，`doctor` 兩項皆 granted；`list_apps` 與 `get_app_state` 無錯誤；raw `codex exec` 與 headless `claude -p` 各自呼叫 `type_text` 與 `get_app_state`，main session 另外讀回 TextEdit 確認兩個標記都在）

### R8: 無對外連線

- **When**: 驗收 b 與 d 進行中
- **Shall**: `Open Computer Use.app` 的 process 沒有對外網路連線
- **驗證方式**: `lsof -i -a -p <pid>` 取樣（驗收 i）；有連線即停止並回報
- **狀態**: [x] 通過（2026-10-04，重測時逐次記錄取樣：三次真實的 `get_app_state` 期間，對 app agent、MCP process 與其子程序共 68 次取樣，`lsof -i` 行數全為 0。限制：每個 process 的實際取樣間隔約 0.12 到 0.27 秒，更短的連線會漏掉；`lsof -i` 看不到經 XPC 或系統 daemon 轉送的流量；重測只量到讀取路徑）

## 測試案例

### 正常路徑

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | launcher 在版本與 Team ID 都正確時啟動 | child 以 `mcp` 為第一個參數被 exec | [ ] |
| 2 | `--apply` 後列出四個 runtime | 都看得到 `open-computer-use` | [ ] |
| 3 | Claude Code 對 TextEdit 打字再讀回 | 讀回的文字相同 | [ ] |
| 4 | raw Codex 對 TextEdit 打字再讀回 | 讀回的文字相同 | [ ] |

### 邊界案例

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | `--apply` 連跑兩次 | 結果相同，不重複新增 | [ ] |
| 2 | 乾淨狀態下跑 `--remove` | 不改任何東西 | [ ] |
| 3 | parent 帶多個 `OPEN_COMPUTER_USE_*` | child 一個都看不到 | [ ] |

### 錯誤處理

| # | 測試 | 預期結果 | 狀態 |
|---|------|----------|------|
| 1 | 套件版本不是 pin 的版本 | 非零結束，不 exec | [ ] |
| 2 | Team ID 不是 `J9P29FA5BX` | 非零結束，不 exec | [ ] |
| 3 | 找不到 binary | 非零結束，訊息清楚 | [ ] |

### 只記錄、不當通過條件

| # | 觀察 | 用途 |
|---|------|------|
| f | 對密碼管理器的 bundle id 呼叫 `get_app_state` 的實際回應：`isError`，訊息為 `Computer Use is not allowed to use the app 'com.1password.1password' for safety reasons.` | S2 的 app policy 設計 |

## 備註

- Batch 完成後隨 TASKS.md 一起封存。
