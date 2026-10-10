import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/receive_network.dart';
import 'balance_service.dart';

/// Public-blockchain activity. No private keys or recovery phrases are used.
/// First derived address only; not a complete wallet-wide history/indexer.
class HistoryEntry {
  final String id;
  final DateTime? time;
  final bool confirmed;
  final String source;
  const HistoryEntry({required this.id, required this.time,
    required this.confirmed, required this.source});
}

class HistoryService {
  final http.Client _client;
  HistoryService([http.Client? client]) : _client = client ?? http.Client();

  Future<List<HistoryEntry>> fetch(ReceiveNetwork network, String address) async {
    switch (network) {
      case ReceiveNetwork.bitcoin:
        return _esplora(address);
      case ReceiveNetwork.litecoin:
        return _litecoin(address);
      case ReceiveNetwork.ethereum:
        return _ethereum(address);
      case ReceiveNetwork.solana:
        return _solana(address);
      case ReceiveNetwork.tron:
        return _tron(address);
      case ReceiveNetwork.usdtTrc20:
        return _tronUsdt(address);
      default:
        throw UnsupportedError('History for ${network.label} is not indexed yet.');
    }
  }

  Future<List<HistoryEntry>> _esplora(String address) async {
    for (final base in [BalanceService.bitcoinApi, BalanceService.bitcoinBackupApi]) {
      try {
        final response = await _client.get(Uri.parse('$base/address/$address/txs'))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! List) continue;
        return decoded.whereType<Map<String, dynamic>>().take(25).map((j) {
          final status = j['status'] is Map ? j['status'] as Map : const {};
          return HistoryEntry(id: '${j['txid'] ?? ''}',
            time: _unixSeconds(status['block_time']),
            confirmed: status['confirmed'] == true,
            source: Uri.parse(base).host);
        }).where((item) => item.id.isNotEmpty).toList();
      } catch (_) { /* Try the alternative Bitcoin explorer. */ }
    }
    throw StateError('Bitcoin transaction history is unavailable from both explorers.');
  }

  Future<List<HistoryEntry>> _litecoin(String address) async {
    final response = await _client.get(Uri.parse(
      '${BalanceService.litecoinApi}/addrs/$address/full?limit=20',
    )).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('Litecoin explorer HTTP ${response.statusCode}');
    final j = jsonDecode(response.body);
    if (j is! Map || j['txs'] is! List) throw const FormatException('Invalid Litecoin history');
    return (j['txs'] as List).whereType<Map<String, dynamic>>().map((tx) =>
      HistoryEntry(id: '${tx['hash'] ?? ''}', time: DateTime.tryParse('${tx['confirmed'] ?? tx['received'] ?? ''}'),
        confirmed: (tx['confirmations'] is num) && (tx['confirmations'] as num) > 0,
        source: 'api.blockcypher.com'))
      .where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<HistoryEntry>> _ethereum(String address) async {
    final response = await _client.get(Uri.parse(
      'https://eth.blockscout.com/api/v2/addresses/$address/transactions',
    )).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('Ethereum history provider HTTP ${response.statusCode}');
    final j = jsonDecode(response.body);
    if (j is! Map || j['items'] is! List) throw const FormatException('Invalid Ethereum history');
    return (j['items'] as List).whereType<Map<String, dynamic>>().take(30).map((tx) =>
      HistoryEntry(id: '${tx['hash'] ?? ''}',
        time: DateTime.tryParse('${tx['timestamp'] ?? ''}'),
        confirmed: tx['block_number'] != null,
        source: 'eth.blockscout.com'))
      .where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<HistoryEntry>> _solana(String address) async {
    final response = await _client.post(Uri.parse(BalanceService.solanaRpc),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'jsonrpc':'2.0','id':1,'method':'getSignaturesForAddress',
        'params':[address, {'limit':20}]})).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('Solana RPC HTTP ${response.statusCode}');
    final j = jsonDecode(response.body);
    if (j is! Map || j['error'] != null || j['result'] is! List) {
      throw const FormatException('Invalid Solana activity response');
    }
    return (j['result'] as List).whereType<Map<String, dynamic>>().map((tx) =>
      HistoryEntry(id: '${tx['signature'] ?? ''}', time: _unixSeconds(tx['blockTime']),
        confirmed: tx['confirmationStatus'] == 'confirmed' ||
          tx['confirmationStatus'] == 'finalized', source: 'Solana RPC'))
      .where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<HistoryEntry>> _tron(String address) async {
    final response = await _client.get(Uri.parse(
      '${BalanceService.tronGridApi}/v1/accounts/$address/transactions?limit=20'))
      .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('TRON explorer HTTP ${response.statusCode}');
    final j = jsonDecode(response.body);
    if (j is! Map || j['success'] != true || j['data'] is! List) {
      throw const FormatException('Invalid TRON activity response');
    }
    return (j['data'] as List).whereType<Map<String, dynamic>>().map((tx) =>
      HistoryEntry(id: '${tx['txID'] ?? ''}', time: _unixMillis(tx['block_timestamp']),
        confirmed: tx['blockNumber'] != null, source: 'api.trongrid.io'))
      .where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<HistoryEntry>> _tronUsdt(String address) async {
    final response = await _client.get(Uri.parse(
      '${BalanceService.tronGridApi}/v1/accounts/$address/transactions/trc20?limit=30'))
      .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('TRC-20 history HTTP ${response.statusCode}');
    final j = jsonDecode(response.body);
    if (j is! Map || j['success'] != true || j['data'] is! List) {
      throw const FormatException('Invalid TRC-20 activity response');
    }
    return (j['data'] as List).whereType<Map<String, dynamic>>()
      .where((tx) => tx['token_info'] is Map &&
        '${(tx['token_info'] as Map)['address']}' == BalanceService.tetherTrc20)
      .map((tx) => HistoryEntry(id: '${tx['transaction_id'] ?? ''}',
        time: _unixMillis(tx['block_timestamp']),
        confirmed: true, source: 'api.trongrid.io · USDT'))
      .where((item) => item.id.isNotEmpty).toList();
  }

  static DateTime? _unixSeconds(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt() * 1000, isUtc: true).toLocal() : null;
  static DateTime? _unixMillis(dynamic value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true).toLocal() : null;
  void dispose() => _client.close();
}
