# Harbor Vault — Android APK-first personal multi-coin wallet prototype

**To generate an APK without installing developer software:** open `START-HERE-APK-FIRST.md` and use the included GitHub Actions workflow.


**Version:** 0.1.0 | **Platforms:** Android + Windows, from a single Flutter codebase.

> **IMPORTANT: DEVELOPMENT/TESTING PROTOTYPE — NOT SECURITY-AUDITED.** Do not use this build for meaningful funds or deposit cryptocurrency to its addresses before independent cryptography, UI, storage, network and packaging verification. It currently has **NO sending or signing support**. If cryptocurrency is deposited, this app cannot spend it; recovery in a compatible, reviewed wallet depends on correct seed/path/network support. Neither this project nor its author can recover lost phrases or reverse transfers.

## What works in source

- Creates a fresh 12-word English BIP39 recovery phrase with `Random.secure()` entropy.
- Requires confirmation of two words from a written backup before storing a new wallet.
- Imports a valid BIP39 recovery phrase (English, no optional BIP39 passphrase support).
- Derives first external receiving address only for:
  - **Bitcoin BTC mainnet** native SegWit `m/84'/0'/0'/0/0` (bc1q)
  - **Litecoin LTC mainnet** native SegWit `m/84'/2'/0'/0/0` (ltc1q)
  - **Ethereum ETH mainnet** EOA `m/44'/60'/0'/0/0` (0x)
  - **Tether USDT ERC-20, Ethereum mainnet only:** same 0x address as Ethereum, contract `0xdAC17F958D2ee523a2206206994597C13D831ec7`
- Shows public addresses, selectable address text and receive QR codes, with network-specific warnings.
- Keeps the BIP39 phrase in operating-system protected **`flutter_secure_storage`**. It is not sent to a server or printed to application logs. No login/account/backend.
- Shows an explicit manual **Refresh balances** button for BTC (mempool.space), ETH and Ethereum USDT (publicnode RPC). Only public addresses are transmitted. Provider downtime/error is displayed rather than mistaken for zero balance.
- Shows network-independent balance-unavailable status for Litecoin until a tested trusted Litecoin API is added.
- Allows revealing recovery words after an explicit warning, and deleting stored wallet after typing DELETE. Neither is gated by a real passcode in this release.
- Includes derivation unit tests with standard published mnemonic vectors.

## What does NOT work yet

- **No sending, transaction signing, fee estimation, swaps, trades, fiat/naira, credit/debit cards.** The app is deliberately receive-only.
- No app PIN, biometric/device authentication gate, hardware key protection, screenshot blocking, anti-tamper controls, malicious clipboard checks or security audit.
- No multiple accounts/addresses (index scanning, gap limit, change discovery), transaction history, pending balances, full UTXO accounting, non-English phrases or optional BIP39 passphrases.
- No real-time automatic push updates or forex conversion; balance requests are manually triggered and rely on third-party availability.
- No TRC-20, BEP-20, Polygon, Solana or other non-Ethereum USDT support.
- No binary APK/EXE included. Platform-specific binaries must be compiled on a machine with the appropriate SDKs.

## Why recovery may show a different balance

Compatible wallets can choose different derivation paths, accounts, script types or additional receiving indices. This project only derives the *first* BIP84 BTC/LTC address and first BIP44 Ethereum account. A phrase can be valid while the coins remain in other addresses that this prototype does not inspect. **Do not assume an empty balance means the wallet is empty.** An optional BIP39 passphrase changes ALL addresses: this prototype does not support passphrases.

