import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset.dart';
import '../models/receive_network.dart';
import '../models/wallet_listing.dart';
import '../services/auto_lock_policy.dart';

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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Owner panel', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 29)),
    const SizedBox(height: 6),
    const Text('Private device administration · No hosted dashboard or remote custody',
      style: TextStyle(color: Colors.white70, fontSize: 12)),
    const SizedBox(height: 18),
    Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(children: [
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.wallet, color: _mint),
        title: Text(widget.walletName), subtitle: const Text('Personal wallet · on this device'),
        trailing: IconButton(tooltip: 'Rename wallet', onPressed: _rename,
          icon: const Icon(Icons.edit_outlined))),
      const Divider(),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.verified_user_outlined, color: _mint),
        title: const Text('Recovery backup check'),
        subtitle: Text(widget.backupVerified ? 'Verified on this device' : 'Not yet verified'),
        trailing: TextButton(onPressed: widget.onVerifyBackup, child: const Text('Verify'))),
      const Divider(),
      ListTile(contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.timer_outlined, color: _mint),
        title: const Text('Auto-lock timer'),
        subtitle: const Text('Inactive in app; background locks immediately'),
        trailing: DropdownButton<int>(
          value: widget.autoLockMinutes,
          onChanged: (value) {
            if (value != null) widget.onAutoLockChanged(value);
          },
          items: AutoLockPolicy.options.map((n) => DropdownMenuItem<int>(
            value: n, child: Text('$n min'))).toList(),
        )),
      const Divider(),
      ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lock_outline, color: _mint),
        title: const Text('Lock Harbor Vault'),
        subtitle: const Text('Require phone passcode / fingerprint again'),
        trailing: IconButton(tooltip: 'Lock now', onPressed: widget.onLock,
          icon: const Icon(Icons.lock_clock))),
    ]))),
    const SizedBox(height: 18),
    Wrap(spacing: 12, runSpacing: 12, children: [
      _stat('${ReceiveNetwork.values.length}', 'Address/network entries', Icons.hub_outlined),
      _stat('${WalletListing.all.length}', 'Listed assets', Icons.toll_outlined),
      _stat('0', 'Remote key access', Icons.shield_outlined),
    ]),
    const SizedBox(height: 18),
    OutlinedButton.icon(onPressed: _copyPublicAddresses,
      icon: const Icon(Icons.copy_all_outlined),
      label: const Text('Copy all public addresses')),
    const SizedBox(height: 10),
    const Text('Security model: no seed phrase or private key on any admin server. The same address may be used on several EVM networks. Not all networks are tracked or supported for sending.',
      style: TextStyle(color: Colors.white70, fontSize: 12)),
    const SizedBox(height: 18),
    const Card(child: Padding(padding: EdgeInsets.all(15), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Before real funds', style: TextStyle(fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('• Independently verify mnemonic and derivation paths.\n'
          '• Test restoring funds on a different compatible wallet.\n'
          '• Implement and audit chain-specific signing and broadcasting.\n'
          '• Add multi-account/address discovery and proper transaction indexing.\n'
          '• Verify Android signing and update strategy.\n'
          '• Obtain an independent security audit.',
          style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 12)),
      ]))),
  ]);

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
