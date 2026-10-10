# Harbor Vault v0.9 — Network catalog and Send UI

Inspired by the user's screenshots, NOT a copy of a third-party wallet.

- Search/filter asset list with network-labelled rows.
- 17 curated network/coin combinations (not 17 indexed balances): Bitcoin,
  Ethereum mainnet/Base/Arbitrum/Optimism, BNB/BSC, Polygon, Avalanche,
  Solana, Litecoin, TRX, USDT ERC-20/TRC-20/BEP-20, and USDC ERC-20/Base/Arbitrum.
- USDT TRC-20 prominently visible in Assets, Receive, and Send pickers.
- Wallet address and selected network, recipient Paste, amount, read-only USD
  equivalent when quote exists, and prominent Next/Review dialog.
- MAX explains it is disabled until verified spendable balance/fee computation.
- BTC/LTC fee tier choices use different provider fee fields (size is illustrative).
- Standard EVM fee only; TRON Energy fee explicitly unavailable.
- Broadcast always disabled. Does NOT sign or access private keys.
- Unindexed chain/token rows explicitly display "Address only" and no fake $0.
- No unverified TON/GRAM/SFP/MAG7 token balance claims or synthetic addresses.

### Build and security

This update is source code, not an APK. Run Flutter tests and build via GitHub
Actions. Neither GitHub compilation nor blockchain-signing validation has been
performed in this environment. Do not use it to store real funds.
