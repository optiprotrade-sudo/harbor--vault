# Harbor Vault v1.3 — Combined v1.2 + Launch Unlock

One source ZIP for ONE GitHub update: includes all earlier v1.2 improvements.

## New changes

- On an already-created wallet, the opening screen is locked and the Android
  authentication dialog is requested automatically without pressing Unlock.
- The app never renders balances or addresses under a pending unlock dialog.
- On returning after genuine backgrounding, the wallet requests Android
  authentication again; cancel or failure remains locked with a retry action.
- Support depends on phone hardware, enabled Android biometrics and screen lock.
  Compatible face authentication or the phone's PIN/pattern/passcode may be
  offered by Android. This is not a new app-specific password.
- The old 1/2/3-minute in-app idle timer and immediate background lock remain.
- No prompt retry loop occurs merely because verification was cancelled.
- No secrets or wallet data are added to notifications.

## Included from v1.2

- Notification bell instead of version label; local read/unread history.
- Tap-outside-to-close notification panel, clear all, mark all read.
- Owner test checklist, history view, network picker and send REVIEW.

## To build

Extract the ZIP and run PUSH-TO-GITHUB.bat (Git for Windows required),
confirm changes, then run Build Harbor Vault Android APK in GitHub Actions.
No need to upload the v1.2 ZIP first.

## Limitations

- Flutter tests/build and on-phone biometrics have NOT been validated locally.
- Mainnet transfers are STILL DISABLED; it is not safe to deposit real funds.
- APK updates may conflict with a previous signing certificate. Do not
  uninstall until wallet recovery is verified and backed up offline.
