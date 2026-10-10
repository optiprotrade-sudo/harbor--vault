import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/services/wallet_engine.dart';
import 'package:harbor_vault/models/wallet_listing.dart';
import 'package:harbor_vault/models/receive_network.dart';

void main() {
  test('supports both 12 and 24 word recovery phrases', () {
    for (final count in [12, 24]) {
      final phrase = WalletEngine.createMnemonic(words: count);
      expect(phrase.split(' '), hasLength(count));
      expect(WalletEngine.validMnemonic(phrase), isTrue);
    }
    expect(() => WalletEngine.createMnemonic(words: 15), throwsArgumentError);
  });

  test('shows expanded catalog including both USDT networks', () {
    expect(WalletListing.all.length, greaterThanOrEqualTo(17));
    final tron = WalletListing.forNetwork(ReceiveNetwork.usdtTrc20);
    final ethereum = WalletListing.forNetwork(ReceiveNetwork.usdtErc20);
    expect(tron.ticker, 'USDT');
    expect(ethereum.ticker, 'USDT');
    expect(tron.network, isNot(ethereum.network));
    expect(WalletListing.search('trc20'), isNotEmpty);
  });
}
