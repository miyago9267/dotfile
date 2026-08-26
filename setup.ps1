# Miyago Dotfile - Windows 互動式安裝腳本
# 對應 setup.sh -- PowerShell 7+ 專用
# 使用方式：pwsh setup.ps1 [--all]

#requires -Version 7.0

param(
    [switch]$All,
    [switch]$Everything,
    [switch]$Environment,
    [switch]$ConfigOnly
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = $PSScriptRoot
$SetupDir = Join-Path $ScriptRoot 'script' 'windows' 'setup.d'

# -- 色彩輔助 --
function Write-Color {
    param([string]$Text, [ConsoleColor]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color -NoNewline
}

function Write-ColorLine {
    param([string]$Text, [ConsoleColor]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
}

# -- 安裝項目定義 --
# config / environment 分離；optional 項目不會被 --All 帶入。
$Items = @(
    @{ Script = 'install_scoop.ps1';    Name = 'Scoop 套件管理器';           Category = '基礎'; ConfigDefault = $false; EnvironmentDefault = $true;  Mode = 'environment'; Optional = $false }
    @{ Script = 'setup_dotfiles.ps1';   Name = 'Dotfiles 連結 (symlink)';     Category = '基礎'; ConfigDefault = $true;  EnvironmentDefault = $false; Mode = 'config'; Optional = $false }
    @{ Script = 'install_fonts.ps1';    Name = 'Nerd Fonts 字型';             Category = '基礎'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_ohmyposh.ps1'; Name = 'oh-my-posh 提示字元';         Category = 'Shell'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_neovim.ps1';   Name = 'Neovim + 依賴';                Category = '編輯器'; ConfigDefault = $false; EnvironmentDefault = $true; Mode = 'environment'; Optional = $false }
    @{ Script = 'setup_neovim.ps1';     Name = 'Neovim 配置連結';              Category = '編輯器'; ConfigDefault = $true;  EnvironmentDefault = $false; Mode = 'config'; Optional = $false }
    @{ Script = 'setup_claude.ps1';     Name = 'Claude Code 設定 (symlink)';   Category = '工具'; ConfigDefault = $true;  EnvironmentDefault = $false; Mode = 'config'; Optional = $false }
    @{ Script = 'install_node.ps1';     Name = 'Node.js (fnm)';                Category = '語言'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_python.ps1';   Name = 'Python (uv + pyenv-win)';      Category = '語言'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_go.ps1';       Name = 'Go';                           Category = '語言'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_rust.ps1';     Name = 'Rust (rustup)';                Category = '語言'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_bun.ps1';      Name = 'Bun';                          Category = '語言'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_gcloud.ps1';   Name = 'Google Cloud SDK';             Category = '雲端'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_kubectl.ps1';  Name = 'kubectl';                      Category = '雲端'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_argocd.ps1';   Name = 'Argo CD CLI';                 Category = '雲端'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
    @{ Script = 'install_gh.ps1';       Name = 'GitHub CLI (gh)';              Category = '工具'; ConfigDefault = $false; EnvironmentDefault = $false; Mode = 'environment'; Optional = $false }
)

$SetupMode = if ($Environment) { 'environment' } else { 'config' }
if ($Environment -or $ConfigOnly) {
    $wantedMode = if ($Environment) { 'environment' } else { 'config' }
    $Items = @($Items | Where-Object { $_.Mode -eq $wantedMode })
}

$Selected = @{}
for ($i = 0; $i -lt $Items.Count; $i++) {
    $Selected[$i] = if ($SetupMode -eq 'environment') { $Items[$i].EnvironmentDefault } else { $Items[$i].ConfigDefault }
}

# -- Banner --
function Show-Banner {
    Write-ColorLine @'
  __  __ _                         ____        _    __ _ _
 |  \/  (_)_   _  __ _  __ _  ___|  _ \  ___ | |_ / _(_) | ___
 | |\/| | | | | |/ _` |/ _` |/ _ \ | | |/ _ \| __| |_| | |/ _ \
 | |  | | | |_| | (_| | (_| | (_) | |_| | (_) | |_|  _| | |  __/
 |_|  |_|_|\__, |\__,_|\__, |\___/____/ \___/ \__|_| |_|_|\___|
           |___/       |___/
'@ Cyan

    $osInfo = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    Write-Host "  OS: $osInfo" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  PowerShell Windows 版安裝程式" -ForegroundColor White
    Write-Host ""
}

function Select-ItemsWithFzf {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        return 1
    }

    $lines = @()
    $actions = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $lines += "$i`t[$($item.Category)] $($item.Name)"
        if ($Selected[$i]) {
            [void]$actions.Add('toggle')
        }
        if ($i -lt ($Items.Count - 1)) {
            [void]$actions.Add('down')
        }
    }

    $fzfArgs = @(
        '--multi', '--height=100%', '--layout=reverse', '--border',
        "--delimiter=`t", '--with-nth=2', '--marker=✓ ', '--pointer=▶ ',
        '--prompt=安裝 > ',
        '--header=Space 選取  Ctrl-A 全選  Ctrl-N 清除  Enter 套用  Esc 取消',
        '--bind=space:toggle+down', '--bind=ctrl-a:select-all',
        '--bind=ctrl-n:deselect-all', "--bind=load:$($actions -join '+')"
    )

    $selectedLines = @($lines | & fzf @fzfArgs)
    $status = $LASTEXITCODE
    if ($status -ne 0) {
        return $status
    }

    for ($i = 0; $i -lt $Items.Count; $i++) {
        $Selected[$i] = $false
    }
    foreach ($line in $selectedLines) {
        if ($line -match '^(\d+)\t') {
            $Selected[[int]$Matches[1]] = $true
        }
    }
    return 0
}

# -- 全部安裝模式 --
if ($All -or $Everything -or $ConfigOnly) {
    Show-Banner
    Write-ColorLine "=== 全部安裝模式 ===" Yellow
    Write-Host ""
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $Selected[$i] = $Everything -or -not $Items[$i].Optional
    }
} else {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw 'Interactive setup requires a TTY. Use -All instead.'
    }

    $fzfStatus = Select-ItemsWithFzf
    if ($fzfStatus -eq 130) {
        Write-ColorLine "`n  已取消安裝" Yellow
        return
    }

    if ($fzfStatus -ne 0) {
        # -- 零依賴 fallback 互動式選單 --
        $current = 0

        while ($true) {
        Clear-Host
        Show-Banner

        Write-Host "  方向鍵上下移動 | 空白鍵切換 | " -NoNewline
        Write-Color "a" Green; Write-Host " 全選 | " -NoNewline
        Write-Color "n" Red; Write-Host " 全不選 | " -NoNewline
        Write-Color "Enter" Yellow; Write-Host " 開始安裝 | " -NoNewline
        Write-Color "q" Red; Write-Host " 離開"
        Write-Host ""

        $prevCat = ''
        for ($i = 0; $i -lt $Items.Count; $i++) {
            $item = $Items[$i]

            # 分類標題
            if ($item.Category -ne $prevCat) {
                if ($i -gt 0) { Write-Host "" }
                Write-ColorLine "  -- $($item.Category) --" Cyan
                $prevCat = $item.Category
            }

            # 游標和勾選
            $cursor = if ($i -eq $current) { '> ' } else { '  ' }
            $cursorColor = if ($i -eq $current) { 'Yellow' } else { 'White' }
            $check = if ($Selected[$i]) { 'x' } else { ' ' }
            $checkColor = if ($Selected[$i]) { 'Green' } else { 'DarkGray' }

            Write-Color "  $cursor" $cursorColor
            Write-Color "[" White
            Write-Color $check $checkColor
            Write-Color "] " White
            Write-Host $item.Name
        }

        Write-Host ""
        $count = ($Selected.Values | Where-Object { $_ }).Count
        Write-Host "  已選擇 " -NoNewline
        Write-Color "$count" Green
        Write-Host " / $($Items.Count) 項"

        # 讀取按鍵
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'UpArrow'   { $current = ($current - 1 + $Items.Count) % $Items.Count }
            'DownArrow' { $current = ($current + 1) % $Items.Count }
            'Spacebar'  { $Selected[$current] = -not $Selected[$current] }
            'Enter'     { break }
            'Q'         { Write-ColorLine "`n  已取消安裝" Yellow; return }
            'A'         { for ($j = 0; $j -lt $Items.Count; $j++) { $Selected[$j] = $true } }
            'N'         { for ($j = 0; $j -lt $Items.Count; $j++) { $Selected[$j] = $false } }
            default {
                # j/k 導航
                if ($key.KeyChar -eq 'j') { $current = ($current + 1) % $Items.Count }
                elseif ($key.KeyChar -eq 'k') { $current = ($current - 1 + $Items.Count) % $Items.Count }
            }
        }

            if ($key.Key -eq 'Enter') { break }
        }
    }
}

# -- 執行安裝 --
Clear-Host
Show-Banner
Write-ColorLine "=== 開始安裝 ===" Yellow
Write-Host ""

$installed = 0
$failed = 0
$skipped = 0

for ($i = 0; $i -lt $Items.Count; $i++) {
    $item = $Items[$i]
    $scriptPath = Join-Path $SetupDir $item.Script

    if (-not $Selected[$i]) {
        $skipped++
        continue
    }

    if (-not (Test-Path $scriptPath)) {
        Write-ColorLine "  [SKIP] $($item.Name) -- 腳本不存在: $($item.Script)" Red
        $skipped++
        continue
    }

    Write-ColorLine "  [RUN]  $($item.Name)" Yellow
    try {
        & $scriptPath
        Write-ColorLine "  [OK]   $($item.Name)" Green
        $installed++
    } catch {
        Write-ColorLine "  [FAIL] $($item.Name) -- $_" Red
        $failed++
    }
    Write-Host ""
}

# -- 結果摘要 --
Write-Host ""
Write-ColorLine "=== 安裝完成 ===" Yellow
Write-Host "  成功: " -NoNewline; Write-ColorLine "$installed" Green
if ($failed -gt 0) {
    Write-Host "  失敗: " -NoNewline; Write-ColorLine "$failed" Red
}
Write-Host "  略過: $skipped"

# -- 軟體檢查 --
Write-Host ""
Write-ColorLine "=== 軟體狀態 ===" Yellow

$software = @(
    @{ Name = "git";         Cmd = "git --version" },
    @{ Name = "oh-my-posh";  Cmd = "oh-my-posh --version" },
    @{ Name = "node";        Cmd = "node --version" },
    @{ Name = "bun";         Cmd = "bun --version" },
    @{ Name = "python/uv";   Cmd = "uv --version" },
    @{ Name = "go";          Cmd = "go version" },
    @{ Name = "docker";      Cmd = "docker --version" },
    @{ Name = "claude";      Cmd = "claude --version" }
)

foreach ($sw in $software) {
    try {
        $null = Invoke-Expression $sw.Cmd 2>$null
        Write-Host "  [OK] $($sw.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  [--] $($sw.Name)" -ForegroundColor DarkGray
    }
}

# -- 模組檢查 --
Write-Host ""
Write-ColorLine "=== PowerShell 模組 ===" Yellow

$modules = @("oh-my-posh", "posh-git", "DirColors", "Terminal-Icons")
foreach ($mod in $modules) {
    if (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $mod" -ForegroundColor Green
    } else {
        Write-Host "  [--] $mod (Install-Module $mod)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-ColorLine "請重新啟動終端以套用所有變更" Yellow
