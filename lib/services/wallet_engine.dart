import 'dart:math';
import 'dart:typed_data';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:bech32/bech32.dart' as bech32;
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' show RIPEMD160Digest;
import 'package:web3dart/web3dart.dart' show EthPrivateKey;
import '../models/asset.dart';

/// No service, wallet address or telemetry receives the recovery phrase.
/// Derives only external receive address index zero; this is NOT a full wallet
/// index scanner or transaction signer.
class WalletEngine {
  static String createMnemonic() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256)));
    final entropyHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return bip39.entropyToMnemonic(entropyHex);
  }

  static String normalize(String phrase) => phrase.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');

  static bool validMnemonic(String phrase) => bip39.validateMnemonic(normalize(phrase));

  static PublicAddresses derive(String phrase) {
    final mnemonic = normalize(phrase);
    if (!bip39.validateMnemonic(mnemonic)) {
      throw const FormatException('Invalid BIP39 English recovery phrase.');
    }
    final root = bip32.BIP32.fromSeed(bip39.mnemonicToSeed(mnemonic));
    final btcPubkey = root.derivePath("m/84'/0'/0'/0/0").publicKey;
    final ltcPubkey = root.derivePath("m/84'/2'/0'/0/0").publicKey;
    final ethKey = root.derivePath("m/44'/60'/0'/0/0").privateKey;
    if (ethKey == null || ethKey.length != 32) {
      throw StateError('Could not derive Ethereum private key.');
    }
    final ethHex = ethKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final ethAddress = EthPrivateKey.fromHex(ethHex).address.hexEip55;
    return PublicAddresses(
      bitcoin: _segwit('bc', btcPubkey),
      ethereum: ethAddress,
      litecoin: _segwit('ltc', ltcPubkey),
    );
  }

  static String _segwit(String hrp, Uint8List compressedPublicKey) {
    final sha = Uint8List.fromList(crypto.sha256.convert(compressedPublicKey).bytes);
    final program = RIPEMD160Digest().process(sha);
    // Witness version 0, native SegWit P2WPKH (BIP173).
    return bech32.segwit.encode(bech32.Segwit(hrp, 0, program));
  }
}
