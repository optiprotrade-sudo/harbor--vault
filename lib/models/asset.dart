import 'package:flutter/material.dart';

enum ChainAsset { btc, eth, ltc, usdt }

extension ChainAssetInfo on ChainAsset {
  String get symbol => switch (this) {
        ChainAsset.btc => 'BTC',
        ChainAsset.eth => 'ETH',
        ChainAsset.ltc => 'LTC',
        ChainAsset.usdt => 'USDT',
      };
  String get name => switch (this) {
        ChainAsset.btc => 'Bitcoin',
        ChainAsset.eth => 'Ethereum',
        ChainAsset.ltc => 'Litecoin',
        ChainAsset.usdt => 'Tether USD',
      };
  String get network => switch (this) {
        ChainAsset.btc => 'Bitcoin · Mainnet · Native SegWit',
        ChainAsset.eth => 'Ethereum · Mainnet',
        ChainAsset.ltc => 'Litecoin · Mainnet · Native SegWit',
        ChainAsset.usdt => 'Ethereum · ERC-20 ONLY',
      };
  String get path => switch (this) {
        ChainAsset.btc => "m/84'/0'/0'/0/0",
        ChainAsset.eth => "m/44'/60'/0'/0/0",
        ChainAsset.ltc => "m/84'/2'/0'/0/0",
        ChainAsset.usdt => "m/44'/60'/0'/0/0",
      };
  Color get color => switch (this) {
        ChainAsset.btc => const Color(0xFFF4A63A),
        ChainAsset.eth => const Color(0xFF8993F0),
        ChainAsset.ltc => const Color(0xFF7FA9CD),
        ChainAsset.usdt => const Color(0xFF48C99C),
      };
}

class PublicAddresses {
  final String bitcoin;
  final String ethereum;
  final String litecoin;
  const PublicAddresses({required this.bitcoin, required this.ethereum, required this.litecoin});

  String of(ChainAsset asset) => switch (asset) {
        ChainAsset.btc => bitcoin,
        ChainAsset.eth || ChainAsset.usdt => ethereum,
        ChainAsset.ltc => litecoin,
      };
}
