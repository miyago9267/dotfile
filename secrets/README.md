# Secrets Management

使用 age + sops 管理本機開發環境中的 token 和 API key。
加密後的 `tokens.enc.yaml` 可以上版控；換機器只需安全地帶一把 age
private key (`~/.age/key.txt`)。

## 初始化

```bash
# 1. 安裝 age + sops
bash script/common/install_sops.sh

# 2. 產生 age key pair（如果還沒有的話）
sec init

# 3. 用編輯器填入 secrets
sec edit
```

`sec init` 會自動產生 `~/.age/key.txt` 並將 public key 寫入
`secrets/.sops.yaml`。

## Bundle 格式

`tokens.enc.yaml` 解密後採用「服務 → secret 名稱」兩層結構。實際檔案由
SOPS 加密，以下只展示編輯時的形狀：

```yaml
typesafe:
  api_key: <TypeSafe API key>
github:
  token: <GitHub token>
cloudflare:
  api_token: <Cloudflare API token>
```

它會產生以下環境變數：

| YAML path | 環境變數 |
| --- | --- |
| `typesafe.api_key` | `TYPESAFE_API_KEY` |
| `github.token` | `GITHUB_TOKEN` |
| `cloudflare.api_token` | `CLOUDFLARE_API_TOKEN` |

命名規則：

- 第一層使用服務名稱，例如 `typesafe`、`github`。
- 第二層使用用途名稱，例如 `api_key`、`token`。
- 只使用兩層和單行純文字；不要放多行 JSON、憑證檔或大型物件。
- 非 secret 設定不要放進 bundle，放在一般設定檔。
- Production 或高權限 key 優先留在 KeePassXC、CI secret 或其他受控來源。

`secrets/tokens.example.yaml` 提供不含 secret 的結構範例。

## 新增 Secret

```bash
# 開啟加密檔案編輯
sec edit

# 在對應分類下加入 key-value，例如：
# typesafe:
#   api_key: <在本機編輯器貼入>
# github:
#   token: <在本機編輯器貼入>

# 儲存後 sops 會自動加密
```

編輯完成後重新產生本機快取：

```bash
sec reload
source ~/.env.secrets
```

不要把同一把 key 同時放在 KeePassXC 和這個 bundle；選一個來源，避免
rotation 後兩邊不同步。

## 換機器

```bash
# 1. 將舊機器的 ~/.age/key.txt 複製到新機器
scp old-machine:~/.age/key.txt ~/.age/key.txt
chmod 600 ~/.age/key.txt

# 2. clone dotfile repo，執行安裝
bash setup.sh

# 3. 重新產生快取並載入
sec reload
source ~/.env.secrets
```

## 常用指令

| 指令 | 說明 |
| --- | --- |
| `sec edit` | 編輯加密的 secrets 檔案 |
| `sec reload` | 刪除快取並重新解密 |
| `sec list` | 只列出 secret 名稱，不顯示 value |
| `sec status` | 檢查 age、sops、key、cache 與加密檔狀態 |

`sec reload` 是獨立程序，只負責重建 cache，不能修改呼叫它的 shell。Zsh
使用者可在目前 shell 執行 `source ~/.env.secrets`，或使用載入後提供的
`secrets-reload` function 同時重建並載入。

## 快取機制

解密後的明文快取在 `~/.env.secrets`（權限 600），不會進版控。

dotfile 管理的互動式 Zsh 會載入 `config/zsh/.zshrc.d/secrets.zsh`：有 age key、
SOPS 和加密 bundle 時，它會 source 新鮮快取；快取過期時先重建，再 source
到該 shell。這會把成功解析的 bundle entries 匯出給該 shell 和 child
processes。key 不會以明文寫在 `.zshrc`，但目前載入範圍是整個互動式 Zsh。

需要單一 child process 使用單一 secret 時，改用 KeePassXC broker，例如
`agent-secret run typesafe-api -- <command>`。不要把同一把 key 同時放進 KeePassXC
和 SOPS bundle；不要用 `sec show` 或 `sec export` 做一般診斷，兩者會輸出明文。

## `sec` 的 PATH

`sec` 是 repository 的 `script/utils/sec`。dotfile 的
`config/zsh/.zshrc.d/utils.zsh` 會在目錄存在時，把 `$HOME/dotfile/script/utils`
加到 `PATH`。在 Zsh 中，小寫 `path` 是與大寫 `PATH` 綁定的陣列，不是指令。

```zsh
whence -v sec
print -rl -- $path
```

修改 PATH snippet 後，可重開 Terminal 或執行 `source ~/.zshrc` 載入設定；這也
會重新執行上面的 secrets loader。
