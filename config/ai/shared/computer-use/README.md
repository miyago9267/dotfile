# Computer use 共用 MCP launchers

這個目錄放兩個 stdio MCP server 的 launcher，各自獨立註冊：

| Server | Launcher | 內容 |
|--------|----------|------|
| `open-computer-use` | `computer-use-mcp.sh` | 第三方 driver 的原始九個工具（S1） |
| `desktop-ops` | `desktop-ops-mcp.sh` | 疊在 driver 上的 policy／Touch ID／不搶畫面層，另有可開關的 Jev 路徑（見文末） |

## open-computer-use

把第三方 macOS computer-use driver `open-computer-use@0.3.6` 以同一個 stdio MCP
server（名稱 `open-computer-use`）提供給 Claude Code、Codex、agy 與日常 opencode。

- `computer-use-mcp.sh`：launcher。啟動前檢查 package 版本（讀 `package.json`，
  不執行 binary）、bundled app 的 `TeamIdentifier`（`J9P29FA5BX`）與
  `codesign --verify --strict`，清掉所有 `OPEN_COMPUTER_USE_*` 環境變數，最後只
  `exec <binary> mcp`。任一檢查不過就 fail closed（非零 exit、一行 stderr、
  不 exec）。
- `tests/test_computer_use_mcp.sh`：全部用 stub，不碰真的 binary 或 GUI。

## 安裝與註冊

新機器從 dotfile 加一個 private repo 就能裝起來。`bash setup.sh` 選單的
「Computer use MCP (open-computer-use + desktop-ops)」（macOS，標成 optional，所以 `--all` 不會跑，
`--everything` 才會）等於依序跑 `--install` 與 `--apply`；也可以手動分開跑：

```sh
script/common/setup_computer_use.sh --dry-run --install   # 只印安裝計畫，不改東西、不連網
script/common/setup_computer_use.sh --install             # 安裝 driver、service repo、相依套件、helper
script/common/setup_computer_use.sh                       # 註冊的 dry-run（預設，不改任何東西）
script/common/setup_computer_use.sh --apply               # 註冊四個 runtime
script/common/setup_computer_use.sh --remove              # 移除
bash config/ai/shared/computer-use/tests/test_computer_use_mcp.sh
```

`--install` 不註冊任何東西，可以重複跑，已經到位的步驟會跳過；不用 sudo，也不讀任何 secret。
pin 都寫在 `setup_computer_use.sh` 開頭的變數裡：

1. Driver：已裝好 pin 的版本且驗證通過就不動。否則先比對 `npm view open-computer-use@0.3.6
   dist.integrity` 與 pin，不同就拒絕安裝；相同才跑 `npm install -g --ignore-scripts`，裝完檢查
   `TeamIdentifier`、`codesign --verify --strict` 與 `spctl --assess`（要是 `Notarized Developer
   ID`）。任何一項不過就停在這裡，不會往下做。
2. Service repo（`--server desktop-ops` 或 `all`）：`~/Project/Active/Tools/desktop-ops` 不存在就
   clone `git@github.com:miyago9267/desktop-ops.git`（private，走你自己的 ssh／`gh` 設定）並
   `checkout --detach` 到 pin 的 commit。已存在時 `origin` 必須是這個 repo（ssh 或 https 寫法）；
   pin 是 HEAD 或 HEAD 的祖先就完全不碰（開發用的 checkout）；HEAD 落後時只有在 work tree 乾淨
   才 `fetch` 加 `merge --ff-only`，有未 commit 的東西就停下來請你自己處理。不會 reset、clean
   或 stash。
3. `node_modules` 不在或 `bun.lock` 比較新時跑 `bun install --frozen-lockfile --ignore-scripts`；
   helper binary 不在或比 Swift source 舊時跑 `helper/build.sh`。
4. 缺 `npm`、`git`、`bun`、`swiftc`、`codesign` 或 `spctl` 時，在做任何事之前就停，每個缺的工具
   印一行怎麼裝。

裝完還要自己做的事（`--install` 結尾也會印）：`open-computer-use doctor` 授權 Accessibility 與
Screen Recording、用既有的 secrets 流程提供 `TYPESAFE_API_KEY`、跑 `--apply`、重啟 agent session。

`--server open-computer-use|desktop-ops|all`（預設 `all`）決定動哪一個 server；兩個 server 的
註冊與移除互不影響。只動 S1 時加 `--server open-computer-use`：

