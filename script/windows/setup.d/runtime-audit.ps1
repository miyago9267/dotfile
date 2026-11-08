<#
.SYNOPSIS
    Read-only audit for the Windows and WSL runtime boundary.

.DESCRIPTION
    Reports command precedence and performs a bounded WSL direct-exec probe.
    It never installs, removes, or changes PATH. A timed-out WSL client probe
    may be terminated without shutting down the distro.
#>

param(
    [switch]$IncludeWsl
)

$ErrorActionPreference = 'Continue'
Write-Output 'runtime-audit: windows'

function Get-CommandState {
    param([Parameter(Mandatory)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        return [pscustomobject]@{ Name = $Name; Source = '<missing>'; Version = '<unknown>' }
    }

    $version = '<unknown>'
    try {
        $version = switch ($Name) {
            'pwsh' { & $command.Source -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>$null }
            'node' { & $command.Source --version 2>$null }
            'npm' { & $command.Source --version 2>$null }
            'go' { & $command.Source version 2>$null | Select-Object -First 1 }
            'uv' { & $command.Source --version 2>$null }
            'pyenv' { & $command.Source --version 2>$null | Select-Object -First 1 }
            default { '<available>' }
        }
    } catch { }

    [pscustomobject]@{
        Name = $Name
        Source = $command.Source
        Version = (($version | Out-String).Trim())
    }
}

Get-CommandState pwsh
Get-CommandState git
Get-CommandState uv
Get-CommandState pyenv
Get-CommandState python
Get-CommandState node
Get-CommandState npm
Get-CommandState nvm
Get-CommandState go
Get-CommandState docker

if ($IncludeWsl) {
    $wslOutput = Join-Path ([IO.Path]::GetTempPath()) ('runtime-audit-wsl-' + [guid]::NewGuid().ToString('N') + '.out')
    $wslError = $wslOutput + '.err'
    $process = $null
    try {
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = 'wsl.exe'
        $startInfo.Arguments = '-d Ubuntu-24.04 --exec /bin/uname -a'
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $null = $process.Start()
        if (-not $process.WaitForExit(5000)) {
            $process.Kill()
            [pscustomobject]@{ Name = 'wsl-direct-exec'; Source = 'wsl.exe -d Ubuntu-24.04 --exec /bin/uname -a'; Version = 'TIMEOUT' }
        } else {
            [pscustomobject]@{
                Name = 'wsl-direct-exec'
                Source = 'wsl.exe -d Ubuntu-24.04 --exec /bin/uname -a'
                Version = if ($process.ExitCode -eq 0) { $process.StandardOutput.ReadToEnd().Trim() } else { 'FAILED: ' + $process.StandardError.ReadToEnd().Trim() }
            }
        }
    } catch {
        [pscustomobject]@{ Name = 'wsl-direct-exec'; Source = 'wsl.exe'; Version = 'ERROR: ' + $_.Exception.Message }
    } finally {
        Remove-Item -LiteralPath $wslOutput,$wslError -Force -ErrorAction SilentlyContinue
    }
}
