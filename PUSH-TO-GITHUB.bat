@echo off
cd /d "%~dp0"
where git >nul 2>nul
if errorlevel 1 (
  echo Git for Windows is required for one-command upload. No files were changed.
  echo You can alternatively update the repository using GitHub Desktop or the website.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PUSH-TO-GITHUB.ps1"
pause
