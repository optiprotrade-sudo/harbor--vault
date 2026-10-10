import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/services/wallet_engine.dart';

void main() {
  const known = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test('BIP39 generated mnemonic valid and is 12 words', () {
    final mnemonic = WalletEngine.createMnemonic();
    expect(mnemonic.split(' '), hasLength(12));
    expect(WalletEngine.validMnemonic(mnemonic), isTrue);
  });

  test('rejects malformed recovery phrase', () {
    expect(WalletEngine.validMnemonic('something that is not a valid phrase'), isFalse);
    expect(() => WalletEngine.derive('wrong'), throwsFormatException);
  });

  test('official TRON documented Base58Check address vector', () {
    // https://github.com/tronprotocol/documentation/blob/master/TRX/Tron-overview.md
    expect(
      WalletEngine.tronAddressFromEthHex('0x5a523b449890854c8fc460ab602df9f31fe4293f'),
      'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW',
    );
    expect(() => WalletEngine.tronAddressFromEthHex('0xzz'), throwsFormatException);
  });

  test('known BIP84 Bitcoin and BIP44 Ethereum derivation vector', () {
    final addresses = WalletEngine.derive(known);
    expect(addresses.bitcoin, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
    expect(addresses.ethereum.toLowerCase(), '0x9858effd232b4033e47d90003d41ec34ecaeda94');
    expect(addresses.litecoin, startsWith('ltc1q'));
    expect(addresses.solana, 'HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk');
    expect(addresses.tron, matches(RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$')));
    expect(addresses.tron, WalletEngine.derive(known).tron);
  });
}
