import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:harbor_vault/models/asset.dart';
import 'package:harbor_vault/services/balance_service.dart';

void main() {
  const ethAddress = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';
  const btcAddress = 'bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu';
  const tronAddress = 'TJCnKsPa7y5okkXvQAidZBzqx3QyQ6sxMW';

  test('BTC confirmed balance subtracts spent outputs without fallbacks', () async {
    final service = BalanceService(MockClient((request) async {
      expect(request.url.host, 'mempool.space');
      return http.Response(jsonEncode({
        'chain_stats': {'funded_txo_sum': 145000000, 'spent_txo_sum': 25000000},
        'mempool_stats': {'funded_txo_sum': 90000, 'spent_txo_sum': 0},
      }), 200);
    }));
    expect(await service.fetch(ChainAsset.btc, btcAddress), '1.2');
    service.dispose();
  });

  test('BTC retries Blockstream Esplora on rate limiting', () async {
    final hosts = <String>[];
    final service = BalanceService(MockClient((r) async {
      hosts.add(r.url.host);
      if (r.url.host == 'mempool.space') return http.Response('rate limited', 429);
      return http.Response(jsonEncode({
        'chain_stats': {'funded_txo_sum': 120000000, 'spent_txo_sum': 0},
      }), 200);
    }));
    expect(await service.fetch(ChainAsset.btc, btcAddress), '1.2');
    expect(hosts, ['mempool.space', 'blockstream.info']);
    service.dispose();
  });

  test('BTC double failure shows errors and NEVER fabricates zero', () async {
    final service = BalanceService(MockClient((r) async => http.Response('oops', 503)));
    await expectLater(service.fetch(ChainAsset.btc, btcAddress),
        throwsA(predicate((e) => e.toString().contains('503'))));
    service.dispose();
  });

  test('Ethereum/USDT ERC-20 balances use public address only', () async {
    final methods = <String>[];
    final service = BalanceService(MockClient((request) async {
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      methods.add(payload['method'].toString());
      expect(request.body.contains('abandon abandon'), isFalse);
      if (payload['method'] == 'eth_getBalance') {
        return http.Response(jsonEncode({'result': '0xde0b6b3a7640000'}), 200);
      }
      return http.Response(jsonEncode({'result': '0x1ab3f0'}), 200);
    }));
    expect(await service.fetch(ChainAsset.eth, ethAddress), '1');
    expect(await service.fetch(ChainAsset.usdt, ethAddress), '1.75');
    expect(methods, ['eth_getBalance', 'eth_call']);
    service.dispose();
  });

  test('TRON USDT TRC-20 checks the correct contract and decodes six decimals', () async {
    final service = BalanceService(MockClient((r) async {
      expect(r.url.host, 'api.trongrid.io');
      expect(r.url.path, '/v1/accounts/$tronAddress/trc20/balance');
      expect(r.url.queryParameters['contract_address'], BalanceService.tetherTrc20);
      return http.Response(jsonEncode({'success': true, 'data': [
        {BalanceService.tetherTrc20: '12500420'}
      ]}), 200);
    }));
    expect(await service.fetch(ChainAsset.usdtTrc20, tronAddress), '12.50042');
    service.dispose();
  });

  test('TRON successful empty contract-filtered query = 0 USDT', () async {
    final service = BalanceService(MockClient((_) async =>
        http.Response(jsonEncode({'success': true, 'data': []}), 200)));
    expect(await service.fetch(ChainAsset.usdtTrc20, tronAddress), '0');
    service.dispose();
  });

  test('TRC-20 429 is reported, not converted to zero', () async {
    final service = BalanceService(MockClient((_) async => http.Response('rate limit', 429)));
    await expectLater(service.fetch(ChainAsset.usdtTrc20, tronAddress), throwsStateError);
    service.dispose();
  });

  test('TRX account balance uses six decimals', () async {
    final service = BalanceService(MockClient((r) async {
      expect(r.url.queryParameters['only_confirmed'], 'true');
      return http.Response(jsonEncode({'success': true, 'data': [
        {'balance': 15500000}
      ]}), 200);
    }));
    expect(await service.fetch(ChainAsset.trx, tronAddress), '15.5');
    service.dispose();
  });

  test('Litecoin confirmed balance returns satoshis', () async {
    final service = BalanceService(MockClient((r) async =>
        http.Response(jsonEncode({'balance': 120000000}), 200)));
    expect(await service.fetch(ChainAsset.ltc, 'ltc1qtest'), '1.2');
    service.dispose();
  });

  test('Solana lamports parse correctly', () async {
    final service = BalanceService(MockClient((r) async => http.Response(jsonEncode({
      'result': {'value': 1234567890}
    }), 200)));
    expect(await service.fetch(ChainAsset.sol, 'somePublicAddress'), '1.23456789');
    service.dispose();
  });
}
