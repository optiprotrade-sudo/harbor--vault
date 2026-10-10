import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/models/asset.dart';
import 'package:harbor_vault/models/receive_network.dart';
import 'package:harbor_vault/models/wallet_listing.dart';
import 'package:harbor_vault/services/wallet_engine.dart';

void main() {
  const phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('TRC-20 is searchable and uses the separate TRON address', () {
    final results = WalletListing.search('TRC-20');
    expect(results.any((e) => e.network == ReceiveNetwork.usdtTrc20), isTrue);
    final addr = WalletEngine.derive(phrase);
    final token = WalletListing.forNetwork(ReceiveNetwork.usdtTrc20);
    expect(token.addressOf(addr), addr.tron);
    expect(token.addressOf(addr), isNot(addr.ethereum));
    expect(token.trackedAsset, ChainAsset.usdtTrc20);
    expect(token.network.nativeTicker, 'TRX');
  });

  test('EVM chain tokens share address but never imply a pooled balance', () {
    final addr = WalletEngine.derive(phrase);
    expect(ReceiveNetwork.usdcErc20.addressOf(addr), addr.ethereum);
    expect(ReceiveNetwork.usdcBase.addressOf(addr), addr.ethereum);
    expect(ReceiveNetwork.usdtBep20.addressOf(addr), addr.ethereum);
    expect(ReceiveNetwork.usdcBase.trackedAsset, isNull);
    expect(ReceiveNetwork.usdtBep20.trackedAsset, isNull);
    expect(ReceiveNetwork.usdcErc20.isToken, isTrue);
  });

  test('Search matches abbreviations and chain names', () {
    expect(WalletListing.search('usdt').length, 3);
    expect(WalletListing.search('TRC20').any((e) => e.network == ReceiveNetwork.usdtTrc20), isTrue);
    expect(WalletListing.search('base').any((e) => e.ticker == 'USDC'), isTrue);
    expect(WalletListing.search('', filter: 'Stablecoins').every((e) => e.isStablecoin), isTrue);
    expect(WalletListing.search('', filter: 'Native').every((e) => !e.isStablecoin), isTrue);
  });
}
