import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:harbor_vault/models/receive_network.dart';
import 'package:harbor_vault/services/fee_service.dart';

void main() {
  test('Bitcoin planning fee uses live sat/vB and explicit sample size', () async {
    final fees = FeeService(MockClient((r) async {
      expect(r.url.host, 'mempool.space');
      return http.Response(jsonEncode({'halfHourFee': 10}), 200);
    }));
    final quote = await fees.estimate(ReceiveNetwork.bitcoin);
    expect(quote.estimate, '0.000014 BTC');
    expect(quote.detail, contains('140 vbytes'));
    expect(quote.live, true);
    fees.dispose();
  });
  test('EVM gas price gives a planning quote, not a fixed real fee', () async {
    final fees = FeeService(MockClient((r) async {
      expect(jsonDecode(r.body)['method'], 'eth_gasPrice');
      return http.Response(jsonEncode({'jsonrpc':'2.0','result':'0x3b9aca00'}), 200);
    }));
    final quote = await fees.estimate(ReceiveNetwork.ethereum);
    expect(quote.estimate, '0.000021 ETH');
    expect(quote.detail, contains('21,000'));
    fees.dispose();
  });
  test('USDT quote uses ETH for ERC20 gas, not USDT', () async {
    final fees = FeeService(MockClient((_) async => http.Response(
      jsonEncode({'result':'0x3b9aca00'}), 200)));
    final quote = await fees.estimate(ReceiveNetwork.usdtErc20);
    expect(quote.estimate, '0.000065 ETH');
    expect(quote.unit, 'ETH');
    fees.dispose();
  });
  test('Bitcoin Low / Standard / High are based on provider fields', () async {
    final fees = FeeService(MockClient((_) async => http.Response(jsonEncode({
      'economyFee': 3, 'halfHourFee': 5, 'fastestFee': 12,
    }), 200)));
    final low = await fees.estimate(ReceiveNetwork.bitcoin, priority: FeePriority.low);
    final middle = await fees.estimate(ReceiveNetwork.bitcoin);
    final high = await fees.estimate(ReceiveNetwork.bitcoin, priority: FeePriority.high);
    expect(low.estimate, '0.0000042 BTC');
    expect(middle.estimate, '0.000007 BTC');
    expect(high.estimate, '0.0000168 BTC');
    fees.dispose();
  });
  test('EVM nonstandard fee tiers do not invent quotes', () async {
    final fees = FeeService();
    await expectLater(fees.estimate(ReceiveNetwork.usdcBase,
      priority: FeePriority.low), throwsStateError);
    fees.dispose();
  });
  test('New token fee quotes use token-transfer gas assumptions', () async {
    final fees = FeeService(MockClient((r) async => http.Response(
      jsonEncode({'result':'0x3b9aca00'}), 200)));
    final usdc = await fees.estimate(ReceiveNetwork.usdcBase);
    expect(usdc.estimate, '0.000065 ETH');
    expect(usdc.detail, contains('Token transfer'));
    fees.dispose();
  });
  test('Provider failure is never replaced with a fake zero fee' , () async {
    final fees = FeeService(MockClient((_) async => http.Response('rate limit', 429)));
    await expectLater(fees.estimate(ReceiveNetwork.bitcoin), throwsStateError);
    fees.dispose();
  });
  test('TRON fee is unavailable rather than pretending TRC-20 gas costs zero', () async {
    final fees = FeeService();
    await expectLater(fees.estimate(ReceiveNetwork.usdtTrc20), throwsStateError);
    await expectLater(fees.estimate(ReceiveNetwork.tron), throwsStateError);
    fees.dispose();
  });

  test('Solana base fee is explicitly marked illustrative and not live', () async {
    final fees = FeeService();
    final quote = await fees.estimate(ReceiveNetwork.solana);
    expect(quote.estimate, '0.000005 SOL');
    expect(quote.live, false);
    fees.dispose();
  });
}
