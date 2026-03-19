# Secrets Management

使用 age + sops 管理環境變數中的 token 和 API key。
換機器只需帶一把 age private key (`~/.age/key.txt`)。

## 初始化

```bash
# 1. 安裝 age + sops
bash script/common/install_sops.sh

# 2. 產生 age key pair（如果還沒有的話）
secrets-init

# 3. 用編輯器填入 secrets
secrets-edit
```

`secrets-init` 會自動產生 `~/.age/key.txt` 並將 public key 寫入 `secrets/.sops.yaml`。

## 新增 Secret

```bash
# 開啟加密檔案編輯
secrets-edit

# 在對應分類下加入 key-value，例如：
# github:
#   token: ghp_xxxxxxxxxxxx
# openai:
#   api_key: sk-xxxxxxxxxxxx

# 儲存後 sops 會自動加密
```

## 換機器

```bash
# 1. 將舊機器的 ~/.age/key.txt 複製到新機器
scp old-machine:~/.age/key.txt ~/.age/key.txt
chmod 600 ~/.age/key.txt

# 2. clone dotfile repo，執行安裝
bash setup.sh

# 3. 開新 shell 或手動載入
secrets-reload
```

## 常用指令

| 指令 | 說明 |
|------|------|
| `secrets-edit` | 編輯加密的 secrets 檔案 |
| `secrets-reload` | 刪除快取，重新解密並載入 |
| `secrets-init` | 初始化 age key pair + 更新 .sops.yaml |

## 快取機制

解密後的明文快取在 `~/.env.secrets`（權限 600），不會進版控。
當 `tokens.enc.yaml` 比快取新時，會自動重新解密。
