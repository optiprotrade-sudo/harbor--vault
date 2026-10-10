import 'asset.dart';

enum ReceiveNetwork {
  bitcoin, ethereum, litecoin, usdtErc20, solana,
  bnbSmartChain, polygon, base, arbitrum, optimism, avalanche,
}

extension ReceiveNetworkInfo on ReceiveNetwork {
  String get label => switch (this) {
    ReceiveNetwork.bitcoin => 'Bitcoin',
    ReceiveNetwork.ethereum => 'Ethereum',
    ReceiveNetwork.litecoin => 'Litecoin',
    ReceiveNetwork.usdtErc20 => 'USDT (Ethereum ERC-20)',
    ReceiveNetwork.solana => 'Solana',
    ReceiveNetwork.bnbSmartChain => 'BNB Smart Chain',
    ReceiveNetwork.polygon => 'Polygon PoS',
    ReceiveNetwork.base => 'Base',
    ReceiveNetwork.arbitrum => 'Arbitrum One',
    ReceiveNetwork.optimism => 'OP Mainnet',
    ReceiveNetwork.avalanche => 'Avalanche C-Chain',
  };

  String get nativeTicker => switch (this) {
    ReceiveNetwork.bitcoin => 'BTC',
    ReceiveNetwork.ethereum || ReceiveNetwork.base || ReceiveNetwork.arbitrum || ReceiveNetwork.optimism => 'ETH',
    ReceiveNetwork.litecoin => 'LTC',
    ReceiveNetwork.usdtErc20 => 'ETH', // gas token, not transferred token
    ReceiveNetwork.solana => 'SOL',
    ReceiveNetwork.bnbSmartChain => 'BNB',
    ReceiveNetwork.polygon => 'POL',
    ReceiveNetwork.avalanche => 'AVAX',
  };

  String get transferTicker => switch (this) {
    ReceiveNetwork.usdtErc20 => 'USDT',
    _ => nativeTicker,
  };

  String get derivationPath => switch (this) {
    ReceiveNetwork.bitcoin => "m/84'/0'/0'/0/0",
    ReceiveNetwork.litecoin => "m/84'/2'/0'/0/0",
    ReceiveNetwork.solana => "m/44'/501'/0'/0'",
    _ => "m/44'/60'/0'/0/0",
  };

  bool get isEvm => switch (this) {
    ReceiveNetwork.bitcoin || ReceiveNetwork.litecoin || ReceiveNetwork.solana => false,
    _ => true,
  };

  ChainAsset? get trackedAsset => switch (this) {
    ReceiveNetwork.bitcoin => ChainAsset.btc,
    ReceiveNetwork.litecoin => ChainAsset.ltc,
    ReceiveNetwork.ethereum => ChainAsset.eth,
    ReceiveNetwork.usdtErc20 => ChainAsset.usdt,
    ReceiveNetwork.solana => ChainAsset.sol,
    _ => null,
  };

  String addressOf(PublicAddresses addresses) => switch (this) {
    ReceiveNetwork.bitcoin => addresses.bitcoin,
    ReceiveNetwork.litecoin => addresses.litecoin,
    ReceiveNetwork.solana => addresses.solana,
    _ => addresses.ethereum,
  };

  String get caution => switch (this) {
    ReceiveNetwork.usdtErc20 => 'ONLY Ethereum ERC-20 USDT. This is not a TRON, BSC or Solana USDT address.',
    ReceiveNetwork.solana => "Solana uses a different key and address. Derived at m/44'/501'/0'/0'. Check restoration compatibility.",
    ReceiveNetwork.bitcoin => 'Bitcoin mainnet native SegWit (bc1). Not a Lightning invoice or another chain.',
    ReceiveNetwork.litecoin => 'Litecoin mainnet native SegWit (ltc1). Not a Bitcoin address.',
    _ => 'EVM account address. It looks identical across EVM chains but each chain has SEPARATE balances and fees. Confirm the correct network with the sender.',
  };
}
