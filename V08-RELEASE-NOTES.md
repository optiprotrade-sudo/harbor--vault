# Harbor Vault v0.8 — TRON TRC-20 and Bitcoin reliability

This package updates the existing v0.7 Flutter project. It is still a **receive-only and send-review-only prototype**, not a wallet for live deposits or transfers.

## New features
- **TRON (TRX) mainnet** receiving address derived at `m/44'/195'/0'/0/0`, displayed with a `T` prefix.
- **Tether USD on TRON (USDT TRC-20)** as a separate asset from Ethereum ERC-20 USDT. It uses the TRON address and authentic contract `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t` (6 decimals).
- **TRX and TRC-20 USDT balance checks** using public TronGrid endpoints, with provider failures shown as errors rather than zeros. TronGrid may impose rate limits or require an API key.
- **Bitcoin balance retry:** first `mempool.space`, then `blockstream.info`, both using the public Esplora address endpoint and confirmed outputs. If both fail, the app displays a diagnostic in the expanded Bitcoin card.
- **TRX USD quote** through CoinGecko; ERC-20 and TRC-20 balances count independently.
- **TRON network option** in the review-only Send interface.

## Limits that remain
- **No transaction signing, construction, or broadcasting.** "Send" still cannot move coins.
- **No TRON network fee quote:** Energy/Bandwidth, resource ownership and possible TRX burn vary per actual operation. We deliberately do not invent an amount.
- Bitcoin address check uses the first `bc1` derived address only; it is not an account-discovery wallet.
- TRON fee estimation, token indexing beyond USDT, account activation, historical scanning and independent recovery-compatibility checks remain unfinished.
- Secrets remain on-device; only **public addresses** go to remote explorers.
- Neither the APK nor the cryptography has been independently audited.

## Technical sources
- https://developers.tron.network/docs/wallet-developer-guide
- https://developers.tron.network/docs/account
- https://developers.tron.network/es/reference/get-trc20-token-balances-by-address
- https://tether.to/en/supported-protocols/
- https://github.com/blockstream/esplora/blob/master/API.md
