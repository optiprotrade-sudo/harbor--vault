import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:harbor_vault/models/asset.dart';
import 'package:harbor_vault/services/price_service.dart';

void main() {
  test('CoinGecko USD quotes parse all four assets', () async {
    final service = PriceService(MockClient((request) async {
      expect(request.url.host, 'api.coingecko.com');
      expect(request.url.queryParameters['vs_currencies'], 'usd');
      expect(request.url.queryParameters['ids'], 'bitcoin,ethereum,litecoin,tether');
      return http.Response(jsonEncode({
        'bitcoin': {'usd': 72000},
        'ethereum': {'usd': 3000.5},
        'litecoin': {'usd': 110},
        'tether': {'usd': 0.998},
      }), 200);
    }));
    final quotes = await service.fetchUsd();
    expect(quotes[ChainAsset.btc], 72000);
    expect(quotes[ChainAsset.eth], 3000.5);
    expect(quotes[ChainAsset.ltc], 110);
    expect(quotes[ChainAsset.usdt], .998);
    service.dispose();
  });

  test('Invalid or missing quotes are never replaced with invented prices', () async {
    final service = PriceService(MockClient((_) async => http.Response(
      jsonEncode({'bitcoin': {'usd': -1}, 'tether': {'usd': 1}}), 200)));
    final prices = await service.fetchUsd();
    expect(prices.containsKey(ChainAsset.btc), isFalse);
    expect(prices[ChainAsset.usdt], 1);
    expect(prices.containsKey(ChainAsset.ltc), isFalse);
    service.dispose();
  });

  test('Price provider error is explicitly reported', () async {
    final service = PriceService(MockClient((_) async => http.Response('limit', 429)));
    await expectLater(service.fetchUsd(), throwsStateError);
    service.dispose();
  });
}
