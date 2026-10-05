---
id: spec-secrets-management
title: Dotfile Secret 管理（age + sops）
status: in-progress
created: 2026-03-19
updated: 2026-10-05
author: Miyago
approved_by:
tags: [secrets, age, sops, security, cross-platform]
priority: high
---

<!-- markdownlint-disable-next-line MD025 -->
# Dotfile Secret 管理（age + sops）

## Background

環境變數中的 token/key 無法上版控，換機器時容易遺失。
Miyago 目前沒有專門的密碼管理器，token 散落各處，常常忘記。

需要一個方案讓 secret 安全地跟著 dotfile repo 走。

## Requirements

1. Token/API key 加密後可安全 commit 進 dotfile repo
2. 換機器時只需攜帶一把 age private key 即可解密所有 secret
3. 日常使用低摩擦 -- 可由使用者顯式載入解密後的環境變數
4. 支援 macOS 和 Linux（Windows 為 nice-to-have）
5. 新增/修改 secret 的操作簡單直覺

## Non-goals

- 不做團隊多人共享 secret（只有 Miyago 自用）
- 不整合雲端密碼管理服務
- 不重建 KeePassXC 式的 vault 或 master password cache daemon。`agent-secret` 自
  2026-10-05 起改以 macOS Keychain 與 sops + age 為 backend（ADR-5）；既有的
  KeePassXC 資料與舊 broker 原樣保留，不搬移也不刪除
- 高權限或正式環境 secret 不放進 `tokens.enc.yaml` 這個本機開發 bundle

## Architecture

### 工具選擇

| 工具 | 用途 |
| --- | --- |
| `age` | 加密/解密引擎，取代 GPG |
| `sops` | 結構化 secret 編輯器，支援 yaml/json/env |

### 目錄結構

```text
secrets/
  .sops.yaml              # sops 設定：指定 age public key 作為 recipient
  tokens.enc.yaml         # 加密的 secret 檔（安全上版控）
  README.md               # 使用說明

~/.age/
  key.txt                 # age private key（絕對不上版控）

~/.env.secrets            # 解密後的 env 輸出（gitignored，runtime 用）
```

### 檔案格式

`tokens.enc.yaml` 解密後的邏輯結構：

```yaml
github:
  token: <encrypted value>
  packages_token: <encrypted value>
openai:
  api_key: <encrypted value>
typesafe:
  api_key: <encrypted value>
```

`sops` 的 metadata 會由工具放在加密檔案中，不列入這個邏輯 schema。

Export contract：

- `github.token` 變成 `GITHUB_TOKEN`。
- `openai.api_key` 變成 `OPENAI_API_KEY`。
- `typesafe.api_key` 變成 `TYPESAFE_API_KEY`。
- 目前 parser 只支援兩層 YAML 和單行 scalar value。
- 第二層不要重複第一層前綴，例如不要寫 `github.github_token`。

### 工作流程

#### 初始化（一次性）

```text
1. brew install age sops
2. sec init
3. 用 `sec edit` 編輯 `secrets/tokens.enc.yaml`
4. 確認 `.gitignore` 排除 `~/.env.secrets`
```

#### 新增/編輯 secret

```bash
sec edit
```

#### Shell 載入

顯式載入：

```bash
sec reload
source ~/.env.secrets
```

不要在每個 shell 啟動時無條件 source 全部 secret；需要最小權限時，改用
`agent-secret` 的 process injection（ADR-5）。

#### 換機器

```text
1. git clone dotfile repo
2. 從安全管道（AirDrop / USB / 1Password）複製 ~/.age/key.txt
3. 跑 setup script
4. 執行 `sec reload`，只在需要的 shell 內 source `~/.env.secrets`
```

## ADR

### ADR-1: 選擇 age 而非 GPG

- age 設計簡單，一個 key file 搞定
- GPG 需要管理 keyring、trust model、subkey，過度複雜
- age key 是純文字，備份容易

### ADR-2: 效能策略 -- 解密快取

shell 啟動時每次跑 `sops -d` 會有約 200-300ms 延遲。
採用快取策略：

- `sec reload` 時解密寫入 `~/.env.secrets`
- 由使用者在需要的 shell 內 source 快取檔
- 提供 `sec reload` 手動刷新
- 快取檔權限設為 `600`

### ADR-3: 加密檔案格式選 YAML

- YAML 支援巢狀分類（github/openai/cloud）
- sops 對 YAML 的支援最成熟
- 比 .env 格式更有組織性

