import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset.dart';
import '../models/receive_network.dart';
import '../models/wallet_listing.dart';
import '../services/fee_service.dart';

const _background = Color(0xFF071319);
const _panel = Color(0xFF15262C);
const _mint = Color(0xFF8DF0CB);
const _muted = Color(0xFF9DB1B5);

/// Screenshot-inspired send interface. Explicitly REVIEW-ONLY: the app does
/// not create, sign or broadcast a transaction and never reads a private key.
class SendScreen extends StatefulWidget {
  final PublicAddresses addresses;
  final String walletName;
  final ReceiveNetwork initialNetwork;
  final Map<ChainAsset, String> balances;
  final Map<ChainAsset, double> usdPrices;
  /// Fresh OS authentication is requested for each reviewed transfer.
  final Future<bool> Function() authorizeReview;
  final VoidCallback? onReviewOpened;
  const SendScreen({super.key, required this.addresses,
    this.walletName = 'My Harbor Wallet', this.initialNetwork = ReceiveNetwork.bitcoin,
    this.balances = const {}, this.usdPrices = const {},
    required this.authorizeReview, this.onReviewOpened});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _feeService = FeeService();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  late ReceiveNetwork _network;
  FeePriority _priority = FeePriority.standard;
  FeeQuote? _quote;
  String? _feeError;
  bool _loading = false;
  int _sequence = 0;

  WalletListing get _entry => WalletListing.forNetwork(_network);
  bool get _tieredFees => _network == ReceiveNetwork.bitcoin ||
      _network == ReceiveNetwork.litecoin;

