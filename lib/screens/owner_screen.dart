import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset.dart';
import '../models/receive_network.dart';
import '../models/wallet_listing.dart';
import '../services/wallet_preferences.dart';

const _mint = Color(0xFF8DF0CB);

/// Owner-only, on-device dashboard. Not a server-admin console.
/// Never accepts or displays private keys, and has no remote withdrawal powers.
class OwnerScreen extends StatefulWidget {
  final String walletName;
  final PublicAddresses addresses;
  final bool backupVerified;
  final Future<void> Function(String) onRename;
  final Future<void> Function() onVerifyBackup;
  final void Function() onLock;
  final int autoLockMinutes;
  final Future<void> Function(int) onAutoLockChanged;
  const OwnerScreen({super.key, required this.walletName,
    required this.addresses, required this.backupVerified,
    required this.onRename, required this.onVerifyBackup, required this.onLock,
    required this.autoLockMinutes, required this.onAutoLockChanged});

  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  static const _manualChecks = <String, String>{
    'new_wallet': 'Create a fresh test wallet and verify the offline phrase',
    'restore': 'Restore the same phrase on a separate test device',
    'addresses': 'Compare BTC, ETH, LTC, SOL and TRON addresses with trusted wallets',
    'lock': 'Test unlock, 1/2/3-minute timers and background lock',
    'notices': 'Test notification bell, unread badge, outside tap and persistence',
    'balances': 'Test success/failure of public balance lookups; no false zero',
    'send_review': 'Test network selection, fee options and protected send review',
    'history': 'Check transaction histories where indexing is available',
    'signing': 'Implement and test transaction signing/broadcast on testnets',
    'audit': 'Complete independent key/recovery/signing security review',
    'release': 'Configure stable Android release signing and update testing',
  };

  final _prefs = WalletPreferences();
  Set<String> _completed = {};
  bool _savingChecklist = false;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final completed = await _prefs.getChecklistDone();
    if (mounted) setState(() => _completed = completed);
  }

  Future<void> _toggleCheck(String id, bool checked) async {
    final next = Set<String>.of(_completed);
    if (checked) { next.add(id); } else { next.remove(id); }
    setState(() { _completed = next; _savingChecklist = true; });
    try {
      await _prefs.setChecklistDone(next);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not save the testing checklist.')));
    } finally {
      if (mounted) setState(() => _savingChecklist = false);
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: widget.walletName);
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename this wallet'),
      content: TextField(controller: controller, maxLength: 48,
        decoration: const InputDecoration(labelText: 'Wallet name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save')),
      ],
    ));
    controller.dispose();
    if (value != null && value.isNotEmpty) {
      try { await widget.onRename(value); }
      catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save wallet name.'))); }
    }
  }

  Future<void> _copyPublicAddresses() async {
    final lines = ReceiveNetwork.values.map((n) =>
      '${n.label}: ${n.addressOf(widget.addresses)}').join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Public receiving addresses copied. The recovery phrase was not copied.')));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Owner', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 30)),
      const SizedBox(height: 6),
      const Text('Manage your personal wallet without exposing private keys or '
          'opening a remote admin panel.',
        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
      const SizedBox(height: 18),
      Card(child: ExpansionTile(
        key: const PageStorageKey('owner_wallet'),
        initiallyExpanded: true,
        leading: const Icon(Icons.account_balance_wallet_outlined, color: _mint),
        title: const Text('Wallet profile', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(widget.walletName, style: const TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 15),
        children: [
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, color: _mint),
            title: const Text('Wallet name'),
            subtitle: Text(widget.walletName),
            trailing: TextButton(onPressed: _rename, child: const Text('Rename'))),
          const Divider(height: 8),
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined, color: _mint),
            title: const Text('Recovery backup'),
            subtitle: Text(widget.backupVerified ? 'Checked on this device' : 'Not verified'),
            trailing: TextButton(onPressed: widget.onVerifyBackup, child: const Text('Verify'))),
          const Divider(height: 8),
          ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline, color: _mint),
            title: const Text('Lock wallet now'),
            subtitle: Text('Auto-lock: ${widget.autoLockMinutes} min • Change in Security'),
            trailing: IconButton(onPressed: widget.onLock,
              tooltip: 'Lock wallet', icon: const Icon(Icons.lock_clock))),
        ],
      )),
      const SizedBox(height: 10),
      Card(child: ExpansionTile(
        key: const PageStorageKey('owner_networks'),
        leading: const Icon(Icons.hub_outlined, color: _mint),
        title: const Text('Networks & public addresses',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('View counts or copy receiving addresses',
          style: TextStyle(fontSize: 12)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
        children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _stat('${ReceiveNetwork.values.length}', 'Networks', Icons.hub_outlined),
            _stat('${WalletListing.all.length}', 'Assets listed', Icons.toll_outlined),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _copyPublicAddresses,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy all public addresses')),
          const SizedBox(height: 12),
          const Text('Some EVM networks share an address. Not all assets are '
            'balance-tracked or supported for sending.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
        ],
      )),
      const SizedBox(height: 10),
      Card(child: ExpansionTile(
        key: const PageStorageKey('owner_checklist'),
        leading: const Icon(Icons.fact_check_outlined, color: _mint),
        title: const Text('Personal testing checklist',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_completed.length} / ${_manualChecks.length} marked • Saved on device',
          style: const TextStyle(fontSize: 12)),
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(
            'These are personal test notes, not proof that cryptocurrency is safe '
            'to deposit. Security review is still required.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12))),
          ..._manualChecks.entries.map((entry) => CheckboxListTile(
            dense: true, activeColor: _mint, checkColor: Colors.black,
            title: Text(entry.value, style: const TextStyle(fontSize: 12)),
            value: _completed.contains(entry.key),
            onChanged: _savingChecklist ? null : (checked) =>
              _toggleCheck(entry.key, checked ?? false),
          )),
          TextButton.icon(onPressed: _savingChecklist || _completed.isEmpty ? null
            : () async {
                setState(() { _completed = {}; _savingChecklist = true; });
                try { await _prefs.setChecklistDone(<String>{}); }
                catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checklist could not be reset.')));
                } finally {
                  if (mounted) setState(() => _savingChecklist = false);
                }
              },
            icon: const Icon(Icons.restart_alt), label: const Text('Reset checklist')),
        ],
      )),
      const SizedBox(height: 10),
      const Card(child: ExpansionTile(
        key: PageStorageKey('owner_about'),
        leading: Icon(Icons.info_outline, color: _mint),
        title: Text('About & limitations',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Version 1.4.0 • Personal beta', style: TextStyle(fontSize: 12)),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          Text('Your wallet is private to this device; no server can control '
              'its keys. Sending and broadcasting are still disabled.',
            style: TextStyle(color: Colors.white70, height: 1.5)),
          SizedBox(height: 12),
          Text('Before real funds: independently verify mnemonic recovery and '
              'derivation paths, implement and audit signing/broadcast, test '
              'multi-address discovery, and configure stable Android release signing.',
            style: TextStyle(color: Colors.orangeAccent, height: 1.5)),
        ],
      )),
      const SizedBox(height: 22),
    ],
  );

  Widget _stat(String value, String label, IconData icon) => Container(
    width: 155, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF10242B),
      borderRadius: BorderRadius.circular(13)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _mint), const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
}
