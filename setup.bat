@echo off
REM Miyago Dotfile - Windows 安裝入口
REM 自動偵測 PowerShell 7+ 並啟動 setup.ps1

where pwsh >nul 2>nul
if %errorlevel% neq 0 (
    echo PowerShell 7+ is required.
    echo Install from: https://aka.ms/powershell
    pause
    exit /b 1
)

pwsh -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
