# Harbor Vault v1.0 — Consolidated personal beta

This is a *single source update* built on the Harbor Vault v0.9 catalog and the TRON/Bitcoin provider fixes from v0.8. If your installed APK still says v0.8, it is an old APK. You must build the new source from GitHub Actions, download the latest APK and install it.

## Included

- Searchable **17-entry asset/network catalog**, including TRX, Solana, USDT (TRC-20), USDT (ERC-20), USDT (BEP-20), USDC on selected networks, and EVM network address previews.
- Screenshot-inspired Send **review-only** screen: coin picker, wallet label, Paste, amount, USD equivalent, fee tiers where data exists, and review modal. **No signing or broadcasting.** MAX and scanning are not active.
- Owner-only local panel for renaming the wallet, checking recovery backup, locking, and copying public addresses. It is *not* a website admin panel.
- BIP39 12- and 24-word creation, import and checksum validation; local, encrypted storage.
- Device PIN/pattern/passcode or fingerprint unlock using Android device authentication (no custom Harbor Vault PIN).
- Lock on background; authenticate before revealing or deleting recovery phrase.
- Transaction-history screen for selected public first addresses where public provider data is available. This is **not** comprehensive history or address discovery.
- Fee-rate estimates are indicative. Some token fees and TRON resources cannot yet be computed accurately.
- Bitcoin explorer fallback for balance reads, TRON USDT balance read via its published contract, and independent address derivations.

## Critical limitations

**Do not hold real money in this beta.** Wallet is NOT audited. It currently derives only the first address of account zero and does not discover other addresses/accounts. Many entries are address-only previews. Public-provider balances can fail. Ethereum token receive behavior does not automatically imply full contract support or signing. SOL and TRON compatibility must be independently checked against reference implementations and recovery in other trusted wallets.

No built-in swaps, account creation backend, custodial functions, remote transfers, QR scanner, live broadcast, or safe spendable balance calculation. There is no audited transaction signer for Bitcoin, Ethereum, Litecoin, Solana, TRON or tokens. The fee quote is not final.

## Device installation

Keep the same Android application ID `com.harborvault.harbor_vault` and signing certificate across upgrades, or Android may reject the update. Before ANY uninstall, verify an offline paper recovery backup. Releasing through GitHub Actions uses the project's development signing configuration and is NOT a commercial production release.

## How to build

Upload project source to your private repository **with `.github/workflows/build-android-apk.yml` at the repository root**. In GitHub, open **Actions → Build Harbor Vault Android APK → Run workflow**. Check tests and retrieve the generated APK artifact if the run succeeds.
