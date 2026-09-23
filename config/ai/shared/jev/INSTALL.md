# Jev 工具安裝與操作手冊

這份手冊供 agent 安裝、設定與驗證 dotfile 內的 Jev 工具。完整能力說明與
現有 shadow hook 的行為見 [README.md](README.md)。

## 先選需要的能力

| 需求 | 工具 | 安裝方式 |
| --- | --- | --- |
| 對固定候選項做結構化判斷 | TypeSafe System One API | 官方 SDK 或 HTTP API |
| 操作瀏覽器頁面 | `jev-browser` MCP | `script/common/setup_jev.sh` |
| 檢查自有開發 app 的 runtime state | Reticle MCP | MCP 註冊後，逐 app init |
| 觀察 Codex 工具輸入輸出大小 | Codex compaction shadow | `script/common/setup_codex.sh` |
| 壓縮前選證據並在壓縮後補回 | 第三方 Codex plugin | Marketplace 獨立安裝 |

這些能力互不等價。`setup_jev.sh` 只註冊 `jev-browser` 與 Reticle MCP，不會
安裝第三方 Codex compaction plugin，也不會設定 API key。Pi 沒有 MCP registry，
請依 [Pi 使用說明](pi-jev-tools.md) 使用 CLI/library 路徑。

## 安裝前檢查

1. 從 dotfile repository root 執行，先查看工作樹與實際 installer：

   ```bash
   git status --short --branch
   sed -n '1,180p' script/common/setup_jev.sh
   ```

2. 確認目前 runtime 與 Node.js：

   ```bash
   command -v node npx codex claude agy
   node --version
   ```

   共用 Jev MCP adapters 的 Reticle 需求 Node.js 20.11+。Codex compaction
   plugin 需求 Node.js 22+ 與支援 `codex plugin` 的 Codex CLI。

3. 不要還原或覆蓋未提交檔案。若 runtime setup script 會重寫個人設定，先讀
   該 script，並向 Miyago 說明確切路徑與影響範圍。

## API key 與資料界線

