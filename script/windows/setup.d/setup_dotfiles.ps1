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
        # Idempotency: skip if symlink already points to correct target
        if ((Test-Path $Target) -and
            ((Get-Item $Target -Force).LinkType -eq 'SymbolicLink') -and
            ((Get-Item $Target -Force).Target -eq $Source)) {
            Write-Host "  [OK]   $Target" -ForegroundColor DarkGreen
            return
        }
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

# -- repo 內的 symlink：Git for Windows 預設 core.symlinks=false，會 checkout 成內容是路徑的純文字檔 --
if ($canSymlink -and (Get-Command git -ErrorAction SilentlyContinue)) {
    if ((git -C $DotfileRoot config core.symlinks) -ne 'true') {
        git -C $DotfileRoot config core.symlinks true
    }
    $broken = @(git -C $DotfileRoot ls-files -s | Where-Object { $_ -match '^120000 ' } | ForEach-Object {
        ($_ -split "`t", 2)[1]
    } | Where-Object {
        $path = Join-Path $DotfileRoot $_
        $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        # 純文字檔的內容必須等於 index 裡的 link target，否則是本機修改，不動
        (-not $item) -or (-not $item.LinkType -and -not $item.PSIsContainer -and
            "$(Get-Content -LiteralPath $path -Raw)".Trim() -eq (git -C $DotfileRoot cat-file -p ":$_" | Out-String).Trim())
    })
    foreach ($rel in $broken) {
        Remove-Item -LiteralPath (Join-Path $DotfileRoot $rel) -Force -ErrorAction SilentlyContinue
    }
    if ($broken.Count -gt 0) {
        git -C $DotfileRoot checkout -- @broken
        Write-Host "  [LINK] 還原 $($broken.Count) 個 repo symlink" -ForegroundColor Green
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

# -- oh-my-posh theme（03_prompt.ps1 從 profile 同層讀取） --
Link-DotFile (Join-Path $DotfileRoot 'script' 'windows' 'theme.omp.json') (Join-Path (Split-Path $PROFILE) 'theme.omp.json')

# -- .vimrc --
Link-DotFile (Join-Path $DotfileRoot 'config' 'vim' '.vimrc') (Join-Path $UserHome '.vimrc')

# -- Git --
Link-DotFile (Join-Path $DotfileRoot 'config' 'git' '.gitconfig') (Join-Path $UserHome '.gitconfig')

# -- SSH --
Link-DotFile (Join-Path $DotfileRoot 'config' 'ssh' 'config') (Join-Path $UserHome '.ssh' 'config')

# -- VS Code --
$VSCodeUser = Join-Path $UserHome 'AppData' 'Roaming' 'Code' 'User'
Link-DotFile (Join-Path $DotfileRoot 'config' 'vscode' 'settings.json')    (Join-Path $VSCodeUser 'settings.json')
Link-DotFile (Join-Path $DotfileRoot 'config' 'vscode' 'keybindings.json') (Join-Path $VSCodeUser 'keybindings.json')
Link-DotFile (Join-Path $DotfileRoot 'config' 'vscode' 'mcp.json')         (Join-Path $VSCodeUser 'mcp.json')

# -- Windows Terminal --
$WTLocalState = Join-Path $UserHome 'AppData' 'Local' 'Packages' 'Microsoft.WindowsTerminal_8wekyb3d8bbwe' 'LocalState'
if (Test-Path (Split-Path $WTLocalState)) {
    Link-DotFile (Join-Path $DotfileRoot 'config' 'windows-terminal' 'settings.json') (Join-Path $WTLocalState 'settings.json')
}

# -- WSL --
Link-DotFile (Join-Path $DotfileRoot 'config' 'wsl' '.wslconfig') (Join-Path $UserHome '.wslconfig')

# Claude Code 的連結由 setup_claude.ps1 處理（來源在 config/ai/claude）。

Write-Host '  Dotfiles 連結完成' -ForegroundColor Green
