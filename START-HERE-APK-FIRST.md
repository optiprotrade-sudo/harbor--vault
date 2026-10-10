# Build Harbor Vault as an Android APK — without installing Flutter or Android Studio on your PC

This project is an **experimental, receive-only wallet**. It has **not been security-audited**. It **cannot send cryptocurrency**, and it has **no PIN or biometric lock**. **Do not fund it with real coins, import an existing funded recovery phrase, or use it to safeguard money.** Use it only to test the interface and address generation with disposable development phrases.

## Tools needed on your own devices

- **On your Windows PC:** A browser and a GitHub account. No Flutter SDK, Android Studio, Android SDK, or Visual Studio installation is needed for this cloud-build route.
- **On your Android phone:** A browser and permission to install the APK you download from your own GitHub Actions build.
- **In GitHub Actions:** The automated workflow installs Flutter, Android SDK and Java *on GitHub's runner*, creates the Android project, runs wallet tests and compiles the APK.

## Build instructions using your GitHub account

1. Extract the ZIP you received. Open the extracted `harbor_vault_apk_first` folder.
2. At https://github.com/new, create a **private** repository, e.g. `harbor-vault`. Leave the GitHub initialization options off (no README/license/gitignore pre-generated).
3. In your new repository, choose **Add file → Upload files**. Drag the **contents inside** the extracted folder into the upload area, **including `.github` and `scripts` folders**. Verify you see `.github/workflows/build-android-apk.yml` in the repository after committing. If the browser fails to preserve the directory structure, use GitHub Desktop or Git instead, and push the extracted project folder.
4. Open your GitHub repository's **Actions** tab. Enable workflows if GitHub asks.
5. On the left select **Build Harbor Vault Android APK**, click **Run workflow** and select the default branch.
6. When the run has a **green check mark**, open it and find **Artifacts → Harbor-Vault-Android-APK-v0.1**. Download that artifact ZIP.
7. Extract the *artifact ZIP*. It contains the actual `app-release.apk` file.
8. Transfer `app-release.apk` to your Android phone or download it on the phone, then tap it to install. Android might ask you to temporarily allow installations from the browser/files app. Re-disable unknown-app installation after testing.

If there is a **red X**, open the failed job in Actions and copy the error log to ChatGPT. **No APK has been compiled or verified in this chat**; a successful workflow run is necessary to obtain it.

## Notes

- The workflow triggers manually; ordinary repository commits will not automatically rebuild the APK.
- The default Flutter-generated Android package ID is `com.harborvault.harbor_vault`, intended for testing, not a public store release.
- The generated release APK may use development signing credentials provided by Flutter's generated Android scaffold. It is **not** a signed production wallet release or independent security audit.
- GitHub-hosted APK artifacts typically expire; the workflow sets retention to 30 days.
- Your recovery phrase must **never** be committed to GitHub, sent to ChatGPT, or shared with another person. Do not add personal wallet secrets to the project files.
- This first version supports BTC native SegWit, LTC native SegWit, ETH and Ethereum-network USDT receiving addresses only; it has no sending support.

## Want to build locally later?

For **Android APK only**, a local build requires Flutter and the Android SDK (normally installed with Android Studio), but **does not require Windows Visual Studio**. Windows desktop EXE builds are separate and may require Visual Studio with C++ tools.
