# Harbor Vault v1.4 — Single Unlock and Organized Settings

## Fixed

- Prevent duplicate automatic fingerprint requests at startup and when
  Android resumes from its own authentication overlay.
- Added `UnlockPromptCoordinator` with unit tests for one initial prompt,
  OS-prompt lifecycle pause/resume, cancellation, manual retry, genuine
  background return and inactive-app handling.
- Disabled `stickyAuth` in `DeviceAuthService` so the Android plugin won't
  automatically re-prompt on a lifecycle change.
- Existing wallet initially displays full-screen **Welcome back** with no
  wallet header or notification panel behind the OS biometric prompt.
- Authentication failure or cancellation leaves the wallet locked.

## Settings organization

- Security grouped into expandable Unlock & auto-lock, Backup & recovery,
  Privacy & network checks, and Advanced & about sections.
- Owner grouped into Wallet profile, Networks & public addresses, Personal
  testing checklist, and About & limitations.
- Existing auto-lock timer, notification bell and wallet management retained.

## Verification limitations

Archive structure and static code checks are performed before handoff.
Flutter compilation, Android device integration and signing cannot be verified
here; run GitHub Actions and test with a new, unfunded wallet only.
No live signing or cryptocurrency sending is available.
