---
id: spec-shared-computer-use
title: 共通 Computer Use MCP 與 Jev 決策層
status: in-progress
created: 2026-10-04
updated: 2026-10-04
author: Miyago
approved_by: Miyago (S1, 2026-10-04)
tags: [computer-use, mcp, jev, macos, security, cross-runtime]
priority: high
---

# 共通 Computer Use MCP 與 Jev 決策層

## Background

Computer use 原本經 Orca 的 `computer-use` skill 導向 `orca computer`，必須開著 Orca 才能
用，也只有讀 `~/.agents/skills` 的 runtime 才吃得到。2026-10-04 已把那個 skill 移走。

Miyago 要的是：

1. 一個所有 agent runtime 都能調用 MacBook 的共通 MCP（第一目標）。
2. LLM 只負責整理複雜情報、多模態與提問；逐步的 UI 決策交給 Jev（TypeSafe
   System One）這類 typed 決策模型，減少 agent turn 與 usage。

參考實作量到的數字：`computer-use-fast` 在同一個任務裡工具本身花 4.6 秒，六個 model turn
花約 97 秒；`jev-browser` 每次 Jev 判斷約 300 ms。成本在 turn，不在工具。

## Requirements (EARS)

### S1：共通 driver

- **R1**: When Claude Code、Codex（raw `codex` 與 `cxh`）、agy 或日常 opencode 列出 MCP
  server，the system shall 顯示 `open-computer-use` 並指向同一支 launcher。
- **R2**: When launcher 被啟動，the system shall 先確認套件版本為 pin 的版本、內附 app 的
  Team ID 為 `J9P29FA5BX`，才 exec `open-computer-use mcp`。
- **R3**: If 版本或 Team ID 不符，或找不到 binary，then the system shall 以非零結束且不 exec。
- **R4**: When launcher 被啟動，the system shall 移除所有繼承來的 `OPEN_COMPUTER_USE_*`
  環境變數。
- **R5**: When 執行 `setup_computer_use.sh` 不帶參數或帶 `--dry-run`，the system shall
  不改任何 registry 或檔案。
- **R6**: When 依序執行 `--apply` 與 `--remove`，the system shall 讓三個 registry 的列表與
  `config/opencode/opencode.json` 回到 apply 前的狀態。
- **R7**: When agent 經 MCP 對 TextEdit 輸入文字，the system shall 能再以 `get_app_state`
  讀回該文字。
- **R8**: While driver 在操作 app，the system shall 不產生對外網路連線；若觀察到連線就停止
  並回報。

### S2：Jev 決策層（設計中，尚未核准）

見 `S2-DESIGN.md`。

## Non-goals

- 不做 Codex light profile（`cxc` / `cxf`）：它們跑 `--ignore-user-config`，且
  `codex-profile-check.sh` 禁止 light profile 帶 `mcp_servers`。
- 不動 Orca 的 Codex runtime home、`opencode-harness`、`opencode-studio`。
- 不取代 Codex 原生的 `cua_repl` / `computer-use` plugin，也不取代 Claude desktop 的原生
  computer use。
- 不做 Windows / WSL。
- S1 不含 app 白名單、不可逆動作確認、單一 driver 鎖、per-session 核准；這些屬於 S2。

## Alternatives Considered

### 方案 A：自己寫 Swift accessibility driver

不選。driver 是既有工程，`open-computer-use` 已經有九個工具、背景操作、公證過的 permission
agent。自建只會延後第一個可用版本，差異化在決策層，不在 driver。

### 方案 B：`cua-driver` + `computer-use-fast` 的 `cu.py`

不選為 driver。它是 skill 加 CLI，不是 MCP，各 runtime 要各自接 shell。它「一次呼叫跑完整串
動作、文字比對找目標」的做法收進 S2。

### 方案 C：沿用 Orca 的 `orca computer`

不選。需要 Orca app 在跑，等於把系統能力外包給另一個 app。

## Rabbit Holes

1. 不要把 launcher 當成安全邊界。真正的邊界是 macOS 的 TCC 授權；任何以 Miyago 身分執行
   的 process 都能直接跑 `open-computer-use call`。
2. 不要啟用 `ocu js` / `ocu repl`：那是任意本地 JavaScript 執行。
3. 不要設定 `OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS`：會移動真實滑鼠、改變前台
   焦點。
4. 注意 opencode 的 MCP 設定是 tracked 檔（`~/.config/opencode` symlink 進 dotfile），不是
   registry 指令。

## Architecture

```text
Claude / Codex / agy / opencode
        │  stdio MCP: open-computer-use（九個工具）
        ▼
config/ai/shared/computer-use/computer-use-mcp.sh
        │  驗版本 + Team ID、清 OPEN_COMPUTER_USE_*、exec
        ▼
open-computer-use mcp（npm global, 0.3.6）
        │  使用者暫存目錄下的 Unix socket，只限本人
        ▼
Open Computer Use.app（com.ifuryst.opencomputeruse）
        │  Accessibility + Screen Recording（TCC）
        ▼
目標 macOS app
```

