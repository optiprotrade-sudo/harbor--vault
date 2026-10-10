import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/receive_network.dart';

enum FeePriority { low, standard, high }

/// Planning estimate ONLY. Does not sign, construct, or broadcast transactions.
/// In particular, EVM 21k gas is for an ordinary native-coin transfer, not a
/// contract interaction. L2 posting fees, UTXO counts, rent and token-account
/// creation are not included. Never use this as an authorization amount.
class FeeQuote {
  final String estimate;
  final String detail;
  final String unit;
  final bool live;
  const FeeQuote({required this.estimate, required this.detail,
    required this.unit, required this.live});
}

class FeeService {
  final http.Client _client;
  FeeService([http.Client? client]) : _client = client ?? http.Client();

  static const _rpcEndpoints = <ReceiveNetwork, String>{
    ReceiveNetwork.ethereum: 'https://ethereum-rpc.publicnode.com',
    ReceiveNetwork.usdtErc20: 'https://ethereum-rpc.publicnode.com',
    ReceiveNetwork.usdcErc20: 'https://ethereum-rpc.publicnode.com',
    ReceiveNetwork.bnbSmartChain: 'https://bsc-rpc.publicnode.com',
    ReceiveNetwork.usdtBep20: 'https://bsc-rpc.publicnode.com',
    ReceiveNetwork.polygon: 'https://polygon-bor-rpc.publicnode.com',
    ReceiveNetwork.base: 'https://base-rpc.publicnode.com',
    ReceiveNetwork.usdcBase: 'https://base-rpc.publicnode.com',
    ReceiveNetwork.arbitrum: 'https://arbitrum-one-rpc.publicnode.com',
    ReceiveNetwork.usdcArbitrum: 'https://arbitrum-one-rpc.publicnode.com',
    ReceiveNetwork.optimism: 'https://optimism-rpc.publicnode.com',
    ReceiveNetwork.avalanche: 'https://avalanche-c-chain-rpc.publicnode.com',
  };

  Future<FeeQuote> estimate(ReceiveNetwork network,
      {FeePriority priority = FeePriority.standard}) async {
    if (priority != FeePriority.standard &&
        network != ReceiveNetwork.bitcoin && network != ReceiveNetwork.litecoin) {
      throw StateError('Only the standard fee quote is available for this network.');
    }
    switch (network) {
      case ReceiveNetwork.bitcoin:
        final response = await _client.get(
          Uri.parse('https://mempool.space/api/v1/fees/recommended'),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw StateError('Bitcoin fee API unavailable');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final feeRate = body[switch (priority) {
          FeePriority.low => 'economyFee',
          FeePriority.standard => 'halfHourFee',
          FeePriority.high => 'fastestFee',
        }];
        if (feeRate is! num || feeRate <= 0) throw const FormatException('Invalid BTC fee rate');
        // Illustrative one-input, two-output transaction, NOT an actual size estimate.
        final sats = (feeRate * 140).ceil();
        return FeeQuote(estimate: '${_btc(sats)} BTC',
          detail: 'Live ${feeRate.toString()} sat/vB × illustrative 140 vbytes. Real transaction size can differ.',
          unit: 'BTC', live: true);
      case ReceiveNetwork.litecoin:
        final response = await _client.get(
          Uri.parse('https://api.blockcypher.com/v1/ltc/main'),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw StateError('Litecoin fee API unavailable');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final satPerKb = body[switch (priority) {
          FeePriority.low => 'low_fee_per_kb',
          FeePriority.standard => 'medium_fee_per_kb',
          FeePriority.high => 'high_fee_per_kb',
        }];
        if (satPerKb is! num || satPerKb <= 0) throw const FormatException('Invalid LTC fee rate');
        final sat = (satPerKb * 200 / 1000).ceil();
        return FeeQuote(estimate: '${_btc(sat)} LTC',
          detail: 'Live ${satPerKb.toString()} sat/kB × illustrative 200 bytes. Actual UTXOs change transaction size.',
          unit: 'LTC', live: true);
      case ReceiveNetwork.tron:
      case ReceiveNetwork.usdtTrc20:
        // TRC-20 execution can consume Energy/Bandwidth. Cost changes with
        // available resources and the contract invocation, not a fixed gas fee.
        throw StateError('TRON fee requires an Energy/Bandwidth simulation; exact estimates not implemented. TRX may be required.');
      case ReceiveNetwork.solana:
        return const FeeQuote(estimate: '0.000005 SOL',
          detail: 'Indicative base fee for one signature (5,000 lamports), NOT live. Does not include priority fees, rent, token accounts or other instructions.',
          unit: 'SOL', live: false);
      default:
        final rpc = _rpcEndpoints[network];
        if (rpc == null) throw StateError('No supported fee provider');
        final response = await _client.post(Uri.parse(rpc),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'eth_gasPrice', 'params': []}),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw StateError('EVM gas quote unavailable');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['error'] != null) throw StateError('EVM RPC returned an error');
        final raw = body['result'];
        if (raw is! String || !RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(raw)) {
          throw const FormatException('Invalid gas price');
        }
        final weiPerGas = BigInt.parse(raw.substring(2), radix: 16);
        if (weiPerGas <= BigInt.zero) throw const FormatException('Zero gas price');
        final gasUnits = network.isToken ? 65000 : 21000;
        final costWei = weiPerGas * BigInt.from(gasUnits);
        final native = _formatWei(costWei);
        final note = network.isToken
          ? 'Token transfer uses illustrative 65,000 gas units. Actual contract calls vary; ${network.nativeTicker} is needed for fees. Token-contract support must be verified before sending.'
          : 'Assumes a simple 21,000-gas native transfer. Real gas, EIP-1559 fees and L2 data fees can differ.';
        return FeeQuote(estimate: '$native ${network.nativeTicker}',
          detail: 'Live gas-price quote · $note', unit: network.nativeTicker,
          live: true);
    }
  }

  static String _btc(int sats) => _formatUnits(BigInt.from(sats), 8);
  static String _formatWei(BigInt amount) => _formatUnits(amount, 18);

  static String _formatUnits(BigInt amount, int decimals) {
    final scale = BigInt.from(10).pow(decimals);
    final integer = amount ~/ scale;
    final digits = (amount % scale).toString().padLeft(decimals, '0');
    final nonzero = digits.replaceFirst(RegExp(r'0+$'), '');
    return nonzero.isEmpty ? '$integer' : '$integer.$nonzero';
  }
  void dispose() => _client.close();
}
