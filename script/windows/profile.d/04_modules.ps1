# 額外 PowerShell 模組（從 Windows 舊版 profile 合併）

# posh-git -- Git 狀態整合到 prompt
if (Get-Module posh-git -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module posh-git
}

# DirColors -- ls 彩色輸出
if (Get-Module DirColors -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module DirColors
}

# Terminal-Icons -- 檔案圖示
if (Get-Module Terminal-Icons -ListAvailable -ErrorAction SilentlyContinue) {
    Import-Module Terminal-Icons
}

# Chocolatey（如果有安裝）
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module $ChocolateyProfile
}
