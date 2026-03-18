# 安裝 Go（對應 install_golang.sh）

if (Get-Command go -ErrorAction SilentlyContinue) {
    $ver = go version
    Write-Host "  Go 已安裝: $ver" -ForegroundColor Green
    return
}

Write-Host '  安裝 Go...' -ForegroundColor Yellow

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install go
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install GoLang.Go --accept-source-agreements --accept-package-agreements
} else {
    Write-Host '  請先安裝 scoop 或 winget' -ForegroundColor Red
    return
}

Write-Host '  Go 安裝完成' -ForegroundColor Green