### ADR-4: Bundle 與 `agent-secret` 的分工

2026-10-05 改寫：原本的分工對象是 KeePassXC `agent-secret`，由 ADR-5 取代。

- 本機開發、低風險、需要多個 key 一次載入 shell 的工作使用 `tokens.enc.yaml`
  bundle（`sec reload` + 顯式 source）。
- 需要 process-level injection 的 key 使用 `agent-secret run <alias> -- <command>`：
  一次只把一個值注入一個被允許的指令。
- 高權限或正式環境的 key 用 `keychain-only` tier，只存在 macOS Keychain，不進任何
  sops 檔，也不進 dotfile repo。
- 同一把 key 不同時放在兩個來源，避免 rotation 後不同步。`agent-secret put` 會在
  sops 已有同名項目時拒絕，`agent-secret doctor` 會列出兩邊都有的 alias。

### ADR-5: `agent-secret` 改用 Keychain 優先、sops + age 次之（2026-10-05）

決定（Miyago 原話）：「那就是 keychain，然後用 1 來當主力，只是就是如果 keychain
有就會優先用 keychain」。其中的「1」是當時選項裡的 sops + age。

落實方式：

- Broker 是 `script/utils/agent-secret`，進 dotfile 版控，macOS 與 Linux／WSL 共用；
  同目錄的 `agent-secret2` 是指向它的 symlink 別名。2026-10-05 起 `~/bin/agent-secret`
  與 `~/bin/agent-secret2` 都指向新 broker；舊的 KeePassXC 版腳本仍在
  `~/.codex/skills/miyago-secret-vault/scripts/agent-secret`，可經
  `~/bin/agent-secret-keepassxc` 使用，作為觀察期的備份。過渡期已結束：原本檔名帶 `2`
  是為了避免 `script/utils`（在 `PATH` 上）的 `agent-secret` 讓既有 wrapper 的
  `command -v agent-secret` 提前解析到新 broker，切換後不再有此顧慮。
- Alias 表固定在 `~/.config/agent-secret/aliases.tsv`（不進版控，範例見
  `script/utils/agent-secret.aliases.example.tsv`），格式
  `alias|tier|env_name|allowed_commands`。家目錄從帳號資料庫取得，不看 `HOME`；
  表與 backend 的路徑都由它推導，沒有任何環境變數開關。
- 對呼叫端環境的隔離：shebang 是 `#!/bin/bash -p`（不 source `BASH_ENV`、不匯入
  環境裡的函式），不在 privileged 模式就拒絕執行，所以不能用 `bash <script>` 啟動；
  `PATH` 在開頭換成固定的系統路徑，呼叫端的 `PATH` 只在最後 `exec` 被允許的指令時
  還給它；取得值之後只剩 `export` 與 `exec` 兩步。
- 解析順序：先查 Keychain（generic password，service `agent-secret`，account 為
  alias）；只有確認是「找不到」（`security` exit 44）才查
  `secrets/agent.enc.yaml` 內以 alias 為 key 的值。上鎖、使用者拒絕、-25308、
  解密失敗等其他錯誤一律 fail closed，不落到下一層。每次在 stderr 印 alias 與
  使用的 backend，不印值。
- 兩個 tier：
  - `keychain-only`：只查 Keychain，永不查 sops；非 macOS 上 fail closed。意義只有
    「值只存在這台 Mac 的 login Keychain，不進 repo、不同步到其他機器」。它不提供
    讀取時的確認：`put` 以空的信任清單（`-T ""`）建立項目，但 2026-10-05 實測不會跳
    確認視窗（見「尚未處理」）。真正的限制只來自 `allowed_commands` 列出的絕對路徑。
  - `sops`：主力。值放在 `secrets/agent.enc.yaml`，跟著 dotfile repo 走；Keychain
    有同名項目時當成本機 override 優先使用。Linux／WSL 沒有 Keychain，直接查 sops。
- 指令限制一句話：有列出絕對路徑才有限制；`*` 與簡易模式（ADR-6）都沒有限制。
  - `allowed_commands` 是絕對路徑清單時，broker 把指令解析成絕對路徑後比對，不符
    即拒；`env`、`printenv`、shell、常見直譯器即使列在清單內也拒絕（內建拒絕清單）。
  - `allowed_commands` 是 `*` 時不檢查指令，也不套內建拒絕清單。那份清單本來就擋
    不住包裝型或能讀環境的工具（實測 `caffeinate printenv`、`jq -rn '$ENV.X'`、
    `git -c alias.x='!printenv X' x` 都印得出值），保留只會造成「看起來有限制」的
    錯覺；舊 broker 的 alias 以 `*` 移植過來後，`env JEV_ENABLE=1 codex`、`npx ...`
    這類既有呼叫也必須照常可用。`doctor` 會列出哪些 alias 是 `*`。
