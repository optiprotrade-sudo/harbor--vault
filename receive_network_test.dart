import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/models/receive_network.dart';
import 'package:harbor_vault/services/wallet_engine.dart';

void main() {
  const phrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  test('EVM display networks use same public account without claiming pooled funds', () {
    final a = WalletEngine.derive(phrase);
    expect(ReceiveNetwork.ethereum.addressOf(a), ReceiveNetwork.base.addressOf(a));
    expect(ReceiveNetwork.ethereum.addressOf(a), ReceiveNetwork.bnbSmartChain.addressOf(a));
    expect(ReceiveNetwork.ethereum.addressOf(a), ReceiveNetwork.polygon.addressOf(a));
    expect(ReceiveNetwork.solana.addressOf(a), isNot(ReceiveNetwork.ethereum.addressOf(a)));
    expect(ReceiveNetwork.solana.derivationPath, "m/44'/501'/0'/0'");
    expect(ReceiveNetwork.base.trackedAsset, isNull);
    expect(ReceiveNetwork.usdtTrc20.addressOf(a), a.tron);
    expect(ReceiveNetwork.tron.addressOf(a), a.tron);
    expect(ReceiveNetwork.usdtErc20.addressOf(a), a.ethereum);
    expect(a.tron, isNot(a.ethereum));
    expect(a.tron, matches(RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$')));
    expect(ReceiveNetwork.usdtTrc20.isEvm, isFalse);
    expect(ReceiveNetwork.usdtTrc20.derivationPath, "m/44'/195'/0'/0/0");
  });
}
