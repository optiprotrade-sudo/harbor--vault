# Harbor Vault v1.1 — Personal Security Update

## What changed

- The owner can select an **in-app inactivity auto-lock** of **1, 2, or 3 minutes**; the setting is stored locally in encrypted device storage. Default is **2 minutes**.
- The wallet locks **immediately when hidden/backgrounded**, regardless of inactivity preference. Dialogs are dismissed when it locks.
- Reopening requires Android system authentication: fingerprint, compatible face biometric, or device PIN/pattern/passcode depending on phone configuration.
- After you enter a recipient, network and amount, **Next** opens a read-only review. **Verify identity** prompts for fresh OS authentication even if the wallet was previously unlocked.
- Sending, signing, and broadcasting are **still disabled**. The verification is a simulation of the approval gate, not a transaction confirmation.
- Unindexed assets display **Not tracked** instead of a dash. Other unavailable balances show **Unavailable**; neither means funds have been lost or the balance is negative.

## One GitHub update

1. Keep the existing GitHub repository `optiprotrade-sudo/harbor--vault`.
2. Extract the full v1.1 ZIP and **use `PUSH-TO-GITHUB.bat`** if Git for Windows is installed. Type `APPLY`, then `PUSH` after reviewing. Only source code is uploaded.
3. Alternatively, extract the smaller GitHub patch ZIP and replace files **at exactly their included paths**. Commit them together. File paths:
   - `.github/workflows/build-android-apk.yml`
   - `lib/main.dart`
   - `lib/screens/owner_screen.dart`
   - `lib/screens/send_screen.dart`
   - `lib/services/wallet_preferences.dart`
   - `lib/services/auto_lock_policy.dart` (new)
   - `test/auto_lock_policy_test.dart` (new)
   - `pubspec.yaml`
   - `scripts/sanity_check.py`
4. Trigger **GitHub Actions → Build Harbor Vault Android APK** once.
5. Verify the APK shows **v1.1** and make a test-only wallet. Do not use a funded phrase.

## Manual security test checklist (on your phone)

- [ ] Create an empty test wallet, unlock with phone authentication.
- [ ] Set the timer to 1 minute under Security, leave the unlocked wallet untouched; it should lock.
- [ ] Unlock, set 3 minutes, tap periodically; it should remain unlocked while actively used.
- [ ] Switch to another app; Harbor Vault should lock immediately.
- [ ] Open Send, select any test asset/network, enter a valid-looking recipient and amount, tap Next, then Verify identity.
- [ ] Cancel phone authentication: verification must **not** succeed.
- [ ] Complete phone authentication: the screen must say **Verified · No sending**. There must be **no signed or broadcast transaction**.
- [ ] Confirm unindexed assets say **Not tracked**, not `-` or `0`.

## Safety limitations

This app has **not** passed an independent security review, comprehensive derivation/recovery validation or real transaction testing. A displayed address does not mean receiving funds is safe. No real transfers are possible in v1.1. Never place real funds or funded recovery phrases into the prototype.

On some Android devices, face recognition does not qualify as a strong supported biometric for the system prompt. Device credentials may be used instead; no promise of Face ID on all devices.

Do not upload seed phrases, signing keys, phone wallet data, or keystores to GitHub.
