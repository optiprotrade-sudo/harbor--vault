import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models/asset.dart';
import 'models/receive_network.dart';
import 'models/wallet_listing.dart';
import 'screens/send_screen.dart';
import 'screens/history_screen.dart';
import 'screens/owner_screen.dart';
import 'services/balance_service.dart';
import 'services/price_service.dart';
import 'services/portfolio_summary.dart';
import 'services/vault_storage.dart';
import 'services/device_auth_service.dart';
import 'services/auto_lock_policy.dart';
import 'services/wallet_preferences.dart';
import 'services/wallet_engine.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HarborVaultApp());
}

const _bg = Color(0xFF071319);
const _panel = Color(0xFF10242B);
const _mint = Color(0xFF8DF0CB);
const _muted = Color(0xFFA0B9BF);

enum _Page { loading, locked, welcome, backup, restore, wallet, error }

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

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  final _storage = VaultStorage();
  final _deviceAuth = DeviceAuthService();
  final _prefs = WalletPreferences();
  final _noticeStore = VaultNotificationStore();
  List<VaultNotice> _notices = [];
  bool _notificationsOpen = false;
  int _noticeSequence = 0;
  Future<void> _noticeWrites = Future<void>.value();
  bool _authInProgress = false;
  // Prevents biometric retry loops. Only a fresh launch or a real return from
  // the background reopens the OS authentication prompt automatically.
  bool _promptWhenForeground = false;
  String? _unlockError;
  int _autoLockMinutes = AutoLockPolicy.defaultMinutes;
  Timer? _idleLockTimer;
  bool _backupVerified = false;
  String _walletName = 'My Harbor Wallet';
  int _newWordCount = 12;
  final _balanceService = BalanceService();
  final _priceService = PriceService();
  final _word3 = TextEditingController();
  final _word9 = TextEditingController();
  final _importText = TextEditingController();
  final _assetSearch = TextEditingController();
  String _assetFilter = 'All';
  _Page _page = _Page.loading;
  PublicAddresses? _addresses;
  String? _pendingMnemonic;
  String? _error;
  bool _saving = false;
  bool _refreshing = false;
  bool _foreground = true;
  bool _balancesVisible = true;
  DateTime? _lastChecked;
  String? _priceError;
  Timer? _autoRefreshTimer;
  final Set<ReceiveNetwork> _expandedNetworks = {};
  final Map<ChainAsset, double> _usdPrices = {};
  int _refreshVersion = 0;
  int _tab = 0;
  ChainAsset _selected = ChainAsset.btc;
  ReceiveNetwork _receiveNetwork = ReceiveNetwork.bitcoin;
  ReceiveNetwork _sendNetwork = ReceiveNetwork.bitcoin;
  final Map<ChainAsset, String> _balances = {};
  final Map<ChainAsset, String> _balanceErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && _foreground && _page == _Page.wallet) _refresh();
    });
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_page == _Page.wallet && !_authInProgress) {
        _lock(); // Hide wallet contents immediately on backgrounding.
        _promptWhenForeground = true;
      } else if (_page == _Page.locked && !_authInProgress) {
        _promptWhenForeground = true;
      }
    }
    if (!wasForeground && _foreground) {
      if (_page == _Page.locked && _promptWhenForeground && !_authInProgress) {
        _promptWhenForeground = false;
        _queueAutomaticUnlock();
      } else if (_page == _Page.wallet) {
        _recordUserActivity();
        _refresh();
      }
    }
  }

  Future<void> _loadNotices() async {
    try {
      final items = await _noticeStore.load();
      if (mounted) setState(() => _notices = items);
    } catch (_) {
      // A broken or unavailable notification log must not block wallet unlock.
      if (mounted) setState(() => _notices = []);
    }
  }

  void _saveNotices() {
    final snapshot = List<VaultNotice>.of(_notices);
    // Serialise writes so a slow earlier save cannot overwrite a newer one.
    _noticeWrites = _noticeWrites.then((_) => _noticeStore.save(snapshot))
      .catchError((Object _) {});
  }

  void _notify(String title, String message, {String kind = 'info'}) {
    if (!mounted) return;
    final now = DateTime.now();
    final notice = VaultNotice(
      id: '${now.microsecondsSinceEpoch}-${_noticeSequence++}',
      createdAt: now, title: title, message: message, kind: kind);
    setState(() => _notices = VaultNoticeHistory.add(_notices, notice));
    _saveNotices();
  }

  void _markRead(String id) {
    setState(() => _notices = _notices.map((n) =>
      n.id == id ? n.markRead() : n).toList());
    _saveNotices();
  }

  void _markAllRead() {
    setState(() => _notices = VaultNoticeHistory.markAllRead(_notices));
    _saveNotices();
  }

  Future<void> _clearNotices() async {
    setState(() => _notices = []);
    _saveNotices();
  }

  void _toggleNotifications() =>
      setState(() => _notificationsOpen = !_notificationsOpen);

  void _closeNotifications() {
    if (_notificationsOpen) setState(() => _notificationsOpen = false);
  }

  Widget _notificationsPanel(double availableHeight) {
    final height = availableHeight < 500 ? availableHeight * .90 : 490.0;
    return Container(
      width: 380, height: height,
      decoration: BoxDecoration(color: const Color(0xFF14282F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34575A)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 8, 10), child: Row(children: [
          const Icon(Icons.notifications_outlined, color: _mint),
          const SizedBox(width: 8),
          const Expanded(child: Text('Notifications', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800))),
          IconButton(onPressed: _closeNotifications, tooltip: 'Close notifications',
            icon: const Icon(Icons.close)),
        ])),
        if (_notices.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
            TextButton(onPressed: VaultNoticeHistory.unreadCount(_notices) == 0
              ? null : _markAllRead, child: const Text('Mark all read')),
            const Spacer(),
            TextButton(onPressed: () async {
              final clear = await showDialog<bool>(context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Clear notification history?'),
                  content: const Text('This only clears notifications saved on this phone. It does not change blockchain transactions.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear')),
                  ],
                ));
              if (clear == true && mounted) await _clearNotices();
            }, child: const Text('Clear all')),
          ])),
        const Divider(height: 1, color: Color(0xFF365157)),
        Expanded(child: _notices.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(22),
              child: Text('No notifications yet. Wallet activity will appear here on this device.',
                textAlign: TextAlign.center, style: TextStyle(color: _muted))))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 5),
              itemCount: _notices.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF294148)),
              itemBuilder: (ctx, i) {
                final n = _notices[i];
                final time = '${n.createdAt.day}/${n.createdAt.month} '
                  '${n.createdAt.hour.toString().padLeft(2, '0')}:'
                  '${n.createdAt.minute.toString().padLeft(2, '0')}';
                final symbol = n.kind == 'security' ? Icons.shield_outlined
                    : n.kind == 'warning' ? Icons.warning_amber_outlined
                    : n.kind == 'wallet' ? Icons.account_balance_wallet_outlined
                    : Icons.notifications_none;
                return ListTile(
                  onTap: () => _markRead(n.id),
                  leading: Icon(symbol, color: n.kind == 'warning'
                      ? Colors.amberAccent : _mint, size: 22),
                  title: Row(children: [
                    Expanded(child: Text(n.title, style: TextStyle(
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.bold,
                      fontSize: 13))),
                    if (!n.read) const CircleAvatar(radius: 4, backgroundColor: _mint),
                  ]),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.message, style: const TextStyle(color: _muted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(time, style: const TextStyle(color: _muted, fontSize: 10)),
                  ]),
                  isThreeLine: true,
                );
              },
            )),
      ]),
    );
  }

  void _scheduleFirstCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _page == _Page.wallet) _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _idleLockTimer?.cancel();
    _word3.dispose();
    _word9.dispose();
    _importText.dispose();
    _assetSearch.dispose();
    _balanceService.dispose();
    _priceService.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      // Never read or derive from the recovery phrase before device unlock.
      await _loadNotices();
      final exists = await _storage.exists();
      final autoLockMinutes = await _prefs.getAutoLockMinutes();
      if (!mounted) return;
      setState(() {
        _autoLockMinutes = autoLockMinutes;
        _page = exists ? _Page.locked : _Page.welcome;
      });
      // The first visible screen for an existing wallet is ALWAYS the lock
      // screen, never the asset dashboard. Prompt for OS authentication on
      // launch without requiring an extra tap on an in-app Security page.
      if (exists) {
        if (_foreground) {
          _queueAutomaticUnlock();
        } else {
          _promptWhenForeground = true;
        }
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Unable to open the encrypted wallet. Details: $e';
        _page = _Page.error;
      });
    }
  }

  void _queueAutomaticUnlock() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_foreground || _page != _Page.locked ||
          _saving || _authInProgress) return;
      _unlockWallet();
    });
  }

  // Pointer activity resets the in-app idle timeout; leaving the app locks
  // immediately regardless of the chosen setting (to hide wallet contents).
  void _recordUserActivity() {
    if (!mounted || !_foreground || _page != _Page.wallet) return;
    _idleLockTimer?.cancel();
    _idleLockTimer = Timer(AutoLockPolicy.timeout(_autoLockMinutes), () {
      if (!mounted || _page != _Page.wallet) return;
      if (_authInProgress) {
        _recordUserActivity(); // Avoid locking behind the OS identity dialog.
      } else {
        _lock();
      }
    });
  }

  Future<void> _updateAutoLockMinutes(int minutes) async {
    if (!AutoLockPolicy.valid(minutes)) return;
    try {
      await _prefs.setAutoLockMinutes(minutes);
      if (!mounted) return;
      setState(() => _autoLockMinutes = minutes);
      _recordUserActivity();
    } catch (_) {
      _snack('Could not save auto-lock setting.');
    }
  }

  Future<bool> _approveSendReview() async {
    // This is a separate, fresh OS authentication. It must NOT be cached from
    // wallet unlock. Later: enforce this again inside real signing service.
    final ok = await _authenticate(
      'Verify your identity for this transfer review in Harbor Vault');
    if (ok) {
      _recordUserActivity();
      _notify('Transfer review verified',
        'Identity confirmed for a simulated transfer review. No funds were sent.', kind: 'security');
    } else {
      _notify('Transfer review not approved', 'Device authentication was cancelled or unavailable.', kind: 'warning');
    }
    return ok;
  }

  Future<bool> _authenticate(String reason) async {
    if (_authInProgress) return false;
    _authInProgress = true;
    try { return await _deviceAuth.authenticate(reason: reason); }
    finally { _authInProgress = false; }
  }

  Future<void> _unlockWallet() async {
    if (_saving || _authInProgress || _page != _Page.locked || !_foreground) return;
    _promptWhenForeground = false;
    setState(() { _saving = true; _unlockError = null; });
    try {
      final authorized = await _authenticate(
        'Unlock Harbor Vault using your phone fingerprint or passcode');
      if (!authorized) {
        if (mounted) setState(() => _unlockError =
          'Unable to verify. Please try again with fingerprint, supported face unlock, or your phone screen lock.');
        return; // Fail closed; do not load recovery data.
      }
      final phrase = await _storage.getPhrase();
      if (phrase == null) throw StateError('No encrypted phrase was found.');
      final derived = WalletEngine.derive(phrase);
      final walletName = await _prefs.getWalletName();
      final verified = await _prefs.isBackupVerified();
      if (!mounted) return;
      setState(() {
        _addresses = derived;
        _walletName = walletName;
        _backupVerified = verified;
        _page = _Page.wallet;
        _unlockError = null;
        _balances.clear(); _balanceErrors.clear(); _usdPrices.clear();
        _lastChecked = null;
      });
      _recordUserActivity();
      _notify('Wallet unlocked', 'Device authentication succeeded.', kind: 'security');
      _scheduleFirstCheck();
    } catch (_) {
      if (mounted) setState(() => _unlockError =
        'The encrypted wallet could not be opened. Check your device security settings and try again.');
      // Avoid displaying internal storage errors and wallet details on lock UI.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _lock() {
    _idleLockTimer?.cancel();
    if (_page != _Page.wallet) return;
    // Prevent modal dialogs or bottom sheets from covering the locked screen.
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    navigator?.popUntil((route) => route.isFirst);
    setState(() {
      _page = _Page.locked;
      _unlockError = null;
      _addresses = null;
      _balances.clear(); _balanceErrors.clear(); _usdPrices.clear();
      _lastChecked = null;
      _refreshVersion++;
      _refreshing = false;
      _expandedNetworks.clear();
      _tab = 0;
      _notificationsOpen = false;
    });
    _notify('Wallet locked', 'Your wallet was locked and must be authenticated to reopen.', kind: 'security');
  }

  Future<void> _setWalletName(String name) async {
    await _prefs.setWalletName(name);
    if (mounted) setState(() => _walletName = name.trim());
  }

  Future<void> _verifyOfflineBackup() async {
    if (!await _authenticate('Authorize checking your recovery backup')) {
      _snack('Authentication required to verify the offline backup.');
      return;
    }
    final phrase = await _storage.getPhrase();
    if (!mounted || phrase == null) return;
    final words = phrase.split(' ');
    final positionA = 3;
    final positionB = words.length == 24 ? 21 : 9;
    final a = TextEditingController();
    final b = TextEditingController();
    final success = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Check your written backup'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Use your offline paper backup. Do not send these words anywhere.'),
        const SizedBox(height: 10),
        TextField(controller: a, autocorrect: false, enableSuggestions: false,
          decoration: InputDecoration(labelText: 'Word #$positionA')),
        const SizedBox(height: 10),
        TextField(controller: b, autocorrect: false, enableSuggestions: false,
          decoration: InputDecoration(labelText: 'Word #$positionB')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx,
          a.text.toLowerCase().trim() == words[positionA - 1] &&
          b.text.toLowerCase().trim() == words[positionB - 1]),
          child: const Text('Verify')),
      ],
    ));
    a.dispose(); b.dispose();
    if (!mounted) return;
    if (success == true) {
      await _prefs.setBackupVerified(true);
      if (mounted) setState(() => _backupVerified = true);
      _snack('Paper backup verified on this device.');
      _notify('Backup verified', 'Offline recovery backup check was completed.', kind: 'security');
    } else {
      _snack('Not verified. Keep your offline recovery phrase safe.');
    }
  }

  void _create() {
    try {
      final phrase = WalletEngine.createMnemonic(words: _newWordCount);
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
      final authorized = await _authenticate('Authorize secure wallet creation or recovery');
      if (!authorized) {
        _snack('Set up and unlock your phone with a PIN, pattern or fingerprint first.');
        return;
      }
      final derived = WalletEngine.derive(phrase);
      await _storage.storePhrase(phrase);
      await _prefs.resetForNewWallet();
      if (!mounted) return;
      setState(() {
        _addresses = derived;
        _page = _Page.wallet;
        _pendingMnemonic = null;
        _backupVerified = false;
        _balances.clear();
        _balanceErrors.clear();
        _usdPrices.clear();
        _lastChecked = null;
        _priceError = null;
        _refreshVersion++;
        _refreshing = false;
        _expandedNetworks.clear();
      });
      _recordUserActivity();
      _scheduleFirstCheck();
      _snack('Wallet saved in device encrypted storage.');
      _notify('Wallet saved', 'Recovery data was saved to device-encrypted storage.', kind: 'wallet');
    } catch (e) {
      if (mounted) _snack('Could not save the wallet: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _addresses == null || _page != _Page.wallet) return;
    final addresses = _addresses!;
    final version = ++_refreshVersion;
    setState(() {
      _refreshing = true;
      _balanceErrors.clear();
      _balances.clear(); // Never pass cached values off as fresh.
      _usdPrices.clear();
      _priceError = null;
    });

    // Only public receiving addresses go to block explorers. The pricing
    // endpoint receives no wallet address, seed phrase or private key.
    final requests = <Future<void>>[
      ...ChainAsset.values.map((asset) async {
        try {
          final value = await _balanceService.fetch(asset, addresses.of(asset));
          if (mounted && _page == _Page.wallet && version == _refreshVersion) {
            setState(() => _balances[asset] = value);
          }
        } catch (error) {
          if (mounted && _page == _Page.wallet && version == _refreshVersion) {
            // Public provider error only. No private information in exceptions.
            setState(() => _balanceErrors[asset] = error.toString());
          }
        }
      }),
      _loadPrices(version),
    ];
    await Future.wait(requests);
    if (mounted && _page == _Page.wallet && version == _refreshVersion) {
      setState(() {
        _lastChecked = DateTime.now();
        _refreshing = false;
      });
      final errors = _balanceErrors.length;
      if (errors == 0 && _priceError == null) {
        _notify('Balances refreshed', 'Public balance and price checks completed.', kind: 'wallet');
      } else {
        _notify('Balance check incomplete',
          'Some public providers did not respond. Unavailable balances are not zero.',
          kind: 'warning');
      }
    }
  }

  Future<void> _loadPrices(int version) async {
    try {
      final prices = await _priceService.fetchUsd();
      if (mounted && _page == _Page.wallet && version == _refreshVersion) {
        setState(() => _usdPrices.addAll(prices));
      }
    } catch (_) {
      if (mounted && _page == _Page.wallet && version == _refreshVersion) {
        setState(() => _priceError = 'USD pricing unavailable');
      }
    }
  }

  String _checkedLabel() {
    if (_refreshing) return 'Checking public networks and USD quotes…';
    final last = _lastChecked;
    if (last == null) return 'Not checked yet';
    final localTime = '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    return 'Last checked $localTime · Refreshes every 5 min while open';
  }

  Future<void> _copyAddress(ChainAsset asset) async {
    final address = _addresses?.of(asset);
    if (address == null) return;
    await Clipboard.setData(ClipboardData(text: address));
    _snack('${asset.symbol} public address copied. Verify the network before depositing.');
    _notify('Address copied', 'A public receiving address was copied. Verify its network.', kind: 'wallet');
  }

  Future<void> _copyNetworkAddress(ReceiveNetwork network) async {
    final addresses = _addresses;
    if (addresses == null) return;
    await Clipboard.setData(ClipboardData(text: network.addressOf(addresses)));
    _snack('Address copied for ${network.label}. Double-check the exact sending network.');
    _notify('Receive address copied', 'A public network address was copied.', kind: 'wallet');
  }

  ReceiveNetwork _networkForAsset(ChainAsset asset) => switch (asset) {
    ChainAsset.btc => ReceiveNetwork.bitcoin,
    ChainAsset.eth => ReceiveNetwork.ethereum,
    ChainAsset.ltc => ReceiveNetwork.litecoin,
    ChainAsset.usdt => ReceiveNetwork.usdtErc20,
    ChainAsset.sol => ReceiveNetwork.solana,
    ChainAsset.trx => ReceiveNetwork.tron,
    ChainAsset.usdtTrc20 => ReceiveNetwork.usdtTrc20,
  };

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
          const Text('Anyone who sees these words can take all funds. Close screen recording and make sure nobody is watching. Phone authentication is required before revealing them.'),
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
    final authorized = await _authenticate('Authorize revealing your secret recovery words');
    if (!authorized) { _snack('Phone authentication required.'); return; }
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
    if (!await _authenticate('Authorize deleting the local wallet')) {
      _snack('Phone authentication required.');
      return;
    }
    try {
      await _storage.remove();
      await _prefs.resetForNewWallet();
      await _noticeWrites;
      await _noticeStore.clear();
      if (!mounted) return;
      setState(() { _notices = []; _notificationsOpen = false; });
      setState(() {
        _addresses = null;
        _backupVerified = false;
        _balances.clear();
        _balanceErrors.clear();
        _usdPrices.clear();
        _lastChecked = null;
        _priceError = null;
        _refreshVersion++;
        _refreshing = false;
        _expandedNetworks.clear();
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordUserActivity(),
      child: Scaffold(
      appBar: AppBar(
        title: GestureDetector(onTap: _closeNotifications, behavior: HitTestBehavior.opaque,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 32, height: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.anchor_rounded, color: _bg, size: 21)),
          const SizedBox(width: 10),
          const Text('HARBOR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Text(' VAULT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 1)),
        ])),
        actions: [
          if (wallet) Padding(padding: const EdgeInsets.only(right: 10),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              IconButton(onPressed: _toggleNotifications, tooltip: 'Notifications',
                icon: Icon(_notificationsOpen ? Icons.notifications : Icons.notifications_none,
                  color: _mint, size: 27)),
              if (VaultNoticeHistory.unreadCount(_notices) > 0)
                Positioned(right: 0, top: 3, child: IgnorePointer(child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: const BoxDecoration(color: Color(0xFFE86666),
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                  child: Text(VaultNoticeHistory.unreadCount(_notices) > 99
                      ? '99+' : '${VaultNoticeHistory.unreadCount(_notices)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9,
                      fontWeight: FontWeight.w900)),
                ))),
            ])),
        ],
      ),
      body: wallet
        ? LayoutBuilder(builder: (context, bounds) => Stack(children: [
          Row(children: [
            if (desktop) NavigationRail(
              backgroundColor: _bg,
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() { _tab = value; _notificationsOpen = false; }),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Assets')),
                NavigationRailDestination(icon: Icon(Icons.qr_code), label: Text('Receive')),
                NavigationRailDestination(icon: Icon(Icons.send_outlined), label: Text('Send')),
                NavigationRailDestination(icon: Icon(Icons.history), label: Text('Activity')),
                NavigationRailDestination(icon: Icon(Icons.shield_outlined), label: Text('Security')),
                NavigationRailDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: Text('Owner')),
              ],
            ),
            Expanded(child: _walletContent()),
          ]),
          if (_notificationsOpen) ...[
            Positioned.fill(child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeNotifications,
              child: const ColoredBox(color: Colors.transparent))),
            Positioned(right: 10, top: 7,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bounds.maxWidth - 20),
                child: _notificationsPanel(bounds.maxHeight))),
          ],
        ]))
        : SafeArea(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _onboarding()),
          ))),
      bottomNavigationBar: wallet && !desktop
        ? NavigationBar(
            backgroundColor: const Color(0xFF0E222A),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            selectedIndex: _tab,
            onDestinationSelected: (value) => setState(() { _tab = value; _notificationsOpen = false; }),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Assets'),
              NavigationDestination(icon: Icon(Icons.qr_code), label: 'Receive'),
              NavigationDestination(icon: Icon(Icons.send_outlined), label: 'Send'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Activity'),
              NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Security'),
              NavigationDestination(icon: Icon(Icons.admin_panel_settings_outlined), label: 'Owner'),
            ],
          ) : null,
    ));
  }

  Widget _onboarding() {
    if (_page == _Page.loading) return const Center(child: CircularProgressIndicator());
    if (_page == _Page.locked) return Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.fingerprint, size: 76, color: _mint),
        const SizedBox(height: 24),
        const Text('Welcome back!', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        const Text('Unlock Harbor Vault with your phone security',
          textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 16)),
        const SizedBox(height: 14),
        if (_unlockError != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_unlockError!, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _saving ? null : _unlockWallet,
          icon: const Icon(Icons.fingerprint),
          label: Text(_saving ? 'Verifying…' : 'Try fingerprint / face / screen lock')),
        const SizedBox(height: 14),
        const Text('The wallet remains hidden until Android verifies your identity. Cancel or failed verification never opens the wallet.',
          textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 12)),
      ],
    );
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
      const Text('A private home for Bitcoin, Ethereum, Litecoin, Solana, TRON and USDT on ERC-20 or TRC-20. No custodial access.', style: TextStyle(color: _muted, fontSize: 16, height: 1.6)),
      const SizedBox(height: 32),
      const _InfoBanner(icon: Icons.warning_amber_outlined, text: 'PROTOTYPE · Receive-only. Do not deposit real funds until builds, derivation and storage have been independently audited.'),
      const SizedBox(height: 24),
      const Text('Recovery phrase length', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 10, children: [
        ChoiceChip(label: const Text('12 words'), selected: _newWordCount == 12,
          onSelected: (_) => setState(() => _newWordCount = 12)),
        ChoiceChip(label: const Text('24 words'), selected: _newWordCount == 24,
          onSelected: (_) => setState(() => _newWordCount = 24)),
      ]),
      const SizedBox(height: 18),
      ElevatedButton.icon(onPressed: _create, icon: const Icon(Icons.add_circle_outline), label: const Text('Create a new wallet')),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => setState(() => _page = _Page.restore), icon: const Icon(Icons.restore), label: const Text('Restore with recovery words'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52))),
      const SizedBox(height: 25),
      const Text('While the wallet is open, public receiving addresses are checked on launch and about every five minutes. USD prices come from a separate public provider. Recovery words are never sent.', style: TextStyle(color: _muted, fontSize: 12)),
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
      const _InfoBanner(icon: Icons.info_outline, text: 'This prototype checks only first receiving address (index 0) for each path. Assets held on older addresses/accounts or other EVM networks may not appear.'),
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
        const _InfoBanner(icon: Icons.lock_outline, text: 'Write these recovery words on paper, in order. Do NOT take screenshots, copy them into chat, or save them in cloud notes.'),
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
          2 => SendScreen(addresses: _addresses!, initialNetwork: _sendNetwork,
            balances: _balances, usdPrices: _usdPrices, walletName: _walletName,
            authorizeReview: _approveSendReview,
            onReviewOpened: () => _notify('Transfer preview opened',
              'A simulated transfer was reviewed. No funds were sent.', kind: 'wallet')),
          3 => HistoryScreen(addresses: _addresses!),
          4 => _securityView(),
          _ => OwnerScreen(walletName: _walletName, addresses: _addresses!,
            backupVerified: _backupVerified, onRename: _setWalletName,
            onVerifyBackup: _verifyOfflineBackup, onLock: _lock,
            autoLockMinutes: _autoLockMinutes,
            onAutoLockChanged: _updateAutoLockMinutes),
        }),
    ));
  }

  Widget _assetsView() {
    final estimate = PortfolioSummary.calculate(_balances, _usdPrices);
    final shownUsd = _balancesVisible
        ? PortfolioSummary.formatUsd(estimate.usd)
        : '••••••';
    final coverage = estimate.usd == null
        ? _priceError ?? 'Waiting for balance and USD price checks'
        : estimate.complete
            ? 'Estimate for all tracked first addresses'
            : 'Partial estimate · ${estimate.counted} of ${estimate.total} assets priced';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_walletName, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Mainnet · First receiving address only',
            style: TextStyle(color: _muted, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.account_balance_wallet_outlined, color: _mint),
      ]),
      const SizedBox(height: 17),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1B4342), Color(0xFF102A35)]),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFF2B5350)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('TOTAL WALLET BALANCE',
              style: TextStyle(color: _mint, fontSize: 12,
                fontWeight: FontWeight.w800, letterSpacing: 1.1))),
            IconButton(
              tooltip: _balancesVisible ? 'Hide balances' : 'Show balances',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _balancesVisible = !_balancesVisible),
              icon: Icon(_balancesVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: _mint, size: 20),
            ),
            IconButton(onPressed: _refreshing ? null : _refresh,
              tooltip: 'Refresh balances and USD prices',
              icon: const Icon(Icons.sync, color: _mint, size: 20)),
          ]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(shownUsd, style: const TextStyle(fontSize: 35,
              fontWeight: FontWeight.w900, letterSpacing: -.8))),
          const SizedBox(height: 5),
          Text(coverage, style: TextStyle(
            color: estimate.complete ? _muted : const Color(0xFFFFDB8C), fontSize: 12)),
          const SizedBox(height: 7),
          Text(_checkedLabel(), style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() => _tab = 2),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Send'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
                foregroundColor: _mint,
                side: const BorderSide(color: Color(0xFF5C8179))),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => setState(() => _tab = 1),
              icon: const Icon(Icons.qr_code, size: 18),
              label: const Text('Receive'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
            )),
          ]),
        ]),
      ),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Your assets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text('${WalletListing.all.length} networks & tokens',
          style: const TextStyle(fontSize: 12, color: _muted)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: _assetSearch,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Search BTC, USDT, TRC-20, Base…',
            prefixIcon: Icon(Icons.search)))),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Filter coins',
          initialValue: _assetFilter,
          onSelected: (value) => setState(() => _assetFilter = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'All', child: Text('All assets')),
            PopupMenuItem(value: 'Native', child: Text('Native coins')),
            PopupMenuItem(value: 'Stablecoins', child: Text('Stablecoins')),
          ],
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 18),
            decoration: BoxDecoration(color: _panel,
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Text(_assetFilter, style: const TextStyle(fontSize: 12)),
              const Icon(Icons.keyboard_arrow_down, size: 17),
            ])),
        ),
      ]),
      const SizedBox(height: 13),
      LayoutBuilder(builder: (context, constraints) {
        const gap = 9.0;
        final columns = constraints.maxWidth > 680 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final visible = WalletListing.search(_assetSearch.text, filter: _assetFilter);
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final listing in visible)
            SizedBox(width: cardWidth, child: _listingCard(listing)),
          if (visible.isEmpty)
            const Padding(padding: EdgeInsets.all(24),
              child: Text('No matching assets. Try another coin or network.',
                style: TextStyle(color: _muted))),
        ]);
      }),
      const SizedBox(height: 12),
      const Text('TON, SFP, MAG7.ssi and arbitrary tokens need verified contracts or separate chain integration. They are not silently added as spendable assets.',
        style: TextStyle(color: _muted, fontSize: 11)),
      const SizedBox(height: 18),
      const _InfoBanner(icon: Icons.warning_amber_outlined,
        text: 'Review-only sending. USD total includes only the supported first-address balance checks (BTC, ETH, LTC, SOL, TRX and USDT by ERC-20/TRC-20). Provider failures make the estimate partial. Do NOT deposit funds before security review.'),
    ]);
  }

  Widget _listingCard(WalletListing listing) {
    final asset = listing.trackedAsset;
    final balance = asset == null ? null : _balances[asset];
    final error = asset == null ? null : _balanceErrors[asset];
    final quote = asset == null ? null : _usdPrices[asset];
    final numeric = double.tryParse(balance ?? '');
    final validPrice = numeric != null && numeric.isFinite && numeric >= 0 &&
        quote != null && quote.isFinite && quote > 0;
    final usdValue = validPrice ? numeric! * quote! : null;
    final expanded = _expandedNetworks.contains(listing.network);
    final quantity = !_balancesVisible ? '•••• ${listing.ticker}'
      : asset == null ? 'Not tracked'
      : balance == null ? 'Unavailable' : '$balance ${listing.ticker}';
    final usdLabel = !_balancesVisible ? '••••'
      : asset == null ? '—' : PortfolioSummary.formatUsd(usdValue);
    final subtitle = asset == null ? 'Address preview · balance not tracked'
      : error != null ? 'Balance unavailable · tap for details'
      : _refreshing && balance == null ? 'Checking…'
      : balance == null ? 'Not checked' : 'Balance checked';
    return Card(margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) { _expandedNetworks.remove(listing.network); }
            else { _expandedNetworks.add(listing.network); }
          }),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(children: [
              CircleAvatar(radius: 23, backgroundColor: listing.color.withValues(alpha: .14),
                child: Text(listing.ticker.substring(0, 1),
                  style: TextStyle(color: listing.color, fontSize: 18,
                    fontWeight: FontWeight.w900))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${listing.ticker} (${listing.networkTag})',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10,
                    color: error != null || asset == null ? Colors.orangeAccent : _muted)),
              ])),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(quantity, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(usdLabel, style: const TextStyle(color: _muted, fontSize: 11)),
              ]),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18, color: _muted),
            ])),
        ),
        if (expanded) ...[
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(listing.network.caution,
                style: const TextStyle(fontSize: 11, color: _muted)),
              if (error != null) ...[
                const SizedBox(height: 8),
                SelectableText(error,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              ],
              const SizedBox(height: 10),
              SelectableText(listing.addressOf(_addresses!),
                style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _copyNetworkAddress(listing.network),
                  icon: const Icon(Icons.copy, size: 15), label: const Text('Copy'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _receiveNetwork = listing.network;
                    _tab = 1;
                  }),
                  icon: const Icon(Icons.qr_code, size: 15), label: const Text('Receive'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _sendNetwork = listing.network;
                    _tab = 2;
                  }),
                  icon: const Icon(Icons.send_outlined, size: 14), label: const Text('Send'))),
              ]),
            ])),
        ],
      ]),
    );
  }

  Widget _receiveView() {
    final addresses = _addresses!;
    final network = _receiveNetwork;
    final address = network.addressOf(addresses);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pill('NETWORK-SPECIFIC RECEIVE ADDRESSES'),
      const SizedBox(height: 17),
      const Text('Receive crypto', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Choose the exact network. Addresses on EVM networks may look the same but balances remain separate.',
        style: TextStyle(color: _muted)),
      const SizedBox(height: 18),
      DropdownButtonFormField<ReceiveNetwork>(
        value: _receiveNetwork,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Coin / Network'),
        items: ReceiveNetwork.values.map((r) => DropdownMenuItem(
          value: r, child: Text(r.label, overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (r) { if (r != null) setState(() => _receiveNetwork = r); },
      ),
      const SizedBox(height: 18),
      Container(width: double.infinity, padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(22)),
        child: Column(children: [
          Text(network.label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(network.derivationPath, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: QrImageView(data: address, size: 195, backgroundColor: Colors.white)),
          const SizedBox(height: 16),
          SelectableText(address, textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 17),
          ElevatedButton.icon(onPressed: () => _copyNetworkAddress(network),
            icon: const Icon(Icons.copy), label: const Text('Copy address')),
        ])),
      const SizedBox(height: 14),
      _InfoBanner(icon: Icons.warning_amber_outlined, text: network.caution),
      const SizedBox(height: 12),
      if (network.trackedAsset == null)
        const Text('Preview address only · balance and token indexing for this network are not implemented.',
          style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
      const SizedBox(height: 12),
      const Text('Not all chains are EVM. XRP, Bitcoin Lightning, SPL token accounts, and unlisted tokens need separate implementation. TRC-20 is TRON-specific and MUST NOT use an ERC-20 address.',
        style: TextStyle(color: _muted, fontSize: 12)),
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
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.shield_outlined, color: _mint),
              title: Text('100% your keys'), subtitle: Text('No exchange or custodial account. Recovery words stay encrypted on this device; coins remain on their blockchains.')),
          const Divider(),
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock, color: _mint),
              title: Text('Encrypted device storage'), subtitle: Text('Uses Flutter Secure Storage, backed by OS protected encryption.')),
          const Divider(),
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.gpp_maybe_outlined, color: Colors.orangeAccent),
              title: Text('Important security limitations'), subtitle: Text('Uses phone PIN/fingerprint to unlock, but memory zeroization, independent audit and hardware-wallet integration are not implemented.')),
          const Divider(),
          const ListTile(contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fingerprint, color: _mint),
              title: Text('Fingerprint / Face unlock / phone passcode'),
              subtitle: Text('Uses Android identity verification. Face authentication depends on your device settings and OS support.')),
          const Divider(),
          ListTile(contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined, color: _mint),
              title: const Text('Auto-lock while using wallet'),
              subtitle: const Text('Locks after inactivity. Switching away locks immediately.'),
              trailing: DropdownButton<int>(
                value: _autoLockMinutes,
                onChanged: (value) { if (value != null) _updateAutoLockMinutes(value); },
                items: AutoLockPolicy.options.map((minutes) => DropdownMenuItem<int>(
                  value: minutes, child: Text('$minutes min'),
                )).toList(),
              )),
          const Divider(),
          const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.public, color: Colors.lightBlueAccent),
              title: Text('Public balance checks'), subtitle: Text('On wallet open, every 5 minutes while foregrounded, and when Refresh is tapped, public addresses go to blockchain providers. USD market quotes come from CoinGecko. No recovery words are sent.')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _showRecoveryPhrase,
              icon: const Icon(Icons.visibility_outlined), label: const Text('Reveal recovery words'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(49))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _verifyOfflineBackup,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(_backupVerified ? 'Backup verified · Check again' : 'Verify offline backup'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(49))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _lock, icon: const Icon(Icons.lock_clock),
              label: const Text('Lock wallet now'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(49))),
        ]))),
      const SizedBox(height: 20),
      const Text('Standard derivation paths', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ...ChainAsset.values.where((a) => a != ChainAsset.usdt && a != ChainAsset.usdtTrc20).map((a) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
          SizedBox(width: 80, child: Text(a.symbol, style: const TextStyle(color: _mint))),
          SelectableText(a.path, style: const TextStyle(color: _muted)),
        ]))),
      const SizedBox(height: 24),
      OutlinedButton.icon(onPressed: _deleteWallet, icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        label: const Text('Delete wallet from this device', style: TextStyle(color: Colors.redAccent)),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
      const SizedBox(height: 20),
      const Text('About Harbor Vault • Version 1.3.0 (personal beta)\nSending remains disabled pending audits and on-chain test transfers. Keep an offline recovery backup.', style: TextStyle(color: _muted, fontSize: 11)),
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
