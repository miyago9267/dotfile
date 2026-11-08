# agent-secret 的 PowerShell 入口：把參數原樣（陣列）轉給 Git for Windows 的 bash -p <broker>。
# broker 本體是同目錄的 agent-secret（bash）。這個檔案不解析子指令，也不讀、不存任何值：
# pipeline 進來的內容直接接到 bash 的 stdin，stdout / stderr / exit code 原樣回來。不經 cmd.exe，沒有 .cmd shim。
#
#   Get-Clipboard | agent-secret put MY_TOKEN
#   agent-secret run MY_TOKEN -- gh api user
#   agent-secret list
#
# bash.exe 的找法：從 PATH 上的 git.exe 往上找 Git 的安裝目錄，再試常見的安裝位置；只接受安裝目錄底下的
# usr\bin\bash.exe。System32 與 WindowsApps 的 bash.exe 是 WSL 的啟動器，不會被選到。
# 這個檔案存成帶 BOM 的 UTF-8：Windows PowerShell 5.1 會把沒有 BOM 的檔案當成 ANSI（Big5）讀，
# 中文註解會被解錯並吃掉換行，整個檔案就解析失敗（2026-10-10 實測）。編輯後請保留 BOM。

$ErrorActionPreference = 'Stop'

function Find-GitBash {
    $roots = New-Object System.Collections.Generic.List[string]
    foreach ($git in @(Get-Command git.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
        $dir = Split-Path -Parent $git.Source
        for ($i = 0; $i -lt 3 -and $dir; $i++) {
            $roots.Add($dir)
            $dir = Split-Path -Parent $dir
        }
    }
    foreach ($pair in @(
            @($env:ProgramFiles, 'Git'),
            @(${env:ProgramFiles(x86)}, 'Git'),
            @($env:LOCALAPPDATA, 'Programs\Git'),
            @($env:USERPROFILE, 'scoop\apps\git\current'))) {
        if ($pair[0]) { $roots.Add((Join-Path $pair[0] $pair[1])) }
    }
    foreach ($root in $roots) {
        $bash = Join-Path $root 'usr\bin\bash.exe'
        if (Test-Path -LiteralPath $bash -PathType Leaf) { return $bash }
    }
    return $null
}

# 每個參數都自己加上雙引號再交給 PowerShell 的 Legacy 傳遞方式（原樣送出）。原因有兩個（2026-10-10 實測）：
#   1. MSYS 的 runtime 對原生行程傳來、沒加引號的參數會做 glob 展開：* 變成目前目錄的檔名，~ 與 {a,b} 被展開，
#      含 [ 的參數裡的反斜線會被吃掉（'[%s]\n' 變成 [%s]n）。加了引號就不展開。
#   2. Windows PowerShell 5.1 不會跳脫參數裡的雙引號，空字串會整個消失。
# 跳脫照 Windows 指令列的規則：" 前面的反斜線加倍、結尾的反斜線加倍。內嵌的 " 在 5.1 寫成 ""、在 pwsh 寫成 \"：
# 兩個版本判斷「要不要再包一層引號」的方式不同（5.1 數所有的 "，pwsh 不數 \ 後面的 "），寫錯會被多包一層。
function ConvertTo-QuotedNativeArg([string]$Value) {
    $quote = if ($PSVersionTable.PSVersion.Major -lt 6) { '""' } else { '\"' }
    $Value = [regex]::Replace($Value, '(\\*)"', ('$1$1' + $quote))
    $Value = [regex]::Replace($Value, '(\\+)$', '$1$1')
    return '"' + $Value + '"'
}

$bash = Find-GitBash
if (-not $bash) {
    [Console]::Error.WriteLine('agent-secret: Git for Windows bash.exe not found (looked next to git.exe on PATH and in the usual install locations)')
    exit 1
}
# 寫成 C:/... ：bash 認得，broker 的 doctor 也才解析得出自己的路徑
$broker = (Join-Path $PSScriptRoot 'agent-secret') -replace '\\', '/'
if (-not (Test-Path -LiteralPath $broker -PathType Leaf)) {
    [Console]::Error.WriteLine("agent-secret: broker script not found: $broker")
    exit 1
}

$forward = @($args | ForEach-Object { [string]$_ })
# PowerShell 把沒加引號的第一個 -- 當成「參數結束」記號吃掉，不會出現在 $args 裡（寫成 '--' 才會留下）。
# broker 的 run 一定是 run <name> -- <command>...，所以第三個位置不是 -- 時補回去；其餘子指令不動。
if ($forward.Count -ge 3 -and $forward[0] -ceq 'run' -and $forward[2] -cne '--') {
    $forward = @($forward[0], $forward[1], '--') + @($forward[2..($forward.Count - 1)])
}
$quoted = @(@('-p', $broker) + $forward | ForEach-Object { ConvertTo-QuotedNativeArg $_ })

# 送進原生程式的文字用 UTF-8：5.1 預設是 ASCII，非 ASCII 字元會被悄悄換成 ? 然後通過 broker 的檢查；
# 改成 UTF-8 後 broker 會拒絕它們。5.1 只認 global 的 $OutputEncoding（實測），所以呼叫完還原。
# stderr 不能讓 PowerShell 當成終止錯誤：broker 每次 run 都會在 stderr 印名稱與 backend。
$PSNativeCommandArgumentPassing = 'Legacy'
$ErrorActionPreference = 'Continue'
$savedEncoding = $global:OutputEncoding
try {
    $global:OutputEncoding = New-Object System.Text.UTF8Encoding $false
    if ($MyInvocation.ExpectingInput) {
        $input | & $bash @quoted
    } else {
        & $bash @quoted
    }
    $code = $LASTEXITCODE
} finally {
    $global:OutputEncoding = $savedEncoding
}
exit $code