  @override
  void initState() {
    super.initState();
    _network = widget.initialNetwork;
    _amount.addListener(_redrawAmount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _estimate();
    });
  }

  void _redrawAmount() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _sequence++;
    _amount.removeListener(_redrawAmount);
    _feeService.dispose();
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _select(ReceiveNetwork choice) {
    if (_network == choice) return;
    ++_sequence;
    _recipient.clear();
    _amount.clear();
    setState(() {
      _network = choice;
      _priority = FeePriority.standard;
      _quote = null;
      _feeError = null;
      _loading = false;
    });
    _estimate();
  }

  Future<void> _estimate() async {
    final request = ++_sequence;
    setState(() { _loading = true; _quote = null; _feeError = null; });
    try {
      final quote = await _feeService.estimate(_network, priority: _priority);
      if (!mounted || request != _sequence) return;
      setState(() => _quote = quote);
    } catch (_) {
      if (!mounted || request != _sequence) return;
      setState(() => _feeError = _network == ReceiveNetwork.tron ||
          _network == ReceiveNetwork.usdtTrc20
          ? 'TRON Energy/Bandwidth estimation not implemented. TRX may be required.'
          : 'Network fee unavailable. No zero fee is assumed.');
    } finally {
      if (mounted && request == _sequence) setState(() => _loading = false);
    }
  }

  String _shortAddress(String address) => address.length > 16
      ? '${address.substring(0, 7)}…${address.substring(address.length - 5)}'
      : address;

  String? get _balance => _entry.trackedAsset == null
      ? null : widget.balances[_entry.trackedAsset];

  String get _available => _balance == null
      ? 'Balance not verified'
      : 'Reported balance: $_balance ${_entry.ticker}';

  String get _usdEquivalent {
    final price = widget.usdPrices[_entry.trackedAsset];
    final amount = double.tryParse(_amount.text);
    if (price == null || amount == null || !amount.isFinite || amount <= 0) {
      return '—';
    }
    return '\$${(amount * price).toStringAsFixed(2)}';
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _message('Clipboard has no text address.');
      return;
    }
    _recipient.text = text;
    _message('Address pasted. Check both the address and network.');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _recipientFormatHint(String address) {
    final text = address.trim();
    if (_network.isEvm) return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(text);
    switch (_network) {
      case ReceiveNetwork.bitcoin:
        return RegExp(r'^bc1[ac-hj-np-z02-9]{11,87}$').hasMatch(text);
      case ReceiveNetwork.litecoin:
        return RegExp(r'^ltc1[ac-hj-np-z02-9]{11,87}$').hasMatch(text);
      case ReceiveNetwork.solana:
        return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(text);
      case ReceiveNetwork.tron:
      case ReceiveNetwork.usdtTrc20:
        return RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$').hasMatch(text);
      default:
        return false;
    }
  }

  Future<void> _review() async {
    final amountText = _amount.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || !amount.isFinite || amount <= 0 ||
        !RegExp(r'^\d+(\.\d+)?$').hasMatch(amountText)) {
      _message('Enter a positive amount. No transaction was submitted.');
      return;
    }
    if (!_recipientFormatHint(_recipient.text)) {
      _message('The recipient format does not match this network.');
      return;
    }
    if (!mounted) return;
    widget.onReviewOpened?.call();
    bool verifying = false;
    bool identityConfirmed = false;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (dialogContext, updateDialog) => AlertDialog(
        title: const Text('Review transfer · simulation'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewLine('Asset', '${_entry.ticker} (${_entry.networkTag})'),
            _reviewLine('Amount', '$amountText ${_entry.ticker}'),
            _reviewLine('USD equivalent', _usdEquivalent),
            _reviewLine('Fee estimate', _quote?.estimate ?? 'Unavailable'),
            const SizedBox(height: 12),
            const Text('Recipient', style: TextStyle(color: _muted)),
            const SizedBox(height: 5),
            SelectableText(_recipient.text.trim()),
            const SizedBox(height: 16),
            Text(identityConfirmed
              ? 'Identity verified for this review. No transaction was sent.'
              : 'Confirm the full recipient address and amount, then verify with your phone security.',
              style: const TextStyle(color: _mint, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('TEST ONLY: No transaction is built, signed or broadcast. Network format checks are preliminary.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          ],
        )),
        actions: [
          TextButton(onPressed: verifying ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Close')),
          FilledButton.icon(
            onPressed: verifying || identityConfirmed ? null : () async {
              updateDialog(() => verifying = true);
              bool authorized = false;
              try { authorized = await widget.authorizeReview(); }
              catch (_) { authorized = false; }
              if (!dialogContext.mounted) return;
              updateDialog(() {
                verifying = false;
                identityConfirmed = authorized;
              });
              if (!authorized) _message('Phone authentication was cancelled or unavailable.');
            },
            icon: verifying ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.fingerprint),
            label: Text(identityConfirmed ? 'Verified · No sending'
              : verifying ? 'Verifying…' : 'Verify identity'),
          ),
        ],
      ),
    ));
  }

  Widget _reviewLine(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(color: _muted))),
      Flexible(child: Text(value, textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold))),
    ]),
  );

  Future<void> _chooseCoin() async {
    final search = TextEditingController();
    final choice = await showModalBottomSheet<ReceiveNetwork>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      builder: (sheetContext) => StatefulBuilder(builder: (ctx, refreshSheet) {
        final results = WalletListing.search(search.text);
        return SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16,
            MediaQuery.viewInsetsOf(ctx).bottom + 12),
          child: SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.72,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Choose coin & network',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: search, onChanged: (_) => refreshSheet(() {}),
                autofocus: false,
                decoration: const InputDecoration(hintText: 'Search BTC, USDT, TRC-20, Base…',
                  prefixIcon: Icon(Icons.search))),
              const SizedBox(height: 10),
              Expanded(child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF24393F)),
                itemBuilder: (ctx, index) {
                  final entry = results[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: entry.color.withValues(alpha: .16),
                      child: Text(entry.ticker.substring(0, 1),
                        style: TextStyle(color: entry.color, fontWeight: FontWeight.w900))),
                    title: Text('${entry.ticker} (${entry.networkTag})'),
                    subtitle: Text(entry.name, style: const TextStyle(color: _muted)),
                    trailing: entry.network == _network
                      ? const Icon(Icons.check_circle, color: _mint) : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(ctx, entry.network),
                  );
                },
              )),
            ])),
        ));
      }),
    );
    search.dispose();
    if (choice != null && mounted) _select(choice);
  }

  Widget _feeChoice(String name, FeePriority? priority) {
    final enabled = priority != null && (_tieredFees || priority == FeePriority.standard);
    final active = enabled && _priority == priority;
    return Expanded(child: InkWell(
      onTap: enabled && !_loading ? () { setState(() => _priority = priority!); _estimate(); } : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF273938) : _background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _mint : const Color(0xFF35474D)),
        ),
        child: Column(children: [
          Text(name, style: TextStyle(color: enabled ? Colors.white : _muted,
            fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          Text(priority == null ? 'Later' : enabled ? (active ? 'Selected' : 'Choose') : 'N/A',
            style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Send', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('REVIEW MODE · OS verification required; real sending disabled',
        style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
      const SizedBox(height: 22),
      Container(
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, color: _mint, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.walletName, style: const TextStyle(fontWeight: FontWeight.w700))),
          SelectableText(_shortAddress(_network.addressOf(widget.addresses)),
            style: const TextStyle(color: _muted, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 16),
      InkWell(onTap: _chooseCoin, borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            CircleAvatar(radius: 25, backgroundColor: _entry.color.withValues(alpha: .18),
              child: Text(_entry.ticker[0], style: TextStyle(color: _entry.color,
                fontSize: 21, fontWeight: FontWeight.w900))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_entry.ticker, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('${_entry.name} · ${_entry.networkTag}',
                style: const TextStyle(color: _muted, fontSize: 12)),
            ])),
            const Icon(Icons.chevron_right, color: _muted),
          ]),
        )),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(child: Text('To', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        const Icon(Icons.qr_code_scanner, color: _muted, size: 20),
        const SizedBox(width: 6),
        const Text('Scanner later', style: TextStyle(color: _muted, fontSize: 11)),
      ]),
      const SizedBox(height: 9),
      TextField(controller: _recipient, autocorrect: false, enableSuggestions: false,
        keyboardType: TextInputType.text, maxLines: 2, minLines: 1,
        decoration: InputDecoration(hintText: 'Enter or paste recipient address',
          suffixIcon: TextButton(onPressed: _paste,
            child: const Text('Paste', style: TextStyle(color: _mint, fontWeight: FontWeight.w800))))),
      const SizedBox(height: 20),
      const Text('Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(hintText: '0.00',
          suffixIcon: SizedBox(width: 119, child: Row(mainAxisSize: MainAxisSize.min, children: [
            InkWell(onTap: () => _message('MAX requires verified spendable funds and network-fee deductions; not yet available.'),
              child: const Padding(padding: EdgeInsets.all(7), child: Text('MAX',
                style: TextStyle(color: _mint, fontWeight: FontWeight.w800)))),
            Expanded(child: Text(_entry.ticker, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12))),
          ])))),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Text(_usdEquivalent, style: const TextStyle(color: _muted))),
          const Text('USD', style: TextStyle(color: _muted)),
        ])),
      const SizedBox(height: 8),
      Text(_available, style: const TextStyle(color: _muted, fontSize: 12)),
      if (!_entry.isIndexed) ...[
        const SizedBox(height: 7),
        const Text('Address preview only · Token or network balance indexing is not implemented.',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
      ],
      const SizedBox(height: 23),
      Container(padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Network Fee',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            if (_loading) const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
            else IconButton(onPressed: _estimate, tooltip: 'Refresh fee estimate',
              icon: const Icon(Icons.refresh, size: 20, color: _mint)),
          ]),
          const SizedBox(height: 6),
          if (_quote != null) ...[
            Text(_quote!.estimate, style: const TextStyle(color: _mint,
              fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(_quote!.live ? 'Live network rate · approximate transfer size'
              : 'Illustration only · not a live fee',
              style: const TextStyle(color: _muted, fontSize: 11)),
          ] else Text(_feeError ?? 'Checking provider…',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            _feeChoice('Low', FeePriority.low),
            const SizedBox(width: 6),
            _feeChoice('Standard', FeePriority.standard),
            const SizedBox(width: 6),
            _feeChoice('High', FeePriority.high),
            const SizedBox(width: 6),
            _feeChoice('Custom', null),
          ]),
          if (_quote != null) ...[
            const SizedBox(height: 12),
            Text(_quote!.detail, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ])),
      const SizedBox(height: 17),
      Text(_network.caution, style: const TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(height: 23),
      SizedBox(width: double.infinity, child: FilledButton(
        onPressed: _review,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7169F8),
          foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('Next · Review only',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      )),
      const SizedBox(height: 10),
    ],
  );
}
