# Jev toolbox adapters

這裡只放跨 runtime 的薄 adapter，不放 API key，也不把 Jev 判斷硬編進工作流。

## Capabilities

- `jev-browser`: LLM 提供目標，Jev 選擇頁面元素與動作；遇到不確定或不可逆操作時回傳狀態。
- `Reticle`: 讀取自己開發中的 app 的 DOM、network、console 與 runtime state，
  回傳 verification evidence。
- `fast-jev-compaction`: 目前只保留為研究項目；尚未接入自動刪除上下文。
  四個 runtime 都先使用 shadow/dry-run 邊界。

## Context retention Stop shadow

Claude 的 Stop hook 會把當輪最後一則 assistant 回覆當成單一 candidate，
用 Jev `noul` 評估它是否含有續作線索。這只評估單輪回覆，不會讀取整份
transcript 或逐段選 context。

Hook 預設不呼叫 Jev。明確 opt-in 的 Claude session 設定
`JEV_CONTEXT_SHADOW=1` 後，且 hook process 已取得 `TYPESAFE_API_KEY`，才會
將遮罩後、最多 2400 bytes 的最後一則 assistant 回覆送至
`https://api.typesafe.ai/v1/systemone`。Hook 不讀取 transcript、secret store，
也不會彈出解鎖提示；缺少環境變數時直接略過。遮罩會移除部分程式碼、路徑、
URL 與常見憑證格式，但不是完整 DLP：assistant 回覆若重述 user prompt、tool
argument、file content、diff、command line 或其他私人資料，這些內容仍可能被
送出。設定 `JEV_CONTEXT_SHADOW=1` 代表接受合格 assistant 回覆會外送給
TypeSafe；請只在允許這項資料流的 session 啟用。

Shadow hook 不攔截 Stop、不改寫或刪除 context。它只在
`~/.local/state/miyago/jev/context-retention-shadow.jsonl` 記錄模型、question
hash、candidate 大小、分數與 `would_keep` 建議，不記錄 candidate text。預設
`tau` 是 `0.5`，僅供 shadow 比對，尚未校準，不可拿來自動刪除內容。timeout、
缺少 key、錯誤回應或 log 失敗都會放行。

### Claude CLI key loading

Claude Stop hook 只讀取 Claude process 繼承的 `TYPESAFE_API_KEY`，不讀取 secret
store，也不啟動互動式解鎖。使用 dotfile 設定的互動式 zsh 時，`.zshrc` 會載入
`~/.zshrc.d/*.zsh`，其中的 `secrets.zsh` 會讀取 SOPS 產生的
`~/.env.secrets`；cache 權限為 `0600`。因此從該 Terminal 啟動的 Claude CLI 會
自動取得 key，不必把 key 值寫進 `.zshrc` 或 Claude `settings.json`。更新加密
secret 後執行 `sec reload`，再開新 Terminal 套用。

這是目前實際的 zsh 行為：整份 secrets bundle 會載入每個互動式 zsh；它比
`docs/specs/secrets-management/SPEC.md` 描述的按需載入更廣。由 GUI 啟動的 Claude
不一定會繼承 zsh 環境。

```sh
JEV_CONTEXT_SHADOW=1 claude
```

2026-09-23 已用實際 Claude CLI Stop event 驗證 Jev 呼叫與 metadata 寫入成功。
單次測試的 score 只證明管線可用，不代表 retention threshold 已校準。

需要逐項判斷 compaction candidates 時，仍須由 runtime 提供候選項和來源指標。
目前的 compaction shadow 只記錄 event、tool 與 input/output 大小，並記下
`keep_first: 4`、`keep_recent: 8`、`drop_stale: false` 的候選政策；它不讀取
候選語意，也不會刪除 context。先用 replay 樣本校準 retention 判斷，不沿用
Stingray 的 benchmark。

## Pilotfish route advisory

