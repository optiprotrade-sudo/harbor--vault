import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/receive_network.dart';
import '../services/fee_service.dart';

/// A review-only transaction builder. It NEVER constructs, signs, or broadcasts.
/// Real-money signing and spendable-balance checks are intentionally absent.
class SendScreen extends StatefulWidget {
  final PublicAddresses addresses;
  final ReceiveNetwork initialNetwork;
  const SendScreen({super.key, required this.addresses,
    this.initialNetwork = ReceiveNetwork.ethereum});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _feeService = FeeService();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  late ReceiveNetwork _network;
  FeeQuote? _quote;
  String? _feeError;
  bool _loading = false;
  int _requestSequence = 0;

  @override
  void initState() {
    super.initState();
    _network = widget.initialNetwork;
  }

  @override
  void dispose() {
    _requestSequence++;
    _feeService.dispose();
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final request = ++_requestSequence;
    setState(() { _loading = true; _feeError = null; _quote = null; });
    try {
      final quote = await _feeService.estimate(_network);
      if (!mounted || request != _requestSequence) return;
      setState(() => _quote = quote);
    } catch (_) {
      if (!mounted || request != _requestSequence) return;
      setState(() => _feeError = 'Fee estimate unavailable from provider. No fee has been assumed.');
    } finally {
      if (mounted && request == _requestSequence) setState(() => _loading = false);
    }
  }

  bool _looksLikeRecipient(String value) {
    final address = value.trim();
    if (_network.isEvm) return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
    switch (_network) {
      case ReceiveNetwork.bitcoin:
        return address.startsWith('bc1') && address.length >= 14 && address.length <= 90;
      case ReceiveNetwork.litecoin:
        return address.startsWith('ltc1') && address.length >= 14 && address.length <= 90;
      case ReceiveNetwork.solana:
        return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address);
      default:
        return false;
    }
  }

  Future<void> _review() async {
    final amount = _amount.text.trim();
    if (!RegExp(r'^(?:[0-9]+)(?:\.[0-9]+)?$').hasMatch(amount) ||
        (double.tryParse(amount) ?? 0) <= 0) {
      _message('Enter a positive numeric amount.');
      return;
    }
    if (!_looksLikeRecipient(_recipient.text)) {
      _message('Address format is not recognized for this network. No funds have moved.');
      return;
    }
    // Format checks are insufficient for a live transaction. Never submit.
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Transaction review · TEST ONLY'),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Network: ${_network.label}'),
          const SizedBox(height: 8),
          Text('Amount: $amount ${_network.transferTicker}'),
          const SizedBox(height: 8),
          const Text('Recipient:'),
          SelectableText(_recipient.text.trim()),
          const SizedBox(height: 12),
          Text('Indicative fee: ${_quote?.estimate ?? 'Unavailable'}'),
          const SizedBox(height: 12),
          const Text('BROADCAST DISABLED. No keys are accessed and no transaction is signed. This estimate is NOT the amount that would actually be charged.',
            style: TextStyle(color: Colors.orangeAccent)),
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close review')),
        const FilledButton(onPressed: null, child: Text('Broadcast disabled')),
      ],
    ));
  }

  void _message(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Send cryptocurrency', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      const Text('Review mode only. This build cannot send funds yet.',
        style: TextStyle(color: Colors.amberAccent)),
      const SizedBox(height: 22),
      DropdownButtonFormField<ReceiveNetwork>(
        value: _network,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Coin and network'),
        items: ReceiveNetwork.values.map((n) => DropdownMenuItem(
          value: n, child: Text('${n.label} · ${n.transferTicker}', overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (selected) {
          if (selected == null) return;
          _requestSequence++;
          setState(() { _network = selected; _quote = null; _feeError = null; _loading = false; });
        },
      ),
      const SizedBox(height: 16),
      TextField(controller: _recipient, autocorrect: false, enableSuggestions: false,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(labelText: 'Recipient address', hintText: 'Paste the recipient address')),
      const SizedBox(height: 14),
      TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Amount (${_network.transferTicker})')),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Network fee estimate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_quote != null) ...[
            SelectableText(_quote!.estimate, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_quote!.live ? 'Live fee-rate input · planning estimate' : 'Fixed planning illustration · not live',
              style: const TextStyle(color: Colors.amberAccent)),
            const SizedBox(height: 7),
            Text(_quote!.detail),
          ] else if (_feeError != null)
            Text(_feeError!, style: const TextStyle(color: Colors.orangeAccent))
          else
            const Text('Tap Estimate fee to request public network data. Fees are not fixed.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _loading ? null : _estimate,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.calculate_outlined),
            label: Text(_loading ? 'Checking network…' : 'Estimate fee')),
        ],
      ))),
      const SizedBox(height: 16),
      const Text('For safety, this version does not broadcast transactions, verify spendable balances, calculate exact total fees or scan QR codes. Never use its estimate as final authorization.',
        style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 18),
      ElevatedButton.icon(onPressed: _review,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Review transfer · no sending')),
    ],
  );
}
