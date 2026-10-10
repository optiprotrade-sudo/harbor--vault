# Harbor Vault v0.7 - Multi-network Addresses & Fee Preview

This update **does not enable actual transfers**.

## Now present
- Main app's Assets, Receive, Send (review only), Security tabs.
- 5 tracked assets: BTC, ETH, LTC, ERC20 USDT, SOL. USD total covers only
  the tracked first addresses where both a balance AND a price are available.
- 11 receive network choices: Bitcoin, Litecoin, Ethereum, Ethereum ERC20 USDT,
  Solana, BNB Smart Chain, Polygon PoS, Base, Arbitrum One, OP Mainnet and
  Avalanche C-Chain. Same EVM account on EVM chains, separate ledgers.
- Solana ed25519 SLIP-0010 BIP44 0/0 derivation and public getBalance RPC.
- Fee estimates: Bitcoin via sat/vB, Litecoin via sat/kB, EVM via gas price,
  Solana illustrative 5000-lamport single-signature base amount.
- Send: choose coin/network, type recipient, amount, estimate indicative fee,
  review, and see an unambiguously disabled broadcast control. No signing.
- Tests for mnemonic path, SOL derivation vector, mock SOL balance, fee
  service, network model and price quotes.

## Still needed for a real wallet
- Address discovery across accounts and change addresses; accurate spendable
  confirmed balances, pending UTXOs, nonce/chain-id validation.
- Complete mainnet and testnet send engine with chain-aware transaction
  construction, EIP-1559, contract execution simulation/fee estimation,
  Bitcoin coin selection and change, Solana rent/priority fee, QR camera scans.
- Device PIN/biometric unlock before access and transactions, secure
  storage threat model, recovery testing, external security review.
- Real-time multi-network token lists, verified token contracts/mints,
  spam-token protection, authenticated provider endpoints.

No central custody, exchange, bank, or Naira integration.
