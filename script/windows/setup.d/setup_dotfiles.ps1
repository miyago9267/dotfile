# Dotfiles Symlink 設定（對應 setup_dotfiles.sh）
# 處理所有 Windows 端的配置連結：PS profile, VS Code, Windows Terminal, Git, SSH, WSL, Claude

$DotfileRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent | Split-Path -Parent

Write-Host "  Dotfile root: $DotfileRoot" -ForegroundColor Cyan

# -- 權限檢測 --
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

# -- Link helper --
function Link-DotFile {
    param([string]$Source, [string]$Target)

    if (-not (Test-Path $Source)) {
        Write-Host "  [SKIP] 來源不存在: $Source" -ForegroundColor DarkGray
        return
    }

    $targetDir = Split-Path $Target -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if ($canSymlink) {
        if (Test-Path $Target) { Remove-Item $Target -Force }
        New-Item -ItemType SymbolicLink -Path $Target -Value $Source -Force | Out-Null
        Write-Host "  [LINK] $Target" -ForegroundColor Green
    } else {
        if (Test-Path $Source -PathType Container) {
            if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }
            Copy-Item -Path $Source -Destination $Target -Recurse -Force
        } else {
            Copy-Item -Path $Source -Destination $Target -Force
        }
        Write-Host "  [COPY] $Target" -ForegroundColor Yellow
    }
}

if ($canSymlink) {
    Write-Host '  使用 symlink 模式' -ForegroundColor Green
} else {
    Write-Host '  無 symlink 權限，使用複製模式（建議開啟「開發人員模式」）' -ForegroundColor Yellow
}

$UserHome = $env:USERPROFILE

# -- PowerShell profile --
Link-DotFile (Join-Path $DotfileRoot 'script' 'windows' 'profile.ps1') $PROFILE

# -- PowerShell profile.d/（複製模式需要） --
if (-not $canSymlink) {
    $profileDDir = Join-Path (Split-Path $PROFILE) 'profile.d'
    $sourceProfileD = Join-Path $DotfileRoot 'script' 'windows' 'profile.d'
    if (Test-Path $sourceProfileD) {
        if (-not (Test-Path $profileDDir)) {
            New-Item -ItemType Directory -Path $profileDDir -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $sourceProfileD '*') -Destination $profileDDir -Force -Recurse
        Write-Host "  [COPY] profile.d/" -ForegroundColor Yellow
    }
}

# -- .vimrc --
Link-DotFile (Join-Path $DotfileRoot '.vimrc') (Join-Path $UserHome '.vimrc')

# -- Git --
Link-DotFile (Join-Path $DotfileRoot 'git' '.gitconfig') (Join-Path $UserHome '.gitconfig')

# -- SSH --
Link-DotFile (Join-Path $DotfileRoot 'ssh' 'config') (Join-Path $UserHome '.ssh' 'config')

# -- VS Code --
$VSCodeUser = Join-Path $UserHome 'AppData' 'Roaming' 'Code' 'User'
Link-DotFile (Join-Path $DotfileRoot 'vscode' 'settings.json')    (Join-Path $VSCodeUser 'settings.json')
Link-DotFile (Join-Path $DotfileRoot 'vscode' 'keybindings.json') (Join-Path $VSCodeUser 'keybindings.json')
Link-DotFile (Join-Path $DotfileRoot 'vscode' 'mcp.json')         (Join-Path $VSCodeUser 'mcp.json')

# -- Windows Terminal --
$WTLocalState = Join-Path $UserHome 'AppData' 'Local' 'Packages' 'Microsoft.WindowsTerminal_8wekyb3d8bbwe' 'LocalState'
if (Test-Path (Split-Path $WTLocalState)) {
    Link-DotFile (Join-Path $DotfileRoot 'windows-terminal' 'settings.json') (Join-Path $WTLocalState 'settings.json')
}

# -- WSL --
Link-DotFile (Join-Path $DotfileRoot 'wsl' '.wslconfig') (Join-Path $UserHome '.wslconfig')

# -- Claude Code --
$ClaudeDst = Join-Path $UserHome '.claude'
Link-DotFile (Join-Path $DotfileRoot 'claude' 'CLAUDE.md')        (Join-Path $ClaudeDst 'CLAUDE.md')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'settings.json')    (Join-Path $ClaudeDst 'settings.json')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'hooks')            (Join-Path $ClaudeDst 'hooks')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'commands')         (Join-Path $ClaudeDst 'commands')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'scripts')          (Join-Path $ClaudeDst 'scripts')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'agents')           (Join-Path $ClaudeDst 'agents')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'rules')            (Join-Path $ClaudeDst 'rules')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'skills')           (Join-Path $ClaudeDst 'skills')
Link-DotFile (Join-Path $DotfileRoot 'claude' 'templates')        (Join-Path $ClaudeDst 'templates')

Write-Host '  Dotfiles 連結完成' -ForegroundColor Green
