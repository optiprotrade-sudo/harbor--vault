# Harbor Vault v0.8

Android-first prototype of a personal self-custodial multi-chain wallet.

Read `V08-APPLY-TO-GITHUB.txt` to upgrade an existing GitHub repository. Read `V08-RELEASE-NOTES.md` for the complete change list and safety limitations.

Supported first receiving addresses: native-SegWit BTC, native-SegWit LTC, Ethereum ETH / ERC-20 USDT, Solana SOL, TRON TRX / TRC-20 USDT. Also shows major EVM networks sharing the EVM `0x` address, without pretending to scan all balances. Mainnet sending is disabled.

Build via `.github/workflows/build-android-apk.yml` → Actions → Run workflow. Flutter tests run before the APK is built. The output is an APK inside the GitHub Actions artifact.

**Do not deposit real money.** No PIN, biometric lock, audited derivation, account discovery, broadcast engine, or independent security audit is provided.
