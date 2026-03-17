# 安裝 Bun（對應 install_bun.sh）

if (Get-Command bun -ErrorAction SilentlyContinue) {
    $ver = bun --version
    Write-Host "  Bun 已安裝: $ver" -ForegroundColor Green
    return
}

Write-Host '  安裝 Bun...' -ForegroundColor Yellow

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install bun
} else {
    # 官方 PowerShell 安裝腳本
    Invoke-RestMethod bun.sh/install.ps1 | Invoke-Expression
}

Write-Host '  Bun 安裝完成' -ForegroundColor Green
