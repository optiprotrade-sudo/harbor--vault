# Harbor Vault v0.4 – wallet compile fix (Android)

**What GitHub Build #3 showed:** The `flutter test` step was importing `package:bip32/bip32.dart` although your updated `pubspec.yaml` uses `bip32_keys`. It also called `BIP32` and `hexEip55` APIs that do not match the current dependencies.

## Replace TWO existing files on GitHub

- Replace the **root** `pubspec.yaml` with the file included here.
- Replace **`lib/services/wallet_engine.dart`** with the file included here. The replacement intentionally imports `bip32_keys` and `bip39_mnemonic`, uses `.public` and `.private`, and uses Ethereum `.address.hex`.

Do **not** create a new folder named `harbor_vault_v04`, and do **not** edit `.github/workflows/build-android-apk.yml`: the GitHub action already successfully reached its test step.

### Easiest method on GitHub web
1. Open your existing `harbor--vault` repository.
2. Click `lib` → `services` → `wallet_engine.dart` → pencil (Edit).
3. Open `lib/services/wallet_engine.dart` from the extracted ZIP in Notepad++, copy all its content, paste over the full GitHub file, and Commit changes.
4. Return to the repository root; open `pubspec.yaml` → pencil, replace with the corresponding new file content, and Commit changes.
5. Go to **Actions → Build Harbor Vault Android APK → Run workflow**.
6. If tests fail again, report the failed step and error lines; this patch has **not been built with Flutter in this environment**.

### Safety
This is a **receive-only research prototype**, not a security-reviewed wallet. Do not import funded seed phrases, transfer funds to its addresses, or store meaningful crypto in it. Real funds require independent derivation-vector and security review, secure authentication, secure encrypted storage validation, and a production signing/recovery design.
