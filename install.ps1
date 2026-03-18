#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Miyago's dotfiles installer for Windows.
.DESCRIPTION
    Creates symbolic links from dotfiles repo to actual config locations.
    Run as Administrator (symlinks require elevated privileges on Windows).
.PARAMETER DryRun
    Show what would be done without making changes.
.PARAMETER Force
    Overwrite existing files/links without prompting.
#>
param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$DotfilesRoot = $PSScriptRoot

# ── Helper ──────────────────────────────────────────────────────────
function Link-File {
    param(
        [string]$Source,
        [string]$Target
    )

    $Source = Join-Path $DotfilesRoot $Source

    if (-not (Test-Path $Source)) {
        Write-Warning "Source not found: $Source"
        return
    }

    $targetDir = Split-Path $Target -Parent
    if (-not (Test-Path $targetDir)) {
        if ($DryRun) {
            Write-Host "[DRY] mkdir $targetDir" -ForegroundColor Cyan
        } else {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
    }

    if (Test-Path $Target) {
        if ($Force) {
            if (-not $DryRun) {
                Remove-Item $Target -Force
            }
            Write-Host "[OVERWRITE] $Target" -ForegroundColor Yellow
        } else {
            $backup = "$Target.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            if (-not $DryRun) {
                Move-Item $Target $backup
            }
            Write-Host "[BACKUP] $Target -> $backup" -ForegroundColor Yellow
        }
    }

    if ($DryRun) {
        Write-Host "[DRY] link $Target -> $Source" -ForegroundColor Cyan
    } else {
        New-Item -ItemType SymbolicLink -Path $Target -Value $Source -Force | Out-Null
        Write-Host "[LINK] $Target -> $Source" -ForegroundColor Green
    }
}

# ── Mappings ────────────────────────────────────────────────────────
Write-Host "`n=== Miyago Dotfiles Installer ===" -ForegroundColor Magenta
Write-Host "Source: $DotfilesRoot`n"

$UserHome = $env:USERPROFILE
$WTLocalState = "$UserHome\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$VSCodeUser = "$UserHome\AppData\Roaming\Code\User"

# PowerShell profile (uses $PROFILE to detect correct location for pwsh 7+)
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    if ($DryRun) {
        Write-Host "[DRY] mkdir $profileDir" -ForegroundColor Cyan
    } else {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
}
Link-File "script\windows\profile.ps1" $PROFILE

# Windows Terminal
Link-File "windows-terminal\settings.json" "$WTLocalState\settings.json"

# VS Code
Link-File "vscode\settings.json"    "$VSCodeUser\settings.json"
Link-File "vscode\keybindings.json" "$VSCodeUser\keybindings.json"
Link-File "vscode\mcp.json"         "$VSCodeUser\mcp.json"

# Git
Link-File "git\.gitconfig" "$UserHome\.gitconfig"

# SSH (config only, not keys)
Link-File "ssh\config" "$UserHome\.ssh\config"

# WSL
Link-File "wsl\.wslconfig" "$UserHome\.wslconfig"

# Claude Code
Link-File "claude\CLAUDE.md"             "$UserHome\.claude\CLAUDE.md"
Link-File "claude\settings\settings.json" "$UserHome\.claude\settings.json"

# Claude scripts
$claudeScriptsDir = Join-Path $DotfilesRoot 'claude' 'scripts'
if (Test-Path $claudeScriptsDir) {
    Get-ChildItem "$claudeScriptsDir\*.sh" | ForEach-Object {
        Link-File "claude\scripts\$($_.Name)" "$UserHome\.claude\scripts\$($_.Name)"
    }
}

# ── Software checklist ──────────────────────────────────────────────
Write-Host "`n=== Required Software ===" -ForegroundColor Magenta

$software = @(
    @{ Name = "git";           Cmd = "git --version" },
    @{ Name = "oh-my-posh";    Cmd = "oh-my-posh --version" },
    @{ Name = "MesloLGS NF";   Cmd = $null },
    @{ Name = "node";          Cmd = "node --version" },
    @{ Name = "bun";           Cmd = "bun --version" },
    @{ Name = "python/uv";     Cmd = "uv --version" },
    @{ Name = "go";            Cmd = "go version" },
    @{ Name = "docker";        Cmd = "docker --version" },
    @{ Name = "claude";        Cmd = "claude --version" }
)

foreach ($sw in $software) {
    if ($sw.Cmd) {
        try {
            $null = Invoke-Expression $sw.Cmd 2>$null
            Write-Host "  [OK] $($sw.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  [--] $($sw.Name) (not found)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [??] $($sw.Name) (manual check)" -ForegroundColor DarkGray
    }
}

# ── PowerShell modules ──────────────────────────────────────────────
Write-Host "`n=== PowerShell Modules ===" -ForegroundColor Magenta

$modules = @("oh-my-posh", "posh-git", "DirColors", "Terminal-Icons")
foreach ($mod in $modules) {
    if (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $mod" -ForegroundColor Green
    } else {
        Write-Host "  [--] $mod (Install-Module $mod)" -ForegroundColor Yellow
    }
}

Write-Host "`nDone." -ForegroundColor Green
