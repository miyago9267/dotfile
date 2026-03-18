# 安裝 Scoop 套件管理器

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host '  Scoop 已安裝，跳過' -ForegroundColor Green
    return
}

Write-Host '  安裝 Scoop...' -ForegroundColor Yellow

# Scoop 需要 ExecutionPolicy 為 RemoteSigned
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Restricted') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 加入常用 bucket
scoop bucket add extras
scoop bucket add nerd-fonts

Write-Host '  Scoop 安裝完成' -ForegroundColor Green
