@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed or missing from PATH.
  echo Please read README.md to install Flutter, Android Studio and Visual Studio.
  pause
  exit /b 1
)
echo Creating Windows and Android native platform files...
call flutter create --project-name harbor_vault --platforms android,windows .
if errorlevel 1 goto failed
echo Configuring Android permissions and minimum SDK...
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\patch_android.ps1
if errorlevel 1 goto failed
echo Installing dependencies...
call flutter pub get
if errorlevel 1 goto failed
echo Running wallet derivation tests...
call flutter test
if errorlevel 1 goto failed
echo.
echo Setup complete. Run RUN-WINDOWS.bat or BUILD-ANDROID-APK.bat.
pause
exit /b 0
:failed
echo Setup or tests failed. Please copy the error from this window.
pause
exit /b 1
