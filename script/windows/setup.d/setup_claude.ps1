# Claude Code 全域設定 symlink 建立腳本 (Windows)
# 將 dotfile/config/ai/claude/ 下的設定 symlink 回 ~/.claude/

$ErrorActionPreference = 'Stop'

$DotfileRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
$ClaudeSrc = Join-Path $DotfileRoot 'config' 'ai' 'claude'
$ClaudeDst = Join-Path $env:USERPROFILE '.claude'

$Items = @(
    'settings.json'
    'CLAUDE.md'
    'hooks'
    'commands'
    'scripts'
    'agents'
    'rules'
    'skills'
    'templates'
)

function Link-Item {
    param([string]$Name)

    $src = Join-Path $ClaudeSrc $Name
    $dst = Join-Path $ClaudeDst $Name

    if (-not (Test-Path $src)) {
        Write-Host "  [SKIP] $Name -- source not found" -ForegroundColor Red
        return
    }

    # Check if already correct symlink
    if (Test-Path $dst) {
        $item = Get-Item $dst -Force
        if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $src) {
            Write-Host "  [OK]   $Name -- already linked" -ForegroundColor Green
            return
        }

        # Backup existing non-symlink
        if ($item.LinkType -ne 'SymbolicLink') {
            $backup = "${dst}.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Write-Host "  [BAK]  $Name -> $(Split-Path $backup -Leaf)" -ForegroundColor Yellow
            Move-Item $dst $backup
        } else {
            Remove-Item $dst -Force
        }
    }

    $isDir = Test-Path $src -PathType Container
    New-Item -ItemType SymbolicLink -Path $dst -Target $src -Force | Out-Null
    Write-Host "  [LINK] $Name -> $src" -ForegroundColor Green
}

Write-Host "=== Claude Code Settings Symlink ===" -ForegroundColor Yellow

if (-not (Test-Path $ClaudeDst)) {
    New-Item -ItemType Directory -Path $ClaudeDst -Force | Out-Null
}

foreach ($item in $Items) {
    Link-Item -Name $item
}

Write-Host "=== Done ===" -ForegroundColor Green
