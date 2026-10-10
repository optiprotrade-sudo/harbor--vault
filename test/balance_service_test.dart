import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:harbor_vault/models/asset.dart';
import 'package:harbor_vault/services/balance_service.dart';

void main() {
  const ethAddress = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';

  test('Bitcoin confirmed balance subtracts spent outputs', () async {
    final service = BalanceService(MockClient((request) async {
      expect(request.url.host, 'mempool.space');
      return http.Response(jsonEncode({
        'chain_stats': {'funded_txo_sum': 145000000, 'spent_txo_sum': 25000000},
        'mempool_stats': {'funded_txo_sum': 90000, 'spent_txo_sum': 0}
      }), 200);
    }));
    expect(await service.fetch(ChainAsset.btc, 'bc1qtest'), '1.2');
    service.dispose();
  });

  test('Ethereum/USDT balances use public address only', () async {
    final methods = <String>[];
    final service = BalanceService(MockClient((request) async {
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      final method = payload['method'] as String;
      methods.add(method);
      expect(request.body.contains('abandon abandon'), isFalse);
      if (method == 'eth_getBalance') {
        expect((payload['params'] as List).first, ethAddress);
        return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0xde0b6b3a7640000'}), 200);
      }
      expect(method, 'eth_call');
      final params = payload['params'] as List;
      expect((params.first as Map)['data'].toString(), startsWith('0x70a08231'));
      return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x1ab3f0'}), 200); // 1.75 USDT
    }));
    expect(await service.fetch(ChainAsset.eth, ethAddress), '1');
    expect(await service.fetch(ChainAsset.usdt, ethAddress), '1.75');
    expect(methods, ['eth_getBalance', 'eth_call']);
    service.dispose();
  });

  test('Litecoin balance is explicitly unsupported rather than fabricated', () async {
    final service = BalanceService(MockClient((_) async => http.Response('{}', 200)));
    await expectLater(service.fetch(ChainAsset.ltc, 'ltc1test'), throwsUnsupportedError);
    service.dispose();
  });
}