```sh
script/common/setup_computer_use.sh --server open-computer-use --apply
script/common/setup_computer_use.sh --server desktop-ops --remove
bash config/ai/shared/computer-use/tests/test_setup_computer_use.sh   # 用 stub CLI 與暫存 HOME，不碰真的設定
```

`--apply` 會先檢查所選 server 的 launcher 都可執行，而且它啟動需要的東西都在：
`open-computer-use` 要有 pin 版本的 package；`desktop-ops` 要有 repo、相依套件、helper binary 與
bun。有任何一個不行就在寫入之前停下來，並提示先跑 `--install`。

`--apply` 會寫入：

- Claude：`claude mcp add --scope user`（`~/.claude.json`）。
- Codex：script 自己在 `~/.codex/config.toml` 結尾 append 一段有 begin/end marker
  的 `[mcp_servers.open-computer-use]` 文字 block（atomic 寫入、保留 file mode）。
  不用 `codex mcp add/remove`，因為它們會重新序列化其他 `mcp_servers.*` table。
  table 已存在但沒有 marker，或 marker 內的內容不同時，Codex 這步會停下來不動檔案。
- agy：`agy mcp add`（`~/.gemini/config/mcp_config.json`）。
- opencode：`config/opencode/opencode.json` 的 `mcp.open-computer-use` 與
  `permission."open-computer-use_*": "ask"`。

有 runtime 被跳過時 script 以 exit 3 結束，其他 runtime 照常處理。

## Binary 解析順序

nvm 是 lazy-load，agent 的 `PATH` 通常沒有 nvm 的 bin 目錄，所以 launcher 依序找：

1. `COMPUTER_USE_MCP_BIN`（test seam，必須是絕對路徑）。
2. `PATH` 上的 `open-computer-use`，而且要是絕對路徑的可執行檔。
3. `$HOME/.nvm/versions/node/*/bin/open-computer-use` 中 package 版本等於 pin 的
   最新 node 版本。

都找不到就 exit 127。bin script 是 `#!/usr/bin/env node`：找到的 entry 旁邊有
`node` 時，launcher 把那個目錄放到 child `PATH` 最前面；旁邊沒有、`PATH` 上也沒有
`node` 就 fail closed。

## 注意

- `claude mcp list` 會對每個 server 做 health check，也就是會真的啟動這個 server。
  只想看註冊狀態時，用 `COMPUTER_USE_MCP_BIN=/nonexistent claude mcp list` 讓
  launcher fail closed。
- Codex 之後若自己重寫 `config.toml` 而把 marker 註解丟掉，`--remove` 會改用
  `codex mcp remove open-computer-use` 並印出警告；這時檔案回不到 apply 前的 bytes。

## 已接受的殘餘風險

launcher 是 hygiene（版本 pin、signer 檢查、env scrub），不是 security boundary：

- 真正的邊界是 macOS TCC（Accessibility / Screen Recording）授權；授權後，任何
  能啟動這個 server 的本機 agent 都能操作整台 Mac。
- Codex 呼叫 MCP tool 沒有 approval prompt；opencode 有 `ask` rule；Claude 與 agy
  用各自預設的 tool 權限流程。
- 每次啟動會跑 `codesign -dv` 比對 `TeamIdentifier` 與 `codesign --verify --strict`；
  notarization（`spctl`）只在 `--install` 時檢查。`--install` 比對的是 registry 回報的 integrity，
  `npm` 實際下載的內容由 npm 自己驗。Node 的 launcher script
  （`bin/`、`scripts/`）不在 app bundle 的簽章範圍內，只受版本 pin 保護。
- `COMPUTER_USE_MCP_BIN`、`COMPUTER_USE_MCP_CODESIGN` 是 test seam；能改 agent
  環境變數的人可以用它們繞過檢查。

## Kill switch

- 最快：System Settings > Privacy & Security，把 Open Computer Use 的
  Accessibility 與 Screen Recording 關掉。
- 讓 launcher 一律 fail closed：`npm rm -g open-computer-use`。
- 全部取消註冊：`script/common/setup_computer_use.sh --remove`。

## Rollback

```sh
script/common/setup_computer_use.sh --remove            # 兩個 server 都移除
npm rm -g open-computer-use
git -C ~/dotfile status --porcelain 'config/opencode*'   # 應為空
```