- 值只經過 stdin、pipe 與 `export`，不進任何行程的 argv。寫入 Keychain 走
  `security -i` 從 stdin 讀指令搭配 `-X <hex>`，單一值上限 1024 個可列印 ASCII
  字元（`security -i` 的行緩衝限制）；更長或多行的值放 sops。
- 不重建 cache daemon：Keychain 的授權由 macOS 管，sops 每次解密單一 key。

`agent.enc.yaml` 與 `tokens.enc.yaml` 分開的原因：

- `tokens.enc.yaml` 會被 `sec reload` 整份解密成 `~/.env.secrets` 再 source 進
  shell，`sec show`／`sec export` 也是整份輸出。agent 用的值放進去，就等於每個
  shell 與每個子行程都拿得到，process-level injection 失去意義。
- 兩者 schema 不同：`tokens.enc.yaml` 是兩層 YAML 加大寫 export contract；
  `agent.enc.yaml` 是一層的 `alias: value`，由 broker 以 `--extract` 單獨取一個 key。
- 權限邊界不同：Claude 的 `secret-guard` hook 擋 `sec show`、`sec export`、
  `sec edit`、`agent-secret edit`，以及任何目標在 `~/dotfile/secrets/` 的 `sops`；
  agent 只能透過 broker 拿到單一值。

### ADR-6: `agent-secret` 的簡易模式（2026-10-05）

決定（Miyago 原話）：「等一下太麻煩了吧，我只想存進我的keychain然後讓agent可以調用
而已，不就一個key name一個value的事情嗎」。同日另一則指示：「我想要從agent-secret
移植到2代了，舊的東西幫我搬，同時順便做簡單版後安裝給agent使用」。

規格：

- 命名空間由名稱的寫法決定，不會重疊：大寫環境變數寫法（`^[A-Z][A-Z0-9_]*$`）是
  簡易模式，不需要登記，名稱本身就是注入的環境變數名稱；小寫加 `-`
  （`^[a-z0-9][a-z0-9-]*$`）是 ADR-5 的已登記 alias，行為不變。`env_name` 的拒絕
  清單（`PATH`、`HOME`、`LD_*`、`DYLD_*` 等）同樣套用在簡易模式的名稱上。
- `put NAME`：從 stdin 讀值寫進 Keychain（service `agent-secret`、account 為 NAME），
  一般 ACL，不加 `-T ""`；值的限制與已登記的 `put` 相同。
- `run NAME -- <command>`：解析順序同 `sops` tier（Keychain 優先，確認找不到才查
  `agent.enc.yaml` 內以 NAME 為 key 的值，其他錯誤 fail closed）。不讀 alias 表，
  所以表不存在或是空的也能用。不檢查 `allowed_commands`，也不套內建拒絕清單，
  `sh -c '... $NAME ...'` 可以用。
- `rm NAME`：刪除簡易模式在 Keychain 的項目；對已登記的 alias 會拒絕。
- `list`：分成 registered 與 simple 兩段。簡易模式的名稱來自 `security dump-keychain`
  （不帶 `-d`，只輸出屬性、不讀密碼、不跳授權視窗）篩出 service 完全相同的 generic
  password，加上 `agent.enc.yaml` 裡大寫的頂層 key。`doctor` 列出簡易模式的數量。
- 非 macOS：簡易模式只走 sops；`put` 與 `rm` 拒絕並說明要用 `edit`。
- Broker 對呼叫端環境的隔離（`-p`、固定 `PATH`、家目錄來源、值不進 argv）對兩種
  模式都一樣。

取捨：

- 簡易模式下 agent 可以讀到值：取得值的指令沒有限制，`sh -c 'echo $NAME'` 就印得
  出來。風險等級與既有的 ambient export（`source ~/.env.secrets`）相同，但範圍從
  「整個 shell 的生命週期、所有子行程」縮小到「單一指令的執行期間」，而且每次取用
  都在 stderr 留下名稱與 backend。
- 嚴格模式保留給 production 與高權限項目：在 alias 表登記，並在 `allowed_commands`
  列出明確的絕對路徑。限制只有「只有指定程式拿得到值」這一道；`keychain-only` 另外
  保證值不進 sops 與 repo，但不提供讀取時的確認（2026-10-05 實測不會跳確認視窗）。
  `keychain-only` 加 `*` 沒有任何讀取限制，`doctor` 會對這種組合提出警告。