Claude 的 `UserPromptSubmit` hook（`claude/hooks/jev-route.sh` ->
`pilotfish_route.py`）會請 Jev 判斷 user prompt 最適合先派哪個 Pilotfish
role，再注入一句固定格式的建議。這句建議只是 advisory：不構成 approval，
AGENTS.md 的 gate 與 dispatch brake 優先。Jev 只能建議 role，或把流程收緊成
「寫入前先 explore_then_plan」，不能放寬 interaction shape。

只有環境變數 `PILOTFISH_JEV_MODE=active` 時才注入；`shadow` 只記錄、不注入；
其他值或未設定時完全不呼叫 Jev。`config/zsh/.zshrc.d/claude.zsh` 預設匯出
`active`，因此從互動式 zsh 啟動的 Claude 會開啟；單次停用可用
`PILOTFISH_JEV_MODE=off claude`。

以下情況在本機直接略過，不外送：

- subagent 的 prompt，或 cwd 路徑中有任何一段是 `ITRD`（不分大小寫）。
  另可用 `PILOTFISH_JEV_DENY` 追加其他目錄，以冒號分隔。
- 出現風險字眼：auth、token、key、password、login、ssh、remove、kill、push、
  merge、deploy、prod、migration、刪、清空、部署、權限、個資、付錢等。
  這類 prompt 交給既有的 risk policy 處理。
- 含 code fence、超過 5 行或超過 1024 bytes。
- 遮罩（email、URL、IP、hostname、路徑、token、引號內容）後仍殘留
  `` ` ``、`{}`、`@`、路徑、URL 或長 opaque 字串。`@file` 引用因此一律不送。
- `~/.config/typesafe/api_key` 不是本人擁有的 `0600` 一般檔，或所在目錄
  不是私有目錄。這個 hook 不讀 `TYPESAFE_API_KEY` 環境變數。

連線強制使用 HTTPS 送往 `api.typesafe.ai`：不跟隨 redirect、不走 proxy，
整體時限 1.5 秒；連續失敗 3 次後停用 10 分鐘。任何錯誤都會放行 prompt，
不注入任何內容。

遮罩不是完整 DLP：通過檢查的 prompt 文字仍會送到 TypeSafe，其保留與訓練
政策未經查證。只在允許這項資料流的 session 啟用。log 位於
`~/.local/state/miyago/jev/pilotfish-route.jsonl`，只記錄判斷類別與分數，
不記錄 prompt、ID 或回應原文。

測試：`python3 -m unittest discover -s shared/jev/tests`，只使用本機 stub，
不連網。

## Runtime mapping

| Runtime | jev-browser | Reticle | compaction |
| --- | --- | --- | --- |
| Claude | MCP | MCP | 既有 hooks；Jev shadow only |
| Codex | MCP | MCP | 既有 hooks；Jev shadow only |
| AGY | MCP | MCP | 既有 hooks；Jev shadow only |
| Pi | CLI/library skill | CLI/library skill | extension 後續接入 |

## Requirements

- Node.js 20.11+；Reticle 官方目前要求此版本。
- AGY 需支援 `agy mcp add/list`；MCP registry 由 `setup_jev.sh` 管理。
- `jev-browser-mcp.sh` 只把 `TYPESAFE_API_KEY` 注入 MCP child；Claude Stop shadow
  則使用 Claude process 繼承的環境變數。Stop hook 本身不讀取 secret store。
- Reticle 另需在每個要驗證的 web/desktop project 執行 `npx @reticlehq/server init`。

## Apply

先看變更：

```sh
bash script/common/setup_jev.sh --dry-run
```

確認後才寫入使用者層的 Claude/Codex/AGY MCP registry：

```sh
bash script/common/setup_jev.sh --apply
```

停用：

```sh
claude mcp remove jev-browser
claude mcp remove reticle
codex mcp remove jev-browser
codex mcp remove reticle
agy mcp remove jev-browser
agy mcp remove reticle
```

AGY 的 `jev-tools` skill 與 permission 由 `setup_gemini.sh` 安裝；
`setup_jev.sh` 不會寫入 key，也不會自動執行 Reticle project init。`sec` 與
KeePassXC 是不同 secret store；要使用 `sec`，先在 `sec edit` 加入
`typesafe.api_key`，再執行 `sec reload`。