TypeSafe API 使用 `POST https://api.typesafe.ai/v1/systemone`。request 帶入
`state`、`model` 與 typed `questions`；Jev 回傳選項、機率或 yes/no 機率。
詳細格式見 [TypeSafe API](https://docs.typesafe.ai/api) 與
[Choice](https://docs.typesafe.ai/primitives/choice)。

### `sec`、Zsh `PATH` 與載入方式

`sec` 是 `script/utils/sec`，由 Zsh 的 `PATH` 找到。dotfile 的
`config/zsh/.zshrc.d/utils.zsh` 會在目錄存在時將 `$HOME/dotfile/script/utils`
加到 `PATH`。Zsh 的小寫 `path` 是與 `PATH` 綁定的陣列，不是另一個指令。

```zsh
whence -v sec
print -rl -- $path
```

若新安裝的 CLI 尚未被找到，重開 Terminal 或執行 `source ~/.zshrc`，再用
`whence -v <command>` 確認。`source ~/.zshrc` 會重新載入整份互動式設定。

dotfile 的 `.zshrc` 會載入 `~/.zshrc.d/secrets.zsh`。目前這個 snippet 會在有
age key、SOPS 與加密 bundle 時，source 新鮮的 `~/.env.secrets`；快取過期時會先
解密重建，再 source 到該互動式 Zsh。這會讓成功解析的 bundle entries 進入該
shell 及其 child processes；雖然 key 沒有寫成 `.zshrc` 裡的文字，載入範圍仍是
整個互動式 shell。

如選擇 SOPS 作為 key 的來源：

```bash
sec status       # 檢查 age、sops、key、cache 與加密檔狀態
sec list         # 只列 secret 名稱，不列 value
sec edit         # 在本機編輯器編輯加密 bundle
sec reload       # 重建 ~/.env.secrets；不會改變呼叫它的 parent shell
secrets-reload   # Zsh function：重建並載入目前 shell
```

`sec reload` 後要在目前 shell 套用，可執行 `source ~/.env.secrets`；新互動式
Zsh 會依上述 snippet 載入。不要用 `sec show`、`sec export` 顯示或另存明文。
若要讓一個 Codex process 只取得 TypeSafe key，優先使用 KeePassXC broker 的
`agent-secret run typesafe-api -- env JEV_ENABLE=1 codex`；它不需要把 key 放進
`.zshrc`，也不會把 SOPS bundle 全部注入該 process。

第一次使用時，`agent-secret` 可能會顯示本機隱藏密碼視窗供使用者解鎖。
不要要求使用者把 key 貼到對話，也不要輸出環境、shell trace 或完整 process
environment。沒有 `agent-secret` 的環境可依上游 plugin 文件設定私有的
`TYPESAFE_API_KEY_FILE`；POSIX 權限必須為 `0600`。key 檔不得放在 repository。

選一個 secret store 作為來源。不要同一把 key 同時放入 KeePassXC 與 SOPS
bundle。SOPS 工作方式見 [secrets/README.md](../../../../secrets/README.md)。
共用的 `jev-browser-mcp.sh` 優先從既有 `.env.secrets` 讀 key；若 process 尚無
`TYPESAFE_API_KEY` 且 broker 可用，才以 `agent-secret` 注入 MCP child。Reticle
本身不需要 TypeSafe key。

只有在允許資料送到 TypeSafe 的 session 才啟用 Jev API 呼叫。送出的 state
必須符合目前任務所需的最小範圍；不要送 secrets、未核准的個資、生產資料、
完整 transcript 或不必要的原始 tool output。遮罩不是完整 DLP。

## 安裝共用 MCP adapters

`setup_jev.sh` 預設只 dry-run。先看它將修改什麼：

```bash
bash script/common/setup_jev.sh --dry-run
```

`--apply` 會更新存在的 Claude、Codex 與 AGY user-level MCP registries，先移除
同名 `jev-browser` / `reticle` entry，再註冊 dotfile wrapper。這是 global
runtime 設定寫入；執行前須向使用者報告範圍並取得確認：

```bash
bash script/common/setup_jev.sh --apply
```

完成後只檢查實際使用的 runtime：

```bash
codex mcp list
claude mcp list
agy mcp list
```

預期看到 `jev-browser` 與 `reticle`。不要用 `setup_jev.sh` 來安裝 runtime
skills。各 runtime 的完整 setup script 會連帶連結其他設定；若 skill 不存在，
先查看其對應的 `script/common/setup_*.sh`，再確認是否要執行。

Reticle 會在 app 專案建立自己的設定。只對 Miyago 擁有的 development app、且
取得專案寫入確認後執行：

```bash
npx -y @reticlehq/server init
npx -y @reticlehq/server doctor
```

初始化後以 `npx -y @reticlehq/server mcp` 提供 MCP。不要對 production app 執行
Reticle init 或把 Reticle 當 production probe。

## 安裝 Codex compaction plugin

`codex-jev-compaction` 是外部實驗性 plugin，不在 dotfile installer 內，也尚未
提交到 Codex 官方 plugin directory。上游目前沒有 release；以下以
2026-09-23 核對的 commit 固定來源：

```text
Jiiiin/codex-jev-compaction
4278da5f57f9bede20a3b80295dc3b424e1a7bfb
```

安裝前先檢查上游 [README](https://github.com/Jiiiin/codex-jev-compaction)、
[PRIVACY.md](https://github.com/Jiiiin/codex-jev-compaction/blob/main/PRIVACY.md)、
hooks manifest 與 [測試報告](https://github.com/Jiiiin/codex-jev-compaction/blob/main/docs/TEST-REPORT.md)。
Marketplace 加入會下載外部程式並修改 Codex user config；必須先向使用者說明
來源、commit、資料流與寫入範圍，再取得確認。

```bash
codex plugin marketplace add Jiiiin/codex-jev-compaction \
  --ref 4278da5f57f9bede20a3b80295dc3b424e1a7bfb
codex plugin add codex-jev-compaction@jev-compaction
codex plugin marketplace list
codex plugin list
```

在新的 Codex session 執行 `/hooks`，逐項檢查並信任 plugin 的 `PreCompact` 與
`SessionStart` hooks。不要以跳過 hook trust 的方式安裝。信任狀態依 hook 定義
hash 綁定；plugin 更新後若 hash 改變，重新檢查內容再信任。

只有明確啟用 `JEV_ENABLE=1` 且 Codex process 取得 API key 時，plugin 才會送出
Jev request。使用安全 broker 啟動新的 CLI session：

```bash
agent-secret run typesafe-api -- env JEV_ENABLE=1 codex
```

plugin 不讀取 `.env`。桌面 app 不一定繼承 Terminal 的環境；請在實際執行的
Codex process 驗證設定，不要只檢查目前 shell。停用時以 `JEV_ENABLE=0` 啟動新
session，或在 Codex plugin 管理介面停用。

這個 plugin 只補充 Codex 原生 compaction：`PreCompact` 建立有期限的 evidence
checkpoint，`SessionStart(source=compact)` 最多恢復一次 bounded excerpt。它不會
改寫或刪除即時 transcript，也不承諾節省 token。啟用後，合格的 tool calls、
tool results 與任務錨點會送到 TypeSafe；上游沒有可靠的自動脫敏功能。Jev 失敗、
key 缺失或 plugin 停用時，Codex 仍會執行原生 compaction。

## 使用 Jev 做上下文判斷

把 Jev 當成有型別的決策元件，不是聊天代理或執行者：

- 用 `Choice` 從互斥候選項選一項；若有可能無一符合，加入 `none`。
- 要各自判斷多段 context 是否保留時，對每段使用一個 `Noul`；不要用單一
  `Choice` 表示可同時成立的多個保留項。
- 用 `Score` 表示有明確順序的保留優先級；分級描述要具體且互斥。
- 在 `state` 附上目標任務、候選來源 ID、必要的上下文與最新狀態。問題寫在
  `instructions`，允許答案與涵義寫在 `criteria`。
- 程式負責套用判斷。低信心、無答案、timeout、格式錯誤或 API 錯誤時，保留
  原 context 或交由人工檢查；不要因低分直接丟棄不可重建資訊。

`confidence` 代表選項機率分布的集中程度，不代表答案正確或動作安全。先用
合成 replay 樣本比較保留結果，再校準門檻。安全規則、P0/P1 優先級、權限、
計數與其他確定性政策留在程式中。

## 驗證

先做不含使用者 transcript 的本機檢查。若有上游 checkout，在該 checkout 執行：

```bash
node plugins/codex-jev-compaction/scripts/cli.mjs doctor
npm run demo
```

需要確認 live Jev 判斷時，只能使用上游提供的合成 evaluator；它會連到 TypeSafe，
但使用 bundled fixtures，不讀取本機會話：

```bash
agent-secret run typesafe-api -- \
  node plugins/codex-jev-compaction/scripts/evaluate.mjs --live-synthetic
```

2026-09-23 已對目前安裝的 Codex plugin 執行 live synthetic evaluator：9 個案例均
成功取得 Jev 回應，9/9 判定保留 critical evidence；checkpoint 中找到完整合成事實
6/9，三個 middle-position 案例未找回完整事實。這確認 API key 注入、TypeSafe
連線、typed Noul 回應與判斷流程可用；不代表 context 恢復品質已達 release 標準。
Evaluator 自身也回報 `releaseReady: false`。這次沒有測試 Codex hooks lifecycle。

`doctor` 成功只證明目前 command process 的設定可讀；它不證明 Codex app process
繼承同一環境，也不證明 hook 曾執行。

若要驗證完整 compaction hook，使用全新、可丟棄的 synthetic workspace 與不含
真實資料的唯一標記：

1. 從已啟用 plugin 與 key 的全新 Codex session 讀取 synthetic marker，要求 Codex
   暫不回報 marker。
2. 再執行至少七個無關的 synthetic read-only 工具呼叫，讓目標證據離開最近工具
   呼叫的固定保留範圍。
3. 執行 `/compact`，等待 compaction 與恢復 hooks 完成。
4. 不准 Codex 重讀檔案，詢問唯一 marker；檢查 plugin metadata 是否回報
   `restored` 且 `evidenceChars` 大於零。不要輸出 evidence snapshot 內容。

若只有 Codex 答對，但沒有 plugin `restored` metadata，不能把結果歸因於 Jev；
它可能來自 Codex 原生 compaction。若沒有 `checkpoint_ready` / `restored`，停止並
回報未通過，不要用真實會話重試。檢查新 session、hook trust、`JEV_ENABLE`、
key 是否注入，以及 plugin 自己的 `PLUGIN_DATA` 是否可寫。

## 停用、移除與更新

停用 Jev 呼叫但保留 plugin：在新 session 設定 `JEV_ENABLE=0`。完全移除 Codex
plugin 與 marketplace 需明確說明會刪除 plugin cache 與 user-level source 設定，
再執行：

```bash
codex plugin remove codex-jev-compaction@jev-compaction
codex plugin marketplace remove jev-compaction
```

移除共用 MCP entries：

```bash
codex mcp remove jev-browser
codex mcp remove reticle
claude mcp remove jev-browser
claude mcp remove reticle
agy mcp remove jev-browser
agy mcp remove reticle
```

Codex metadata shadow 預設會記錄在
`~/.local/state/miyago/jev/compaction-shadow.jsonl`。將新 Codex process 的
`JEV_COMPACTION_SHADOW` 設為 `0` 可停止記錄。資料只含 hook event、tool 名稱與
input/output byte 數，不含 request body 或 response text。

升級第三方 plugin 前重新檢查新 commit 的程式碼、privacy 與 hooks，再更新
marketplace ref；不要盲目跟隨 `main`。新 hook hash 必須重新審查與信任。
