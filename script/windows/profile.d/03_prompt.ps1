# oh-my-posh 提示字元（替代 Powerlevel10k）

if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) { return }

# 使用 oh-my-posh 內建的 p10k 風格主題
# 可用主題列表：oh-my-posh get themes
$ompTheme = Join-Path $PSScriptRoot '..' 'theme.omp.json'
if (Test-Path $ompTheme) {
    oh-my-posh init pwsh --config $ompTheme | Invoke-Expression
} else {
    # 使用內建主題 (powerlevel10k_rainbow 最接近 p10k)
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/powerlevel10k_rainbow.omp.json" | Invoke-Expression
}

# 啟用 transient prompt（對應 p10k 的 instant prompt 概念）
# 注意：transient prompt 現在要在 theme JSON 裡設定 "transient_prompt" 欄位，
# 不再透過 cmdlet 啟用。詳見 https://ohmyposh.dev/docs/configuration/transient
