import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/asset.dart';

/// Public market quotes for display only. No wallet addresses or secrets are
/// submitted to this endpoint. Quotes can be delayed or temporarily unavailable.
class PriceService {
  static final Uri endpoint = Uri.parse(
    'https://api.coingecko.com/api/v3/simple/price'
    '?ids=bitcoin,ethereum,litecoin,tether,solana&vs_currencies=usd',
  );

  final http.Client _client;
  PriceService([http.Client? client]) : _client = client ?? http.Client();

  Future<Map<ChainAsset, double>> fetchUsd() async {
    final response = await _client.get(
      endpoint,
      headers: const {'accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Price provider returned ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected price response');
    }
    const ids = <ChainAsset, String>{
      ChainAsset.btc: 'bitcoin',
      ChainAsset.eth: 'ethereum',
      ChainAsset.ltc: 'litecoin',
      ChainAsset.usdt: 'tether',
      ChainAsset.sol: 'solana',
    };
    final prices = <ChainAsset, double>{};
    for (final entry in ids.entries) {
      final coin = decoded[entry.value];
      if (coin is! Map<String, dynamic>) continue;
      final quote = coin['usd'];
      if (quote is! num) continue;
      final value = quote.toDouble();
      if (value.isFinite && value > 0) prices[entry.key] = value;
    }
    if (prices.isEmpty) {
      throw const FormatException('No usable USD quotes returned');
    }
    return prices;
  }

  void dispose() => _client.close();
}
