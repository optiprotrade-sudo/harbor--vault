@echo off
cd /d "%~dp0"
flutter run -d windows
if errorlevel 1 echo Failed to run. Read README.md and install Windows desktop tooling.
pause
