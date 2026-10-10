import 'dart:math';
import 'dart:typed_data';

import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bech32/bech32.dart' as bech32;
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' show RIPEMD160Digest;
import 'package:web3dart/web3dart.dart' show EthPrivateKey;
import 'package:solana_sdk/solana_sdk.dart' show Keypair, DerivationPath;

import '../models/asset.dart';

/// Receive-address demo. It derives ONLY account zero, external address zero.
/// Not a scanner or a transaction signer. Not audited for real funds.
class WalletEngine {
  static String createMnemonic() {
    final random = Random.secure();
    final entropy = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    return bip39.Mnemonic(entropy, bip39.Language.english).sentence;
  }

  static String normalize(String phrase) =>
      phrase.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');

  static bool validMnemonic(String phrase) {
    try {
      bip39.Mnemonic.fromSentence(normalize(phrase), bip39.Language.english);
      return true;
    } catch (_) {
      return false;
    }
  }

  static PublicAddresses derive(String phrase) {
    final normalized = normalize(phrase);
    if (!validMnemonic(normalized)) {
      throw const FormatException('Invalid BIP39 English recovery phrase.');
    }

    final mnemonic = bip39.Mnemonic.fromSentence(
      normalized,
      bip39.Language.english,
    );
    final root = bip32.Bip32Keys.fromSeed(
      Uint8List.fromList(mnemonic.seed),
    );

    // bip32_keys v3 exposes .public and .private (not .publicKey/.privateKey).
    final btcPublicKey = root.derivePath("m/84'/0'/0'/0/0").public;
    final ltcPublicKey = root.derivePath("m/84'/2'/0'/0/0").public;
    final ethPrivateKey = root.derivePath("m/44'/60'/0'/0/0").private;
    if (ethPrivateKey == null || ethPrivateKey.length != 32) {
      throw StateError('Could not derive Ethereum private key.');
    }

    final ethHex = ethPrivateKey
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    // web3dart 3.0.3 uses wallet 0.0.18 EthereumAddress.eip55With0x.
    // USDT on Ethereum uses the same account address.
    final ethereumAddress = EthPrivateKey.fromHex(ethHex).address.eip55With0x;

    // Solana uses hardened Ed25519 / SLIP-0010, not an EVM address.
    // This path is ONE commonly-used Solana convention; other wallet apps
    // may use m/44'/501'/0' or other account indexes.
    final solanaKeypair = Keypair.fromSeedAndDerivationPath(
      Uint8List.fromList(mnemonic.seed),
      DerivationPath.bip44(account: 0, change: 0),
    );
    final solanaAddress = solanaKeypair.publicKey.toString();

    return PublicAddresses(
      bitcoin: _nativeSegwitAddress('bc', btcPublicKey),
      ethereum: ethereumAddress,
      litecoin: _nativeSegwitAddress('ltc', ltcPublicKey),
      solana: solanaAddress,
    );
  }

  static String _nativeSegwitAddress(String hrp, Uint8List compressedPublicKey) {
    final sha256 = Uint8List.fromList(
      crypto.sha256.convert(compressedPublicKey).bytes,
    );
    final hash160 = RIPEMD160Digest().process(sha256);
    return bech32.segwit.encode(bech32.Segwit(hrp, 0, hash160));
  }
}
