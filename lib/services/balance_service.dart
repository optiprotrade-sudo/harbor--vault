import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset.dart';

/// Network lookups transmit PUBLIC addresses only, and only on Refresh.
/// HTTPS blockchain providers are third parties; their uptime is not guaranteed.
/// No seed/private key is used or transmitted here.
class BalanceService {
  static const ethereumRpc = 'https://ethereum-rpc.publicnode.com';
  static const bitcoinApi = 'https://mempool.space/api';
  static const tetherErc20 = '0xdac17f958d2ee523a2206206994597c13d831ec7';

  final http.Client _client;
  BalanceService([http.Client? client]) : _client = client ?? http.Client();

  Future<String> fetch(ChainAsset asset, String address) async {
    switch (asset) {
      case ChainAsset.btc:
        final response = await _client.get(Uri.parse('$bitcoinApi/address/$address'))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw Exception('Bitcoin explorer returned ${response.statusCode}');
        final j = jsonDecode(response.body) as Map<String, dynamic>;
        final stats = j['chain_stats'] as Map<String, dynamic>;
        final confirmedSat = (stats['funded_txo_sum'] as num).toInt() -
            (stats['spent_txo_sum'] as num).toInt();
        return _format(BigInt.from(confirmedSat), 8);
      case ChainAsset.eth:
        final result = await _rpc('eth_getBalance', [address, 'latest']);
        return _format(BigInt.parse(_hexValue(result), radix: 16), 18);
      case ChainAsset.usdt:
        final paddedAddress = address.substring(2).toLowerCase().padLeft(64, '0');
        final result = await _rpc('eth_call', [
          {'to': tetherErc20, 'data': '0x70a08231$paddedAddress'},
          'latest'
        ]);
        return _format(BigInt.parse(_hexValue(result), radix: 16), 6);
      case ChainAsset.ltc:
        throw UnsupportedError('Litecoin explorer not configured. Address generation is available.');
    }
  }

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final response = await _client.post(
      Uri.parse(ethereumRpc),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Ethereum RPC returned ${response.statusCode}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) throw Exception('Ethereum RPC error: ${body['error']}');
    return body['result'];
  }

  static String _hexValue(dynamic result) {
    if (result is! String || !result.startsWith('0x')) throw const FormatException('Invalid RPC result');
    final v = result.substring(2);
    return v.isEmpty ? '0' : v;
  }

  static String _format(BigInt amount, int decimals) {
    final base = BigInt.from(10).pow(decimals);
    final whole = amount ~/ base;
    final fractional = (amount % base).toString().padLeft(decimals, '0');
    final stripped = fractional.replaceFirst(RegExp(r'0+$'), '');
    return stripped.isEmpty ? '$whole' : '$whole.$stripped';
  }

  void dispose() => _client.close();
}
