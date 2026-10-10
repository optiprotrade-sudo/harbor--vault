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

  test('known BIP84 Bitcoin and BIP44 Ethereum derivation vector', () {
    final addresses = WalletEngine.derive(known);
    expect(addresses.bitcoin, 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
    expect(addresses.ethereum.toLowerCase(), '0x9858effd232b4033e47d90003d41ec34ecaeda94');
    expect(addresses.litecoin, startsWith('ltc1q'));
  });
}
