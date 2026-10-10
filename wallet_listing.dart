import 'package:flutter/material.dart';
import 'asset.dart';
import 'receive_network.dart';

/// A curated, network-specific catalog. This is NOT token discovery, and does
/// not imply that balances/signing or arbitrary smart contracts are supported.
class WalletListing {
  final ReceiveNetwork network;
  final String name;
  final String ticker;
  final String networkTag;
  final bool isStablecoin;
  final Color color;
  const WalletListing(this.network, this.name, this.ticker, this.networkTag,
      this.color, {this.isStablecoin = false});

  ChainAsset? get trackedAsset => network.trackedAsset;
  bool get isIndexed => trackedAsset != null;
  String addressOf(PublicAddresses addresses) => network.addressOf(addresses);

  static const all = <WalletListing>[
    WalletListing(ReceiveNetwork.bitcoin, 'Bitcoin', 'BTC', 'Bitcoin', Color(0xFFF3A33A)),
    WalletListing(ReceiveNetwork.ethereum, 'Ethereum', 'ETH', 'ERC-20', Color(0xFF8C97FA)),
    WalletListing(ReceiveNetwork.arbitrum, 'Ethereum', 'ETH', 'Arbitrum', Color(0xFF8C97FA)),
    WalletListing(ReceiveNetwork.base, 'Ethereum', 'ETH', 'Base', Color(0xFF8C97FA)),
    WalletListing(ReceiveNetwork.bnbSmartChain, 'BNB', 'BNB', 'BEP-20', Color(0xFFF2C341)),
    WalletListing(ReceiveNetwork.solana, 'Solana', 'SOL', 'Solana', Color(0xFFB18CFA)),
    WalletListing(ReceiveNetwork.tron, 'TRON', 'TRX', 'TRON', Color(0xFFFF5B66)),
    WalletListing(ReceiveNetwork.litecoin, 'Litecoin', 'LTC', 'Litecoin', Color(0xFF95B8D9)),
    WalletListing(ReceiveNetwork.usdtTrc20, 'Tether USD', 'USDT', 'TRC-20', Color(0xFF57CEA8), isStablecoin: true),
    WalletListing(ReceiveNetwork.usdtErc20, 'Tether USD', 'USDT', 'ERC-20', Color(0xFF57CEA8), isStablecoin: true),
    WalletListing(ReceiveNetwork.usdtBep20, 'Tether USD', 'USDT', 'BEP-20', Color(0xFF57CEA8), isStablecoin: true),
    WalletListing(ReceiveNetwork.usdcErc20, 'USD Coin', 'USDC', 'ERC-20', Color(0xFF5DAAFF), isStablecoin: true),
    WalletListing(ReceiveNetwork.usdcBase, 'USD Coin', 'USDC', 'Base', Color(0xFF5DAAFF), isStablecoin: true),
    WalletListing(ReceiveNetwork.usdcArbitrum, 'USD Coin', 'USDC', 'Arbitrum', Color(0xFF5DAAFF), isStablecoin: true),
    WalletListing(ReceiveNetwork.polygon, 'Polygon', 'POL', 'Polygon', Color(0xFFB28BFA)),
    WalletListing(ReceiveNetwork.optimism, 'Ethereum', 'ETH', 'Optimism', Color(0xFF8C97FA)),
    WalletListing(ReceiveNetwork.avalanche, 'Avalanche', 'AVAX', 'C-Chain', Color(0xFFFD696B)),
  ];

  static WalletListing forNetwork(ReceiveNetwork network) =>
      all.firstWhere((entry) => entry.network == network);

  static List<WalletListing> search(String value, {String filter = 'All'}) {
    final query = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return all.where((item) {
      if (filter == 'Stablecoins' && !item.isStablecoin) return false;
      if (filter == 'Native' && item.isStablecoin) return false;
      final text = '${item.name} ${item.ticker} ${item.networkTag} ${item.network.label}'
          .toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return query.isEmpty || text.contains(query);
    }).toList(growable: false);
  }
}