- Launcher 與測試：`config/ai/shared/computer-use/`
- 註冊：`script/common/setup_computer_use.sh [--dry-run|--apply|--remove]`
- S2 會在 launcher 之上加一層 `jev-computer` MCP，原 driver 留作接手用的低階介面。

## ADR

### ADR-1: Driver 採用 `open-computer-use@0.3.6`

- 決策：採用第三方套件，pin 版本，安裝前比對 registry integrity，launcher 每次啟動驗
  Team ID。
- 原因：MCP 原生、tool surface 與 Codex 官方一致、MIT、app 為 Developer ID 簽章並已公證、
  無 npm 依賴、`postinstall` 只印字、registry 有 SLSA provenance。
- 代價：上游沒有 session 核准與 app policy；`SECURITY.md` 仍是未填的範本，沒有通報管道；
  發版頻繁（約一個月內 0.3.0 到 0.3.6），升級要重跑 integrity 與簽章檢查。

### ADR-2: 接受「TCC 授權 = 使用者層級桌面控制」

- 決策：Miyago 於 2026-10-04 接受此殘餘風險。
- 原因：這正是「任何 agent 都能調用」的必然結果；MCP 註冊與 runtime 的核准提示都擋不住
  直接走 CLI 的路徑。
- Kill switch：系統設定關掉 `Open Computer Use` 的 Accessibility 與 Screen Recording，或
  `tccutil reset Accessibility com.ifuryst.opencomputeruse` 與
  `tccutil reset ScreenCapture com.ifuryst.opencomputeruse`。

### ADR-3: Codex 也註冊，且沒有人工確認

- 決策：Miyago 於 2026-10-04 選擇四個 runtime 都註冊。
- 原因：共通版的目標優先。
- 代價：`~/.codex/config.toml` 與 `heavy` profile 都是 `approval_policy = "never"`，Codex
  呼叫這個 MCP 不會詢問。`security-reviewer` 原建議 S1 不註冊 Codex，此為使用者覆寫。

### ADR-4: 使用時的 session 規則

- 決策：S2 的 gate 上線前，computer use 只在可信任的 session 使用，不與瀏覽不可信內容的
  工作並行。
- 原因：螢幕內容的 prompt injection 目前沒有技術性防護；`get_app_state` 可讀出完整信件與
  聊天內容。

### ADR-5: Codex 以標記區塊註冊，不用 `codex mcp add`

- 決策：`setup_computer_use.sh` 自己在 `~/.codex/config.toml` 結尾 append 一段有 begin / end
  標記的 `[mcp_servers.open-computer-use]`，移除時刪掉同一段。
- 原因：實測 `codex mcp add` 會重新序列化無關的 `[mcp_servers.node_repl]`（key 重排、
  `120` 變 `120.0`、刪掉 `args = []`），`--remove` 就無法逐 byte 還原。
- 代價：Codex app 之後若重寫整份檔案而丟掉標記，`--remove` 會退回 `codex mcp remove` 並警告。

### ADR-6: Launcher 自己找 binary，並驗 bundle 完整性

- 決策：解析順序為 test seam、`PATH` 上的絕對路徑執行檔、
  `~/.nvm/versions/node/*/bin/open-computer-use` 中版本符合 pin 的最新一個；把該目錄放進
  子程序的 `PATH` 讓 `#!/usr/bin/env node` 找得到 node。exec 前除了比對 Team ID，也跑
  `codesign --verify --strict`。
- 原因：nvm 是 lazy-load，agent 啟動的 process `PATH` 沒有 nvm 的 bin 目錄；只比對 Team ID
  擋不住被竄改的 bundle。
- 限制：`codesign` 只涵蓋 app bundle；套件裡 Node 的 `bin/` 與 `scripts/` 只受版本 pin 保護。

## Phase 計畫

### S1: 共通 driver

- 安裝、launcher、測試、setup script、四個 runtime 註冊、實機驗收。

### S2: `jev-computer` 決策層

- 目標導向工具，決策順序為文字比對 → Jev → 回 status 給 LLM；加上 app policy、不可逆動作
  gate、單一 driver 鎖。需要先決定資料界線。

### S3: 量測

- 比較原始工具與 `jev-computer` 的 turn 數、token、延遲，再決定原始九個工具是否繼續對
  agent 開放。

## Risks

| 風險 | 影響 | 緩解 |
|------|------|------|
| 任何本機 process 可繞過 MCP 直接操作桌面 | 桌面被非預期操作 | ADR-2 已接受；kill switch 為撤銷 TCC |
| Codex 無人工確認 | 誤操作直接生效 | ADR-3 已接受；S2 加不可逆動作 gate |
| 螢幕內容 prompt injection | agent 被畫面文字帶走 | ADR-4 的 session 規則；S2 加 app 白名單 |
| 上游 native binary 的對外連線未知 | 畫面資料外流 | R8 實測；有連線就停 |
| 上游升級換簽章或行為改變 | launcher 擋下或行為漂移 | pin 版本、驗 Team ID、升級走同一套檢查 |
| 兩個 agent 同時操作 | 動作互相干擾 | S1 不處理；S2 加單一 driver 鎖 |
