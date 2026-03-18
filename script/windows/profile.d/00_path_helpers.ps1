# PATH 工具函式（對應 .zshrc.d/00_path_helpers.zsh）

function Add-PathEntry {
    <#
    .SYNOPSIS
    將路徑加到 PATH 前面（不重複）
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $current = $env:PATH -split [IO.Path]::PathSeparator
    if ($Path -notin $current) {
        $env:PATH = $Path + [IO.Path]::PathSeparator + $env:PATH
    }
}

function Add-PathEntryIfExists {
    <#
    .SYNOPSIS
    若目錄存在，加到 PATH 前面（不重複）
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (Test-Path $Path -PathType Container) {
        Add-PathEntry $Path
    }
}

function __Remove-PathHelpers {
    # profile 載入完畢後清理 helper（由 profile.ps1 呼叫）
    Remove-Item -Path Function:\Add-PathEntry -ErrorAction SilentlyContinue
    Remove-Item -Path Function:\Add-PathEntryIfExists -ErrorAction SilentlyContinue
    Remove-Item -Path Function:\__Remove-PathHelpers -ErrorAction SilentlyContinue
}
