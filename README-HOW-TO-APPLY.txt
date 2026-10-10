HARBOR VAULT v0.5 - GITHUB TEST FIX

Your GitHub Actions run reached flutter test, but failed because:
(1) test/widget_test.dart still referred to MyApp (Flutter's default template).
(2) lib/services/wallet_engine.dart used .address.hex, but wallet 0.0.18 exposes .eip55With0x.

Update exactly these two files in your existing GitHub repository, branch main:

1. lib/services/wallet_engine.dart
   Open its GitHub page, Edit (pencil), select all, replace with matching file from this ZIP, Commit changes.

2. test/widget_test.dart
   Navigate to test/widget_test.dart in GitHub; Edit, select all, replace with matching file from this ZIP, Commit changes.
   If it does not exist, Add file > Create new file at test/widget_test.dart.

Do NOT edit pubspec.yaml or the workflow for these particular errors.
After saving, open both on GitHub and verify:
- wallet_engine.dart contains: .address.eip55With0x
- widget_test.dart contains: HarborVaultApp, not MyApp
Then Actions > Build Harbor Vault Android APK > Run workflow.

CAUTION: This project is a receive-address demonstration, not an audited wallet.
Do not use it with actual funds or import a real funded recovery phrase.

These edits are checked against the reported compiler errors, but were not compiled here; additional build errors may still appear.
