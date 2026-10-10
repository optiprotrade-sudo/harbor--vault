$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $project 'android\app\src\main\AndroidManifest.xml'
if (!(Test-Path $manifest)) { throw 'Missing AndroidManifest.xml. Run flutter create first.' }
$xml = Get-Content -Path $manifest -Raw
if ($xml -notmatch 'android.permission.INTERNET') {
  $permission = '    <uses-permission android:name="android.permission.INTERNET" />' + "`n    "
  $xml = $xml.Replace('<application', $permission + '<application')
}
if ($xml -notmatch 'android:allowBackup=') {
  $xml = $xml.Replace('<application', '<application android:allowBackup="false"')
}
Set-Content -Path $manifest -Value $xml -Encoding UTF8
$kotlin = Join-Path $project 'android\app\build.gradle.kts'
$groovy = Join-Path $project 'android\app\build.gradle'
if (Test-Path $kotlin) {
  $gradle = Get-Content -Path $kotlin -Raw
  $gradle = $gradle.Replace('minSdk = flutter.minSdkVersion', 'minSdk = 23')
  Set-Content -Path $kotlin -Value $gradle -Encoding UTF8
} elseif (Test-Path $groovy) {
  $gradle = Get-Content -Path $groovy -Raw
  $gradle = $gradle.Replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion 23')
  Set-Content -Path $groovy -Value $gradle -Encoding UTF8
}
Write-Output 'Patched Android INTERNET permission, disabled app cloud backup and set minSdk 23.'
