@echo off
cd /d "%~dp0"
flutter build apk --release
if errorlevel 1 (
  echo Failed. Check flutter doctor and Android Studio setup.
) else (
  echo.
  echo APK located at build\app\outputs\flutter-apk\app-release.apk
  echo NOTE: This prototype has not been security-audited. DO NOT use with real funds.
)
pause
