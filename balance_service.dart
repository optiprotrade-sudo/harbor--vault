import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/asset.dart';

/// Public-address lookups ONLY; no recovery phrases/private keys are sent.
/// Provider uptime / rate limits are not guaranteed. Missing != zero.
class BalanceService {
  static const ethereumRpc = 'https://ethereum-rpc.publicnode.com';
  static const bitcoinApi = 'https://mempool.space/api';
  static const bitcoinBackupApi = 'https://blockstream.info/api';
  static const litecoinApi = 'https://api.blockcypher.com/v1/ltc/main';
  static const solanaRpc = 'https://api.mainnet-beta.solana.com';
  static const tronGridApi = 'https://api.trongrid.io';
  static const tetherErc20 = '0xdac17f958d2ee523a2206206994597c13d831ec7';
  // Official TRON-mainnet USDT contract. NOT interchangeable with ERC20 USDT.
  static const tetherTrc20 = 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';

  final http.Client _client;
  BalanceService([http.Client? client]) : _client = client ?? http.Client();

  Future<String> fetch(ChainAsset asset, String address) async {
    switch (asset) {
      case ChainAsset.btc:
        return _bitcoinWithFallback(address);
      case ChainAsset.eth:
        final result = await _rpc('eth_getBalance', [address, 'latest']);
        return _format(BigInt.parse(_hexValue(result), radix: 16), 18);
      case ChainAsset.usdt:
        if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address)) {
          throw const FormatException('Invalid Ethereum address');
        }
        final paddedAddress = address.substring(2).toLowerCase().padLeft(64, '0');
        final result = await _rpc('eth_call', [
          {'to': tetherErc20, 'data': '0x70a08231$paddedAddress'},
          'latest'
        ]);
        return _format(BigInt.parse(_hexValue(result), radix: 16), 6);
      case ChainAsset.sol:
        final response = await _client.post(
          Uri.parse(solanaRpc),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0', 'id': 1, 'method': 'getBalance',
            'params': [address, {'commitment': 'confirmed'}]
          }),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw StateError('Solana RPC HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['error'] != null) throw StateError('Solana RPC error');
        final result = decoded['result'];
        if (result is! Map || result['value'] is! num) {
          throw const FormatException('Solana balance missing');
        }
        return _format(BigInt.from((result['value'] as num).toInt()), 9);
      case ChainAsset.ltc:
        final response = await _client.get(
          Uri.parse('$litecoinApi/addrs/$address/balance'),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw StateError('Litecoin explorer HTTP ${response.statusCode}');
        }
        final j = jsonDecode(response.body) as Map<String, dynamic>;
        final sats = j['balance'];
        if (sats is! num) throw const FormatException('Missing confirmed LTC');
        return _format(BigInt.from(sats.toInt()), 8);
      case ChainAsset.trx:
        final account = await _tronAccount(address);
        final rawTrx = account['balance'];
        if (rawTrx == null) return '0'; // confirmed account without TRX
        if (rawTrx is! int || rawTrx < 0) {
          throw const FormatException('Invalid confirmed TRX balance');
        }
        return _format(BigInt.from(rawTrx), 6);
      case ChainAsset.usdtTrc20:
        return _tronUsdtBalance(address);
    }
  }

  Future<String> _bitcoinWithFallback(String address) async {
    // Esplora backends return the same confirmed balance schema.
    if (!RegExp(r'^bc1[ac-hj-np-z02-9]{11,87}$').hasMatch(address)) {
      throw const FormatException('Invalid bc1 Bitcoin receive address format');
    }
    final reasons = <String>[];
    for (final base in [bitcoinApi, bitcoinBackupApi]) {
      final host = Uri.parse(base).host;
      try {
        final r = await _client.get(Uri.parse('$base/address/$address'))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) {
          reasons.add('$host HTTP ${r.statusCode}');
          continue;
        }
        final json = jsonDecode(r.body);
        if (json is! Map<String, dynamic>) {
          reasons.add('$host invalid JSON');
          continue;
        }
        final stats = json['chain_stats'];
        if (stats is! Map || stats['funded_txo_sum'] is! num ||
            stats['spent_txo_sum'] is! num) {
          reasons.add('$host missing balance fields');
          continue;
        }
        final funded = (stats['funded_txo_sum'] as num).toInt();
        final spent = (stats['spent_txo_sum'] as num).toInt();
        if (funded < 0 || spent < 0 || spent > funded) {
          reasons.add('$host invalid satoshi totals');
          continue;
        }
        return _format(BigInt.from(funded - spent), 8);
      } catch (e) {
        // Only retain a short, sanitized provider failure string.
        reasons.add('$host request failed');
      }
    }
    throw StateError('BTC sources failed: ${reasons.join('; ')}');
  }

  static bool _validTron(String address) =>
      RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(address);

  Future<Map<String, dynamic>> _tronAccount(String address) async {
    if (!_validTron(address)) throw const FormatException('Invalid TRON address');
    final url = Uri.parse('$tronGridApi/v1/accounts/$address?only_confirmed=true');
    final response = await _client.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('TRON explorer HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true || decoded['data'] is! List) {
      throw const FormatException('TRON explorer returned an invalid response');
    }
    final accounts = decoded['data'] as List;
    if (accounts.isEmpty) return {'balance': 0}; // valid but not yet activated
    if (accounts.first is! Map<String, dynamic>) {
      throw const FormatException('TRON account is invalid');
    }
    return accounts.first as Map<String, dynamic>;
  }

  Future<String> _tronUsdtBalance(String address) async {
    if (!_validTron(address)) throw const FormatException('Invalid TRON address');
    final uri = Uri.parse('$tronGridApi/v1/accounts/$address/trc20/balance')
        .replace(queryParameters: {'contract_address': tetherTrc20});
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('TRC-20 balance explorer HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true || decoded['data'] is! List) {
      throw const FormatException('TRC-20 provider returned an invalid response');
    }
    final entries = decoded['data'] as List;
    BigInt? amount;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final value = entry[tetherTrc20];
      if (value != null) {
        if (value is! String || !RegExp(r'^\d+$').hasMatch(value)) {
          throw const FormatException('Invalid TRC-20 raw balance');
        }
        amount = BigInt.parse(value);
        break;
      }
    }
    // A successful contract-filtered response omits tokens with zero balance.
    return _format(amount ?? BigInt.zero, 6);
  }

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final response = await _client.post(
      Uri.parse(ethereumRpc),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('Ethereum RPC HTTP ${response.statusCode}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) throw StateError('Ethereum RPC returned an error');
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
