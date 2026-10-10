# Harbor Vault v0.3: GitHub dependency correction

The second GitHub Actions failure occurs at `Create Android application files`. The original project contains old `bip32` and `bip39` packages alongside modern `pointycastle`. The old BIP32 package declares an incompatible dependency and Dart SDK range. This patch replaces the mnemonic and key-derivation libraries with newer alternatives.

To update an EXISTING GitHub repository, open the repository's root:

1. Replace `pubspec.yaml` with the file inside this package (at the repo root).
2. Replace `lib/services/wallet_engine.dart` with the file inside this package (same path).
3. Edit `.github/workflows/build-android-apk.yml`: change the `flutter create` command to include `--no-pub` as shown in this package (if your workflow already lacks `Set up Android SDK`, keep it removed).
4. Commit, then run Actions -> Build Harbor Vault Android APK -> Run workflow.

Do not upload the enclosing `harbor_vault_v03` folder to the repository, and do not replace the entire repository unless you intend to.

This is a proposed source compatibility fix; **the Android APK has not been compiled or verified in this environment**. If the next run fails, the job's `Annotations` section identifies the failing step without having to scroll through long logs. Do not import a funded mnemonic or send real funds to any addresses from this prototype.