`--remove` 只刪 `--apply` 加的東西：`config/opencode/opencode.json` 與
`~/.codex/config.toml`（marker 還在時）都會回到 apply 前的 bytes。marker 不在時見
上面「注意」。

## desktop-ops

`desktop-ops` 是 `~/Project/Active/Tools/desktop-ops` 的 MCP server，以 MCP client 的身分啟動
上面的 `computer-use-mcp.sh`，自己不碰 native binary。五個不呼叫模型的工具一直都在：
`computer_apps`、`computer_snapshot`、`computer_act`、`computer_run`、`computer_screenshot`。
開關為 `on` 時多四個 Jev 工具：`computer_do`、`computer_check`、`computer_choose`、
`computer_read`，會把畫面文字送到 `api.typesafe.ai`。工具、status、規則與資料界線的說明在該 repo
的 `README.md`。

- `desktop-ops-mcp.sh`：launcher。Jev 路徑的開關是檔案裡唯一的一行
  `DESKTOP_OPS_JEV_PATH=on`（2026-10-05 起的預設，實機驗收已與 Miyago 做完）；先清掉所有繼承來的
  `DESKTOP_OPS_*` 再設定開關、driver 與 policy 路徑，所以呼叫端的環境變數關不掉也開不了 Jev
  路徑，也改不了 helper、driver、policy、state 目錄或 API endpoint。切到 repo 目錄後以 `bun --no-install --no-env-file` 啟動，不轉送
  額外參數。repo、相依套件、helper binary、bun 或 S1 launcher 任何一個不在就 fail closed，而且
  發生在讀任何 key 之前。
  - `off`：從子程序環境移除 `TYPESAFE_API_KEY`，不讀 `~/.env.secrets`，不呼叫 `agent-secret`。
  - `on`：只注入 `TYPESAFE_API_KEY`，來源順序與 `jev-browser-mcp.sh` 相同：`~/.env.secrets`
    （在 subshell 裡讀，其他 secret 不會帶出來）、繼承來的值、`agent-secret run typesafe-api`。
    key 只走環境變數，不進 argv，也不印出來。都拿不到時照樣啟動，Jev 工具回 `no_api_key`。
  - 要關掉 Jev 路徑：手動把那一行改成 `DESKTOP_OPS_JEV_PATH=off`，重啟 client。沒有別的開關，
    環境變數也關不掉。
  - `on` 但拿不到 key：server 照樣啟動，九個工具都列得出來；四個 Jev 工具回 `no_api_key`，
    什麼都不送，另外五個照常運作。
- `policy.json`：只能追加黑名單（`deny_apps`、`deny_app_prefixes`、`deny_hosts`）與不可逆關鍵字
  （`irreversible_keywords`）。底線寫死在程式裡，這個檔放行不了任何東西；檔案不見、壞掉或出現
  別的 key，`desktop-ops` 會拒絕所有 app。
- `tests/test_desktop_ops_mcp.sh`：用假的 repo、假的 bun、假的 secrets 檔與假的 broker 測
  launcher。正式檔案必須是 `on`，`on` 的行為直接對正式檔案測；`off` 的行為用一份只改了開關那
  一行的暫存副本測。

安裝與註冊：

```sh
script/common/setup_computer_use.sh --server desktop-ops --install   # clone／對齊 pin、bun install、build helper
script/common/setup_computer_use.sh --server desktop-ops --apply
bash config/ai/shared/computer-use/tests/test_desktop_ops_mcp.sh
```

注意：

- 會碰真的 app、真的 Touch ID 或真的 TypeSafe API 的檢查列在 repo `README.md` 的「實機檢查」；
  Jev 路徑（9 到 13）還沒做。
- `DESKTOP_OPS_HOME` 是 launcher 的 test seam（repo 位置）；能改 agent 環境變數的人可以用它
  換掉整個 server。
- 直接使用 `open-computer-use` 的原始工具不受 `desktop-ops` 的 policy、Touch ID 與不搶畫面
  規則約束；鎖也只是 advisory。
- opencode 另有 `permission."desktop-ops_*": "ask"`。

Rollback：

```sh
script/common/setup_computer_use.sh --server desktop-ops --remove   # S1 的註冊不動
```

再刪掉 `~/Project/Active/Tools/desktop-ops`、`desktop-ops-mcp.sh` 與 `policy.json`。