- `secret-guard` hook 不為簡易模式放寬任何規則；它擋的是直接讀 Keychain 與解密
  `~/dotfile/secrets/`，不看 `agent-secret run` 後面接什麼指令。

### 2026-10-05 搬移紀錄

從舊 KeePassXC broker 搬到新 broker 的 6 個 alias（名稱與環境變數名稱沿用）：

| alias | tier |
| --- | --- |
| `gitlab-aluo` | `sops` |
| `gitlab-dunqian` | `sops` |
| `cloudflare-dunqian-itrd` | `sops` |
| `github-personal`（只允許 `/opt/homebrew/bin/gh`） | `sops` |
| `typesafe-api` | `sops` |
| `production-gcp-openvpn` | `keychain-only` |

另有 `claude-eval`（`keychain-only`）與 `redmine` 登記在新 broker，不屬於這次搬移。

驗證方式：在不顯示值的前提下比對新舊兩邊的值。

- 4 個比對相同。
- `github-personal` 以功能性檢查確認可用。
- `production-gcp-openvpn` 已於 2026-10-05 比對相同。原本以為這一項要等 Miyago
  按 Keychain 的確認，實際上 `keychain-only` 的讀取不會跳確認視窗（見「尚未處理」）。
- KeePassXC 的資料與舊腳本在觀察期內保留，不刪除。

### 尚未處理

- `keychain-only` 沒有讀取確認。2026-10-05 實測：`claude-eval` 與
  `production-gcp-openvpn`（都經 broker 的 `put` 以 `-T ""` 建立）在無人看管下被
  `agent-secret run` 讀取四次，全部成功，沒有跳任何 macOS 確認視窗。推測原因（未驗證）：
  項目由 `/usr/bin/security` 建立、也由它讀取，被視為建立者自己存取。原 Plan 的 F6
  處置（以 `-T ""` 區分 broker 與 agent）因此實測無效；Miyago 當日選擇接受現狀並把
  文件改對。目前唯一的讀取限制是 `allowed_commands` 列出的絕對路徑。
- `config/zsh/.zshrc.d/secrets.zsh` 在 shell 啟動時自動 source `~/.env.secrets`，
  與本 spec「Shell 載入」的規定（不要無條件 source 全部 secret）衝突。
- age 私鑰仍是 `~/.age/key.txt` 明文檔；改由 Keychain 提供尚未做。
- 寫快取 `~/.env.secrets` 時沒有跳脫值（`sec reload` 直接輸出 `export K="值"`）：
  值含 `"`、`$` 或反引號時，source 會執行或截斷內容。
- `agent-secret` 的殘餘風險：被允許的指令會繼承呼叫端的環境，包含 `export -f`
  匯出的函式與直譯器的啟動變數。實測：allowlist 內的指令如果是 bash 腳本，呼叫端
  匯出的 `printf` 函式會在那個腳本裡執行，並記到注入的值；`NODE_OPTIONS`、
  `PYTHONSTARTUP` 這類變數同理（推論，未實測）。Broker 本身不受影響（`-p` 不匯入
  函式），但 `allowed_commands` 限制的是「執行哪個程式」，不是「那個程式在什麼環境
  下跑」。這屬於主動規避，超出目前的威脅模型（合作型 agent 的意外外洩），broker
  不為此清理子行程的環境。

## Phase 計畫

### Phase 1: 基礎建設

- 安裝腳本（age + sops）
- 初始化 age key pair
- 建立 `secrets/` 目錄和 `.sops.yaml`
- `.gitignore` 更新

### Phase 2: Shell 整合

- `secrets.zsh` 載入模組
- 解密快取機制
- `sec reload` / `sec edit` command workflow

### Phase 3: Setup 整合

- `setup.sh` / `setup.ps1` 整合安裝流程
- 首次 setup 引導建立或匯入 age key
- 換機器的 onboarding 體驗

## Risks

| 風險 | 影響 | 緩解 |
| --- | --- | --- |
| age key 遺失 | 所有 secret 無法解密 | key 備份到 macOS Keychain 或實體 USB |
| 不小心 commit 解密後的檔案 | secret 外洩 | `.gitignore` + git hook 檢查 |
| sops 版本升級改格式 | 無法解密舊檔案 | pin sops 版本，定期驗證 |