## Install on Windows (beginner-friendly)

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) and add Flutter's `bin` directory to PATH.
2. Install **Visual Studio Community** with the *Desktop development with C++* workload and **C++ ATL** component for Windows builds. (Visual Studio Code alone is not enough.)
3. Install **Android Studio** with Android SDK/platform tools, and accept Android SDK licenses for APK builds.
4. Extract the downloaded source zip to a folder such as `C:\harbor_vault`.
5. Double-click **`SETUP-WINDOWS.bat`**. It creates `android/` and `windows/` platform scaffolding, patches Android permissions, fetches packages and runs tests. Internet connection required to install dependencies.
6. Double-click **`RUN-WINDOWS.bat`** to run on your Windows PC.
7. Double-click **`BUILD-ANDROID-APK.bat`** to create `build\app\outputs\flutter-apk\app-release.apk` for local testing on Android.
8. Double-click **`BUILD-WINDOWS-EXE.bat`** to compile release EXE and required data/DLL files in `build\windows\x64\runner\Release\`. Do not distribute the EXE without its accompanying folder.

Or from PowerShell in project directory:

```powershell
flutter doctor -v
flutter create --project-name harbor_vault --platforms android,windows .
powershell -ExecutionPolicy Bypass -File scripts\patch_android.ps1
flutter pub get
flutter test
flutter run -d windows
flutter build apk --release
flutter build windows --release
```

If Flutter reports a Windows build error, check Visual Studio C++ ATL support; `flutter_secure_storage` Windows needs it. Flutter secure storage minimum Android SDK is 23. Android release builds also require `android.permission.INTERNET` for on-demand balance queries, and cloud app backup is disabled to avoid restoring undecryptable secret blobs. The `SETUP-WINDOWS.bat` script applies these Android settings.

**For testing without real funds**, generate a new phrase, make an offline backup, confirm words, and check derived public addresses. Never share a phrase from an active wallet when asking for help. Test the known derivation vectors with `flutter test` before anything else.

## Security boundaries and risks

- OS protected encrypted storage is helpful but NOT a replacement for a wallet security audit or hardware wallet. Compromised Windows/Android sessions can steal secrets from memory or from on-screen recovery display.
- The app auto-opens to its wallet if a phrase is present; there is no app-access PIN in v0.1. Keep OS device access locked and do not reveal words around people or screen capture software.
- Secret phrases remain immutable Dart strings until garbage-collected; zeroization is not assured.
- The security model currently assumes a trusted package supply chain and trusted OS, and has not been independently assessed.
- Receiving addresses are MAINNET. This does **not** imply funds should be sent. Use the receive QR only for address-format tests until reviewed.
- Balance providers learn queried public addresses and IP metadata. If unavailable, an error appears. Balances are confirmed on BTC, not pending/mempool amounts.
- Users must inspect external code/dependencies and independently reproduce address derivation on a safe offline machine before deploying to funds.
- `bech32` has AGPL-family licensing terms with a lesser clause; review the package's COPYING file and license compliance before redistributing software, especially proprietary binaries.

## File structure

```
lib/main.dart                       responsive Flutter screens / UI
lib/models/asset.dart              supported chains and network labels
lib/services/wallet_engine.dart    BIP39/BIP32 address derivation
lib/services/vault_storage.dart    encrypted device storage
lib/services/balance_service.dart  manual PUBLIC balance lookups
test/wallet_engine_test.dart        standard derivation test vectors
scripts/patch_android.ps1          Android permission/backup configuration
SETUP-WINDOWS.bat                  Flutter platform setup and tests
RUN-WINDOWS.bat                    launch Windows debug build
BUILD-ANDROID-APK.bat              compile Android APK
BUILD-WINDOWS-EXE.bat              compile Windows desktop release
```

## Next development milestones

1. Complete integration/derivation tests on physical Android and Windows, including import/restore on a clean second device.
2. Add OS-enforced re-authentication and lockscreen for all private operations, and harden all recovery-phrase display paths.
3. Add full address discovery, transaction history, trusted redundant blockchain API configuration and correct pending accounting.
4. Add Litecoin balance lookup and ERC-20 token discovery.
5. Design, security-review and test transaction building/signing/broadcast on test networks before enabling ANY real-fund send flow.
6. Obtain an independent wallet security review and publish reproducible signed release builds.

## Independence

No backend, payment gateway, admin dashboard, naira, bank account, or custody arrangement is part of this personal wallet prototype. Regulatory requirements can change if it evolves into a business/platform for users.
