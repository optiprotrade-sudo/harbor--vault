@echo off
cd /d "%~dp0"
flutter build windows --release
if errorlevel 1 (
  echo Failed. Check Visual Studio C++ desktop build tools and ATL installation.
) else (
  echo.
  echo Windows build files are in build\windows\x64\runner\Release\
  echo Keep the full Release folder together, not the EXE alone.
)
pause
