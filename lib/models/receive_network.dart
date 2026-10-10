import 'asset.dart';

enum ReceiveNetwork {
  bitcoin, ethereum, litecoin, usdtErc20, solana,
  tron, usdtTrc20,
  bnbSmartChain, polygon, base, arbitrum, optimism, avalanche,
  usdcErc20, usdcBase, usdcArbitrum, usdtBep20,
}

extension ReceiveNetworkInfo on ReceiveNetwork {
  String get label => switch (this) {
    ReceiveNetwork.bitcoin => 'Bitcoin',
    ReceiveNetwork.ethereum => 'Ethereum (ERC-20 network)',
    ReceiveNetwork.litecoin => 'Litecoin',
    ReceiveNetwork.usdtErc20 => 'USDT (ERC-20)',
    ReceiveNetwork.solana => 'Solana',
    ReceiveNetwork.tron => 'TRX (TRON)',
    ReceiveNetwork.usdtTrc20 => 'USDT (TRC-20)',
    ReceiveNetwork.bnbSmartChain => 'BNB (BEP-20 network)',
    ReceiveNetwork.polygon => 'POL (Polygon)',
    ReceiveNetwork.base => 'ETH (Base)',
    ReceiveNetwork.arbitrum => 'ETH (Arbitrum)',
    ReceiveNetwork.optimism => 'ETH (Optimism)',
    ReceiveNetwork.avalanche => 'AVAX (Avalanche C-Chain)',
    ReceiveNetwork.usdcErc20 => 'USDC (ERC-20)',
    ReceiveNetwork.usdcBase => 'USDC (Base)',
    ReceiveNetwork.usdcArbitrum => 'USDC (Arbitrum)',
    ReceiveNetwork.usdtBep20 => 'USDT (BEP-20)',
  };

  String get nativeTicker => switch (this) {
    ReceiveNetwork.bitcoin => 'BTC',
    ReceiveNetwork.ethereum || ReceiveNetwork.usdtErc20 || ReceiveNetwork.usdcErc20 ||
    ReceiveNetwork.base || ReceiveNetwork.usdcBase || ReceiveNetwork.arbitrum ||
    ReceiveNetwork.usdcArbitrum || ReceiveNetwork.optimism => 'ETH',
    ReceiveNetwork.litecoin => 'LTC',
    ReceiveNetwork.solana => 'SOL',
    ReceiveNetwork.tron || ReceiveNetwork.usdtTrc20 => 'TRX',
    ReceiveNetwork.bnbSmartChain || ReceiveNetwork.usdtBep20 => 'BNB',
    ReceiveNetwork.polygon => 'POL',
    ReceiveNetwork.avalanche => 'AVAX',
  };

  String get transferTicker => switch (this) {
    ReceiveNetwork.usdtErc20 || ReceiveNetwork.usdtTrc20 || ReceiveNetwork.usdtBep20 => 'USDT',
    ReceiveNetwork.usdcErc20 || ReceiveNetwork.usdcBase || ReceiveNetwork.usdcArbitrum => 'USDC',
    _ => nativeTicker,
  };

  bool get isToken => switch (this) {
    ReceiveNetwork.usdtErc20 || ReceiveNetwork.usdtTrc20 || ReceiveNetwork.usdtBep20 ||
    ReceiveNetwork.usdcErc20 || ReceiveNetwork.usdcBase || ReceiveNetwork.usdcArbitrum => true,
    _ => false,
  };

  String get derivationPath => switch (this) {
    ReceiveNetwork.bitcoin => "m/84'/0'/0'/0/0",
    ReceiveNetwork.litecoin => "m/84'/2'/0'/0/0",
    ReceiveNetwork.solana => "m/44'/501'/0'/0'",
    ReceiveNetwork.tron || ReceiveNetwork.usdtTrc20 => "m/44'/195'/0'/0/0",
    _ => "m/44'/60'/0'/0/0",
  };

  bool get isEvm => switch (this) {
    ReceiveNetwork.bitcoin || ReceiveNetwork.litecoin || ReceiveNetwork.solana ||
    ReceiveNetwork.tron || ReceiveNetwork.usdtTrc20 => false,
    _ => true,
  };

  ChainAsset? get trackedAsset => switch (this) {
    ReceiveNetwork.bitcoin => ChainAsset.btc,
    ReceiveNetwork.litecoin => ChainAsset.ltc,
    ReceiveNetwork.ethereum => ChainAsset.eth,
    ReceiveNetwork.usdtErc20 => ChainAsset.usdt,
    ReceiveNetwork.solana => ChainAsset.sol,
    ReceiveNetwork.tron => ChainAsset.trx,
    ReceiveNetwork.usdtTrc20 => ChainAsset.usdtTrc20,
    _ => null,
  };

  String addressOf(PublicAddresses addresses) => switch (this) {
    ReceiveNetwork.bitcoin => addresses.bitcoin,
    ReceiveNetwork.litecoin => addresses.litecoin,
    ReceiveNetwork.solana => addresses.solana,
    ReceiveNetwork.tron || ReceiveNetwork.usdtTrc20 => addresses.tron,
    _ => addresses.ethereum,
  };

  String get caution => switch (this) {
    ReceiveNetwork.usdtErc20 => 'USDT on Ethereum ERC-20 ONLY. ETH is needed for contract transfer fees.',
    ReceiveNetwork.usdtTrc20 => 'USDT on TRON TRC-20 ONLY. This uses a T-starting TRON address, NOT the Ethereum address. TRX/Energy/Bandwidth may be needed for transfers.',
    ReceiveNetwork.usdtBep20 => 'USDT on BNB Smart Chain BEP-20 ONLY. Token contract and balance indexing are not configured; do not fund this experimental address yet.',
    ReceiveNetwork.usdcErc20 || ReceiveNetwork.usdcBase || ReceiveNetwork.usdcArbitrum => 'USDC is network-specific. Token contract verification and indexing are not implemented here. This is a receive-address preview only.',
    ReceiveNetwork.tron => 'TRON mainnet address begins with T. Activation and network resources may apply. Sending disabled.',
    ReceiveNetwork.solana => "SOL wallet address derived at m/44'/501'/0'/0'. SPL tokens additionally require mint/token-account discovery.",
    ReceiveNetwork.bitcoin => 'Bitcoin mainnet native SegWit (bc1). Only first receiving address; this is not a Lightning invoice.',
    ReceiveNetwork.litecoin => 'Litecoin mainnet native SegWit (ltc1), not a Bitcoin address.',
    _ => 'EVM address preview: separate networks may use identical address text but have different balances, token contracts and fees. Network-specific tracking/sending is not implemented for this entry.',
  };
}
