# Dotfiles Symlink 設定（對應 setup_dotfiles.sh）

$DotfileRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent

Write-Host "  Dotfile root: $DotfileRoot" -ForegroundColor Cyan

# PowerShell profile symlink
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$sourcePsProfile = Join-Path $DotfileRoot 'powershell' 'profile.ps1'

# 檢查是否有管理員權限（symlink 需要）
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

# 在 Windows 開發者模式下不需要管理員權限建 symlink
$devMode = $false
try {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (Test-Path $regPath) {
        $devMode = (Get-ItemProperty -Path $regPath -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
    }
} catch { }

$canSymlink = $isAdmin -or $devMode

if ($canSymlink) {
    Write-Host '  使用 symlink 模式' -ForegroundColor Green

    # Profile
    if (Test-Path $PROFILE) { Remove-Item $PROFILE -Force }
    New-Item -ItemType SymbolicLink -Path $PROFILE -Target $sourcePsProfile -Force | Out-Null
    Write-Host "  已連結: $PROFILE -> $sourcePsProfile"

    # .vimrc
    $vimrcTarget = Join-Path $DotfileRoot '.vimrc'
    $vimrcLink = Join-Path $HOME '.vimrc'
    if (Test-Path $vimrcTarget) {
        if (Test-Path $vimrcLink) { Remove-Item $vimrcLink -Force }
        New-Item -ItemType SymbolicLink -Path $vimrcLink -Target $vimrcTarget -Force | Out-Null
        Write-Host "  已連結: $vimrcLink -> $vimrcTarget"
    }
} else {
    Write-Host '  無 symlink 權限，使用複製模式（請開啟「開發人員模式」以使用 symlink）' -ForegroundColor Yellow

    # Profile
    Copy-Item -Path $sourcePsProfile -Destination $PROFILE -Force
    Write-Host "  已複製: $sourcePsProfile -> $PROFILE"

    # profile.d/
    $profileDDir = Join-Path (Split-Path $PROFILE) 'profile.d'
    $sourceProfileD = Join-Path $DotfileRoot 'powershell' 'profile.d'
    if (Test-Path $sourceProfileD) {
        if (-not (Test-Path $profileDDir)) {
            New-Item -ItemType Directory -Path $profileDDir -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $sourceProfileD '*') -Destination $profileDDir -Force -Recurse
        Write-Host "  已複製: profile.d/ -> $profileDDir"
    }

    # .vimrc
    $vimrcTarget = Join-Path $DotfileRoot '.vimrc'
    if (Test-Path $vimrcTarget) {
        Copy-Item -Path $vimrcTarget -Destination (Join-Path $HOME '.vimrc') -Force
        Write-Host "  已複製: .vimrc"
    }
}

Write-Host '  Dotfiles 連結完成' -ForegroundColor Green
