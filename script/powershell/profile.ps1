# Miyago Dotfile - PowerShell Profile
# 對應 .zshrc -- PowerShell 7+ 專用

#requires -Version 7.0

# -- 基本設定 --
$env:EDITOR = 'nvim'
$env:LANG = 'en_US.UTF-8'
$env:LANGUAGE = 'en_US'

# 歷史記錄
$MaximumHistoryCount = 10000

# -- Dotfile 根目錄 --
$DotfileRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $DotfileRoot) {
    $DotfileRoot = Join-Path $HOME 'dotfile'
}

# -- 載入 .env --
$envFile = Join-Path $HOME '.env'
if (-not (Test-Path $envFile)) {
    $envFile = Join-Path $DotfileRoot '.env'
}
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+?)\s*=\s*(.+)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim('"').Trim("'"), 'Process')
        }
    }
}

# -- 模組化載入 profile.d/*.ps1 --
$profileDir = Join-Path $PSScriptRoot 'profile.d'
if (Test-Path $profileDir) {
    Get-ChildItem -Path $profileDir -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

# -- 清理 helper functions（對應 .zshrc 的 unset -f） --
if (Get-Command '__Remove-PathHelpers' -ErrorAction SilentlyContinue) {
    __Remove-PathHelpers
}
