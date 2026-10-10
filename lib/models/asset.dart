import 'package:flutter/material.dart';

enum ChainAsset { btc, eth, ltc, usdt, sol, trx, usdtTrc20 }

extension ChainAssetInfo on ChainAsset {
  String get symbol => switch (this) {
        ChainAsset.btc => 'BTC',
        ChainAsset.eth => 'ETH',
        ChainAsset.ltc => 'LTC',
        ChainAsset.usdt || ChainAsset.usdtTrc20 => 'USDT',
        ChainAsset.sol => 'SOL',
        ChainAsset.trx => 'TRX',
      };
  String get name => switch (this) {
        ChainAsset.btc => 'Bitcoin',
        ChainAsset.eth => 'Ethereum',
        ChainAsset.ltc => 'Litecoin',
        ChainAsset.usdt => 'Tether USD (ERC-20)',
        ChainAsset.sol => 'Solana',
        ChainAsset.trx => 'TRON',
        ChainAsset.usdtTrc20 => 'Tether USD (TRC-20)',
      };
  String get network => switch (this) {
        ChainAsset.btc => 'Bitcoin · Mainnet · Native SegWit',
        ChainAsset.eth => 'Ethereum · Mainnet',
        ChainAsset.ltc => 'Litecoin · Mainnet · Native SegWit',
        ChainAsset.usdt => 'Ethereum · ERC-20 only',
        ChainAsset.sol => 'Solana · Mainnet · Native SOL',
        ChainAsset.trx => 'TRON · Mainnet · TRX',
        ChainAsset.usdtTrc20 => 'TRON · Mainnet · TRC-20 USDT',
      };
  String get path => switch (this) {
        ChainAsset.btc => "m/84'/0'/0'/0/0",
        ChainAsset.eth || ChainAsset.usdt => "m/44'/60'/0'/0/0",
        ChainAsset.ltc => "m/84'/2'/0'/0/0",
        ChainAsset.sol => "m/44'/501'/0'/0'",
        ChainAsset.trx || ChainAsset.usdtTrc20 => "m/44'/195'/0'/0/0",
      };
  Color get color => switch (this) {
        ChainAsset.btc => const Color(0xFFF4A63A),
        ChainAsset.eth => const Color(0xFF8993F0),
        ChainAsset.ltc => const Color(0xFF7FA9CD),
        ChainAsset.usdt || ChainAsset.usdtTrc20 => const Color(0xFF48C99C),
        ChainAsset.sol => const Color(0xFFB28CF6),
        ChainAsset.trx => const Color(0xFFFF596B),
      };
}

class PublicAddresses {
  final String bitcoin;
  final String ethereum;
  final String litecoin;
  final String solana;
  final String tron;

  const PublicAddresses({
    required this.bitcoin, required this.ethereum, required this.litecoin,
    required this.solana, required this.tron,
  });

  String of(ChainAsset asset) => switch (asset) {
        ChainAsset.btc => bitcoin,
        ChainAsset.eth || ChainAsset.usdt => ethereum,
        ChainAsset.ltc => litecoin,
        ChainAsset.sol => solana,
        ChainAsset.trx || ChainAsset.usdtTrc20 => tron,
      };
}
