import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models/asset.dart';
import 'services/balance_service.dart';
import 'services/vault_storage.dart';
import 'services/wallet_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HarborVaultApp());
}

const _bg = Color(0xFF071319);
const _panel = Color(0xFF10242B);
const _mint = Color(0xFF8DF0CB);
const _muted = Color(0xFFA0B9BF);

enum _Page { loading, welcome, backup, restore, wallet, error }

class HarborVaultApp extends StatelessWidget {
  const HarborVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Harbor Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(seedColor: _mint, brightness: Brightness.dark,
            surface: _panel, primary: _mint),
        appBarTheme: const AppBarTheme(backgroundColor: _bg, elevation: 0),
        cardTheme: CardThemeData(color: _panel, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: const Color(0xFF153039),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _mint, foregroundColor: _bg,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const VaultScreen(),
    );
  }
}

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _storage = VaultStorage();
  final _balanceService = BalanceService();
  final _word3 = TextEditingController();
  final _word9 = TextEditingController();
  final _importText = TextEditingController();
  _Page _page = _Page.loading;
  PublicAddresses? _addresses;
  String? _pendingMnemonic;
  String? _error;
  bool _saving = false;
  bool _refreshing = false;
  int _tab = 0;
  ChainAsset _selected = ChainAsset.btc;
  final Map<ChainAsset, String> _balances = {};
  final Map<ChainAsset, String> _balanceErrors = {};

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _word3.dispose();
    _word9.dispose();
    _importText.dispose();
    _balanceService.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final phrase = await _storage.getPhrase();
      if (!mounted) return;
      if (phrase == null) {
        setState(() => _page = _Page.welcome);
      } else {
        final derived = WalletEngine.derive(phrase);
        if (mounted) setState(() {
          _addresses = derived;
          _page = _Page.wallet;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Unable to open the encrypted wallet. Details: $e';
        _page = _Page.error;
      });
    }
  }

  void _create() {
    try {
      final phrase = WalletEngine.createMnemonic();
      // Derive before accepting or persisting the phrase.
      WalletEngine.derive(phrase);
      _word3.clear();
      _word9.clear();
      setState(() {
        _pendingMnemonic = phrase;
        _page = _Page.backup;
      });
    } catch (e) {
      _snack('Could not securely create the recovery words: $e');
    }
  }

  Future<void> _completeCreation() async {
    final phrase = _pendingMnemonic;
    if (phrase == null) return;
    final words = phrase.split(' ');
    if (_word3.text.toLowerCase().trim() != words[2] ||
        _word9.text.toLowerCase().trim() != words[8]) {
      _snack('Word 3 or word 9 did not match. Check your written backup.');
      return;
    }
    await _storeAndOpen(phrase);
  }

  Future<void> _restore() async {
    final phrase = WalletEngine.normalize(_importText.text);
    if (!WalletEngine.validMnemonic(phrase)) {
      _snack('Invalid BIP39 English recovery phrase or checksum.');
      return;
    }
    await _storeAndOpen(phrase);
    _importText.clear();
  }

  Future<void> _storeAndOpen(String phrase) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final derived = WalletEngine.derive(phrase);
      await _storage.storePhrase(phrase);
      if (!mounted) return;
      setState(() {
        _addresses = derived;
        _page = _Page.wallet;
        _pendingMnemonic = null;
        _balances.clear();
        _balanceErrors.clear();
      });
      _snack('Wallet saved in device encrypted storage.');
    } catch (e) {
      if (mounted) _snack('Could not save the wallet: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _addresses == null) return;
    setState(() {
      _refreshing = true;
      _balanceErrors.clear();
    });
    // Only public addresses are sent to third-party providers.
    await Future.wait([ChainAsset.btc, ChainAsset.eth, ChainAsset.usdt].map((asset) async {
      try {
        final value = await _balanceService.fetch(asset, _addresses!.of(asset));
        if (mounted) setState(() => _balances[asset] = value);
      } catch (e) {
        if (mounted) setState(() {
          _balances.remove(asset); // Never show stale values as current.
          _balanceErrors[asset] = '$e';
        });
      }
    }));
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _copyAddress(ChainAsset asset) async {
    final address = _addresses?.of(asset);
    if (address == null) return;
    await Clipboard.setData(ClipboardData(text: address));
    _snack('${asset.symbol} public address copied. Verify the network before depositing.');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  Future<void> _showRecoveryPhrase() async {
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Show recovery words?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Anyone who sees these words can take all funds. Close screen recording and make sure nobody is watching. This version does NOT enforce app authentication.'),
          const SizedBox(height: 12),
          TextField(controller: confirmation, decoration: const InputDecoration(labelText: 'Type SHOW to continue')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, confirmation.text.trim() == 'SHOW'), child: const Text('Reveal')),
        ],
      ),
    );
    confirmation.dispose();
    if (accepted != true || !mounted) return;
    try {
      final phrase = await _storage.getPhrase();
      if (!mounted || phrase == null) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Secret recovery phrase'),
          content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Write these down offline. Never send them to anyone or store screenshots.', style: TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 14),
            _PhraseGrid(phrase: phrase),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      _snack('Could not unlock recovery words: $e');
    }
  }

  Future<void> _deleteWallet() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this local wallet?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('This removes the encrypted recovery phrase from this device. If you do not have a backup, access to coins may be lost permanently.'),
          const SizedBox(height: 16),
          TextField(controller: controller, decoration: const InputDecoration(labelText: 'Type DELETE to confirm')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text == 'DELETE'), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;
    try {
      await _storage.remove();
      if (!mounted) return;
      setState(() {
        _addresses = null;
        _balances.clear();
        _balanceErrors.clear();
        _page = _Page.welcome;
        _tab = 0;
        _selected = ChainAsset.btc;
      });
      _snack('Local wallet removed. Your offline recovery backup is still essential.');
    } catch (e) {
      _snack('Wallet could not be deleted: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 800;
    final wallet = _page == _Page.wallet;
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.anchor_rounded, color: _bg, size: 21)),
          const SizedBox(width: 10),
          const Text('HARBOR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Text(' VAULT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 1)),
        ]),
        actions: [
          if (wallet)
            const Padding(padding: EdgeInsets.only(right: 12), child: Center(
              child: Text('SELF-CUSTODY  •  v0.1', style: TextStyle(fontSize: 10, color: _muted)))),
        ],
      ),
      body: wallet
        ? Row(children: [
            if (desktop) NavigationRail(
              backgroundColor: _bg,
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() => _tab = value),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Assets')),
                NavigationRailDestination(icon: Icon(Icons.qr_code), label: Text('Receive')),
                NavigationRailDestination(icon: Icon(Icons.shield_outlined), label: Text('Security')),
              ],
            ),
            Expanded(child: _walletContent()),
          ])
        : SafeArea(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _onboarding()),
          ))),
      bottomNavigationBar: wallet && !desktop
        ? NavigationBar(
            backgroundColor: const Color(0xFF0E222A),
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() => _tab = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Assets'),
              NavigationDestination(icon: Icon(Icons.qr_code), label: 'Receive'),
              NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Security'),
            ],
          ) : null,
    );
  }

  Widget _onboarding() {
    if (_page == _Page.loading) return const Center(child: CircularProgressIndicator());
    if (_page == _Page.error) return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 54),
      const SizedBox(height: 18),
      const Text('Encrypted wallet could not be loaded', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Text(_error ?? 'Unknown error', textAlign: TextAlign.center),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: _boot, child: const Text('Retry')),
    ]);
    if (_page == _Page.welcome) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      _pill('PERSONAL  •  NO ACCOUNT  •  NO NAIRA'),
      const SizedBox(height: 28),
      const Text('Your coins.\nYour keys.', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 48, height: 1.05)),
      const SizedBox(height: 18),
      const Text('A private home for Bitcoin, Ethereum, Litecoin and Ethereum-network USDT. No server account. No custodial access.', style: TextStyle(color: _muted, fontSize: 16, height: 1.6)),
      const SizedBox(height: 32),
      const _InfoBanner(icon: Icons.warning_amber_outlined, text: 'PROTOTYPE · Receive-only. Do not deposit real funds until builds, derivation and storage have been independently audited.'),
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: _create, icon: const Icon(Icons.add_circle_outline), label: const Text('Create a new wallet')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => setState(() => _page = _Page.restore), icon: const Icon(Icons.restore), label: const Text('Restore with recovery words'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      const SizedBox(height: 25),
      const Text('Nothing is sent to our server. Internet access is used only if you tap Refresh balances.', style: TextStyle(color: _muted, fontSize: 12)),
    ]);
    if (_page == _Page.restore) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(onPressed: () => setState(() => _page = _Page.welcome), icon: const Icon(Icons.arrow_back), label: const Text('Back')),
      const SizedBox(height: 16),
      const Text('Restore wallet', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('Enter a valid English BIP39 recovery phrase. Never send your recovery words to a website or support agent.', style: TextStyle(color: _muted)),
      const SizedBox(height: 22),
      TextField(controller: _importText, minLines: 4, maxLines: 6,
          enableSuggestions: false, autocorrect: false,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: 'Recovery phrase', alignLabelWithHint: true)),
      const SizedBox(height: 14),
      const _InfoBanner(icon: Icons.info_outline, text: 'This prototype checks only first receiving address (index 0) for each standard path. Older coins in other accounts/addresses may not appear.'),
      const SizedBox(height: 22),
      ElevatedButton(onPressed: _saving ? null : _restore, child: Text(_saving ? 'Saving…' : 'Restore on this device')),
    ]);
    if (_page == _Page.backup) {
      final phrase = _pendingMnemonic;
      if (phrase == null) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(onPressed: () => setState(() { _pendingMnemonic = null; _page = _Page.welcome; }), icon: const Icon(Icons.arrow_back), label: const Text('Cancel creation')),
        const SizedBox(height: 12),
        const Text('Secure your recovery words', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        const _InfoBanner(icon: Icons.lock_outline, text: 'Write these 12 words on paper, in order. Do NOT take screenshots, copy them into chat, or save them in cloud notes.'),
        const SizedBox(height: 20),
        _PhraseGrid(phrase: phrase),
        const SizedBox(height: 22),
        const Text('Confirm your handwritten backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _word3, autocorrect: false, enableSuggestions: false, decoration: const InputDecoration(labelText: 'Word #3'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _word9, autocorrect: false, enableSuggestions: false, decoration: const InputDecoration(labelText: 'Word #9'))),
        ]),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _saving ? null : _completeCreation, child: Text(_saving ? 'Saving…' : 'I saved my words — create wallet')),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _walletContent() {
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 38),
        child: switch (_tab) {
          0 => _assetsView(),
          1 => _receiveView(),
          _ => _securityView(),
        }),
    ));
  }

  Widget _assetsView() {
    final width = MediaQuery.sizeOf(context).width;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pill('MAINNET ADDRESSES · RECEIVE-ONLY BUILD'),
      const SizedBox(height: 16),
      const Text('My assets', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      const Text('Balances are unavailable until you request a public network check.', style: TextStyle(color: _muted)),
      const SizedBox(height: 22),
      Container(width: double.infinity, padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF183E3C), Color(0xFF122B36)]),
          borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.shield_outlined, color: _mint, size: 32),
          const SizedBox(height: 18),
          const Text('100% YOUR KEYS', style: TextStyle(fontSize: 13, color: _mint, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
          const SizedBox(height: 6),
          const Text('No exchange. No bank. No custodial account.', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Your recovery words stay encrypted on this device. Funds are on their blockchains, not inside this app.', style: TextStyle(fontSize: 12, color: _muted)),
        ])),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _refreshing ? null : _refresh,
          icon: _refreshing ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
          label: Text(_refreshing ? 'Checking…' : 'Refresh balances'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _tab = 1),
          icon: const Icon(Icons.qr_code), label: const Text('Receive'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)))),
      ]),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final cols = constraints.maxWidth > 720 ? 2 : 1;
        final gap = 14.0;
        final cardWidth = (constraints.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: ChainAsset.values.map((a) =>
          SizedBox(width: cardWidth, child: _assetCard(a, compact: width < 420))).toList());
      }),
      const SizedBox(height: 20),
      const _InfoBanner(icon: Icons.error_outline, text: 'No transaction signing or sending yet. This prototype displays the FIRST receiving address for each chain only. Do not rely on it as an audited production wallet.'),
    ]);
  }

  Widget _assetCard(ChainAsset asset, {bool compact = false}) {
    final value = _balances[asset];
    final error = _balanceErrors[asset];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 21, backgroundColor: asset.color.withValues(alpha: .15), child: Text(asset.symbol[0], style: TextStyle(fontSize: 19, color: asset.color, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(asset.symbol, style: const TextStyle(fontSize: 12, color: _muted)),
          ])),
          const Icon(Icons.arrow_outward, color: _muted, size: 17),
        ]),
        const SizedBox(height: 17),
        Text(value == null ? '— ${asset.symbol}' : '$value ${asset.symbol}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 20 : 23)),
        const SizedBox(height: 5),
        Text(error != null ? 'Balance unavailable — provider error' :
             asset == ChainAsset.ltc ? 'Balance lookup not connected' :
             value == null ? 'Not checked' : 'Public network balance',
          style: TextStyle(color: error != null ? Colors.orangeAccent : _muted, fontSize: 12)),
        const SizedBox(height: 14),
        Text(asset.network, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 9),
        SelectableText(_addresses!.of(asset), maxLines: 2, style: const TextStyle(fontSize: 12, color: Color(0xFFCCDFDF))),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => _copyAddress(asset), icon: const Icon(Icons.copy, size: 16), label: const Text('Copy'))),
          const SizedBox(width: 9),
          Expanded(child: OutlinedButton.icon(onPressed: () { setState(() { _selected = asset; _tab = 1; }); }, icon: const Icon(Icons.qr_code, size: 16), label: const Text('QR / Receive'))),
        ]),
      ])),
    );
  }

  Widget _receiveView() {
    final address = _addresses!.of(_selected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pill('PUBLIC RECEIVE ADDRESSES'),
      const SizedBox(height: 17),
      const Text('Receive crypto', style: TextStyle(fontSize: 33, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Choose the exact coin AND network before sharing an address.', style: TextStyle(color: _muted)),
      const SizedBox(height: 23),
      Wrap(spacing: 9, runSpacing: 9, children: ChainAsset.values.map((a) =>
        ChoiceChip(label: Text(a.symbol), selected: _selected == a, onSelected: (_) => setState(() => _selected = a))).toList()),
      const SizedBox(height: 22),
      Container(width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          Text(_selected.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_selected.network, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: address, size: 208, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M)),
          const SizedBox(height: 24),
          SelectableText(address, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 18),
          ElevatedButton.icon(onPressed: () => _copyAddress(_selected), icon: const Icon(Icons.copy), label: const Text('Copy receiving address')),
        ])),
      const SizedBox(height: 18),
      _InfoBanner(icon: Icons.warning_amber_outlined, text: _selected == ChainAsset.usdt
        ? 'USDT here means ERC-20 on Ethereum only. DO NOT send TRC-20, BEP-20, Solana or other-chain USDT to this address.'
        : 'Use only ${_selected.network}. A transaction sent using another network may be permanently lost.'),
      const SizedBox(height: 12),
      const Text('One address is shown per blockchain. This version does not rotate or scan addresses.', style: TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _securityView() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pill('NO THIRD-PARTY CUSTODY'),
      const SizedBox(height: 18),
      const Text('Security & backup', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Your recovery words are the only reliable way to recover this wallet if the device is lost.', style: TextStyle(color: _muted)),
      const SizedBox(height: 24),
      Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock, color: _mint),
              title: Text('Encrypted device storage'), subtitle: Text('Uses Flutter Secure Storage, backed by OS protected encryption.')),
          const Divider(),
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.gpp_maybe_outlined, color: Colors.orangeAccent),
              title: Text('Important security limitations'), subtitle: Text('No app PIN, device authentication, memory zeroization, external audit or hardware-wallet integration yet.')),
          const Divider(),
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.public, color: Colors.lightBlueAccent),
              title: Text('No account or wallet backend'), subtitle: Text('Balance refresh contacts public blockchain providers with your PUBLIC address only.')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _showRecoveryPhrase, icon: const Icon(Icons.visibility_outlined), label: const Text('Reveal recovery words'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(49))),
        ]))),
      const SizedBox(height: 20),
      const Text('Standard derivation paths', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...ChainAsset.values.where((a) => a != ChainAsset.usdt).map((a) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          SizedBox(width: 80, child: Text(a.symbol, style: const TextStyle(color: _mint))),
          SelectableText(a.path, style: const TextStyle(color: _muted)),
        ]))),
      const SizedBox(height: 24),
      OutlinedButton.icon(onPressed: _deleteWallet, icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        label: const Text('Delete wallet from this device', style: TextStyle(color: Colors.redAccent)),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
      const SizedBox(height: 20),
      const Text('v0.1 receive-only prototype · Not audited · No warranty. Keep an offline recovery backup.', style: TextStyle(color: _muted, fontSize: 11)),
    ]);
  }

  Widget _pill(String label) => Container(
    decoration: BoxDecoration(color: const Color(0xFF163A36), borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Text(label, style: const TextStyle(fontSize: 10, color: _mint, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );
}

class _PhraseGrid extends StatelessWidget {
  final String phrase;
  const _PhraseGrid({required this.phrase});
  @override
  Widget build(BuildContext context) {
    final words = phrase.split(' ');
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 370 ? 3 : 2;
      final gap = 9.0;
      final w = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < words.length; i++)
          Container(width: w, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 9),
            decoration: BoxDecoration(color: const Color(0xFF1A353A), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text('${i + 1}.', style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(width: 5),
              Expanded(child: Text(words[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ])),
      ]);
    });
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xFF293026), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF5B5B3C))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: const Color(0xFFF2D88B), size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF3E7B5), height: 1.5, fontSize: 12))),
    ]),
  );
}
