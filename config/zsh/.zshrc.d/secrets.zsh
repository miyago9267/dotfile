# Secrets management -- age + sops 整合
# 解密 tokens.enc.yaml 並 export 環境變數

# -- 前置檢查 --
# age key 不存在就靜默跳過
[ ! -f "$HOME/.age/key.txt" ] && return 0

# sops 不可用就跳過
command -v sops >/dev/null 2>&1 || return 0

# -- 路徑設定 --
# 找到 dotfile repo 下的加密檔
_secrets_dotfile="$HOME/dotfile"
_secrets_enc="${_secrets_dotfile}/secrets/tokens.enc.yaml"
_secrets_cache="$HOME/.env.secrets"

# 加密檔不存在就跳過
[ ! -f "$_secrets_enc" ] && { unset _secrets_dotfile _secrets_enc _secrets_cache; return 0; }

# -- 快取策略 --
# 如果快取存在且比加密檔新，直接 source
if [ -f "$_secrets_cache" ] && [ "$_secrets_cache" -nt "$_secrets_enc" ]; then
  source "$_secrets_cache"
else
  # 重新解密並產生快取
  export SOPS_AGE_KEY_FILE="$HOME/.age/key.txt"
  _secrets_raw="$(sops -d "$_secrets_enc" 2>/dev/null)" || {
    unset _secrets_dotfile _secrets_enc _secrets_cache _secrets_raw
    return 0
  }

  # 解析 YAML 輸出為 export KEY=VALUE 格式
  # 支援巢狀一層: category.key = value -> CATEGORY_KEY=value
  printf '%s\n' "$_secrets_raw" | awk '
    /^[a-zA-Z_][a-zA-Z0-9_]*:/ {
      # 頂層 key
      gsub(/:.*/, "")
      prefix = toupper($0)
      next
    }
    /^    [a-zA-Z_][a-zA-Z0-9_]*:/ {
      # 第二層 key: value
      gsub(/^[[:space:]]+/, "")
      split($0, kv, ": ")
      key = toupper(kv[1])
      gsub(/:$/, "", key)
      val = kv[2]
      # 移除 YAML 引號
      gsub(/^["'"'"']|["'"'"']$/, "", val)
      if (val != "" && val != "{}" && val != "[]") {
        printf "export %s_%s=%s\n", prefix, key, "\"" val "\""
      }
    }
  ' > "$_secrets_cache"

  chmod 600 "$_secrets_cache"
  source "$_secrets_cache"
  unset _secrets_raw
fi

unset _secrets_dotfile _secrets_enc _secrets_cache

# -- Helper functions --

# 編輯加密的 secrets 檔案
secrets-edit() {
  local _dotfile="$HOME/dotfile"
  local _enc="${_dotfile}/secrets/tokens.enc.yaml"
  export SOPS_AGE_KEY_FILE="$HOME/.age/key.txt"
  sops "$_enc"
}

# 刪除快取，重新解密並 source
secrets-reload() {
  rm -f "$HOME/.env.secrets"
  source "${0:a}"
}

# 初始化 age key pair + 更新 .sops.yaml
secrets-init() {
  local _dotfile="$HOME/dotfile"

  # 產生 age key pair（如果不存在）
  if [ ! -f "$HOME/.age/key.txt" ]; then
    mkdir -p "$HOME/.age"
    age-keygen -o "$HOME/.age/key.txt" 2>&1
    chmod 600 "$HOME/.age/key.txt"
    echo "age key pair 已產生: ~/.age/key.txt"
  else
    echo "age key 已存在: ~/.age/key.txt"
  fi

  # 取得 public key
  local _pubkey
  _pubkey="$(grep -o 'age1[a-z0-9]*' "$HOME/.age/key.txt" | head -1)"
  if [ -z "$_pubkey" ]; then
    echo "錯誤: 無法從 ~/.age/key.txt 取得 public key"
    return 1
  fi

  echo "Public key: $_pubkey"

  # 更新 .sops.yaml
  local _sops_cfg="${_dotfile}/secrets/.sops.yaml"
  cat > "$_sops_cfg" <<EOF
creation_rules:
  - age: "${_pubkey}"
EOF
  echo ".sops.yaml 已更新"

  # 如果加密檔還是明文模板，進行首次加密
  local _enc="${_dotfile}/secrets/tokens.enc.yaml"
  if [ -f "$_enc" ] && ! grep -q "sops:" "$_enc"; then
    export SOPS_AGE_KEY_FILE="$HOME/.age/key.txt"
    sops -e -i --age "$_pubkey" "$_enc" 2>/dev/null && \
      echo "tokens.enc.yaml 已加密" || \
      echo "提示: 請手動執行 secrets-edit 編輯並加密 secrets"
  fi
}
