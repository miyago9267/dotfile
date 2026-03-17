# 安裝 oh-my-posh（替代 Powerlevel10k）

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Host '  oh-my-posh 已安裝，跳過' -ForegroundColor Green
    return
}

Write-Host '  安裝 oh-my-posh...' -ForegroundColor Yellow

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install oh-my-posh
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install JanDeDobbeleer.OhMyPosh --accept-source-agreements --accept-package-agreements
} else {
    # 直接用官方安裝腳本
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
}

Write-Host '  oh-my-posh 安裝完成' -ForegroundColor Green
