# Neovim 配置 Symlink（對應 setup_dotfiles.sh 中的 nvim 部分）

$DotfileRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
$nvimSource = Join-Path $DotfileRoot 'config' 'nvim'
$nvimTarget = Join-Path $env:LOCALAPPDATA 'nvim'

if (-not (Test-Path $nvimSource)) {
    Write-Host "  找不到 Neovim 配置: $nvimSource" -ForegroundColor Red
    return
}

# 檢查是否能建 symlink
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
$devMode = $false
try {
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (Test-Path $regPath) {
        $devMode = (Get-ItemProperty -Path $regPath -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
    }
} catch { }

$canSymlink = $isAdmin -or $devMode

if ($canSymlink) {
    # 移除舊連結或目錄
    if (Test-Path $nvimTarget) {
        $item = Get-Item $nvimTarget -Force
        if ($item.LinkType) {
            Remove-Item $nvimTarget -Force
        } else {
            Write-Host "  $nvimTarget 已存在且不是 symlink，備份為 nvim.bak" -ForegroundColor Yellow
            $backup = "$nvimTarget.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Move-Item $nvimTarget $backup
        }
    }

    New-Item -ItemType SymbolicLink -Path $nvimTarget -Target $nvimSource -Force | Out-Null
    Write-Host "  已連結: $nvimTarget -> $nvimSource" -ForegroundColor Green
} else {
    Write-Host '  無 symlink 權限，使用複製模式' -ForegroundColor Yellow
    if (Test-Path $nvimTarget) {
        $backup = "$nvimTarget.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Move-Item $nvimTarget $backup
    }
    Copy-Item -Path $nvimSource -Destination $nvimTarget -Recurse -Force
    Write-Host "  已複製: $nvimSource -> $nvimTarget" -ForegroundColor Green
    Write-Host '  注意：複製模式下配置不會自動同步，更新後需重新執行此腳本' -ForegroundColor Yellow
}

Write-Host '  Neovim 配置連結完成' -ForegroundColor Green
