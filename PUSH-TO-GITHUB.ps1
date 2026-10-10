$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/optiprotrade-sudo/harbor--vault.git'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('harbor-vault-update-' + [guid]::NewGuid().ToString('N'))
Write-Host 'Harbor Vault v1.0: single GitHub update to optiprotrade-sudo/harbor--vault' -ForegroundColor Cyan
Write-Host 'No wallet keys, signing keys, phone data or private backups are uploaded.'
$confirm = Read-Host 'Type APPLY to clone and prepare the update'
if ($confirm -cne 'APPLY') { Write-Host 'Cancelled.'; exit 0 }
& git clone --depth 1 $repo $work
if ($LASTEXITCODE -ne 0) { throw 'Could not clone private repository. Ensure Git for Windows and GitHub login are configured.' }
foreach ($folder in @('lib','test','scripts','.github')) {
  $from = Join-Path $source $folder
  $to = Join-Path $work $folder
  if (-not (Test-Path $to)) { New-Item -ItemType Directory -Path $to | Out-Null }
  Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force
}
foreach ($file in @('pubspec.yaml','analysis_options.yaml')) {
  Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $work $file) -Force
}
Push-Location $work
try {
  & git status --short
  Write-Host "Review the files above. This copies app source and workflow only; no personal wallet data." -ForegroundColor Yellow
  $confirm = Read-Host 'Type PUSH to commit and upload the changes to GitHub'
  if ($confirm -cne 'PUSH') { Write-Host 'Not pushed.'; exit 0 }
  & git add -- lib test scripts .github pubspec.yaml analysis_options.yaml
  if ($LASTEXITCODE -ne 0) { throw 'Could not stage changes' }
  & git diff --cached --quiet
  if ($LASTEXITCODE -eq 0) { Write-Host 'Nothing new to commit'; exit 0 }
  & git commit -m 'Harbor Vault v1.0 consolidated personal beta'
  if ($LASTEXITCODE -ne 0) { throw 'Commit failed. Configure git user.name and user.email if requested.' }
  & git push origin HEAD:main
  if ($LASTEXITCODE -ne 0) { throw 'Push failed. Your local clone is at ' + $work }
  Write-Host 'Source pushed successfully. Open GitHub Actions and build the APK.' -ForegroundColor Green
} finally { Pop-Location }
