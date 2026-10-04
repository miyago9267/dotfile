# open-computer-use 共用 MCP launcher

把第三方 macOS computer-use driver `open-computer-use@0.3.6` 以同一個 stdio MCP
server（名稱 `open-computer-use`）提供給 Claude Code、Codex、agy 與日常 opencode。

- `computer-use-mcp.sh`：launcher。啟動前檢查 package 版本（讀 `package.json`，
  不執行 binary）、bundled app 的 `TeamIdentifier`（`J9P29FA5BX`）與
  `codesign --verify --strict`，清掉所有 `OPEN_COMPUTER_USE_*` 環境變數，最後只
  `exec <binary> mcp`。任一檢查不過就 fail closed（非零 exit、一行 stderr、
  不 exec）。
- `tests/test_computer_use_mcp.sh`：全部用 stub，不碰真的 binary 或 GUI。

## 安裝與註冊

```sh
npm view open-computer-use@0.3.6 dist.integrity   # 先比對 integrity
npm i -g --ignore-scripts open-computer-use@0.3.6
script/common/setup_computer_use.sh               # dry-run（預設，不改任何東西）
script/common/setup_computer_use.sh --apply       # 註冊四個 runtime
script/common/setup_computer_use.sh --remove      # 移除
bash config/ai/shared/computer-use/tests/test_computer_use_mcp.sh
```

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
  notarization（`spctl`）只在安裝時手動驗過一次。Node 的 launcher script
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
script/common/setup_computer_use.sh --remove
npm rm -g open-computer-use
git -C ~/dotfile status --porcelain 'config/opencode*'   # 應為空
```

`--remove` 只刪 `--apply` 加的東西：`config/opencode/opencode.json` 與
`~/.codex/config.toml`（marker 還在時）都會回到 apply 前的 bytes。marker 不在時見
上面「注意」。
