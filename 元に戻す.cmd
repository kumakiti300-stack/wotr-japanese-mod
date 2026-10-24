@echo off
setlocal
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0installer\Install.ps1" -Action Restore
exit /b %errorlevel%
