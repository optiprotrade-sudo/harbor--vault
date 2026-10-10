import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/asset.dart';
import '../models/receive_network.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  final PublicAddresses addresses;
  const HistoryScreen({super.key, required this.addresses});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = HistoryService();
  ReceiveNetwork _network = ReceiveNetwork.bitcoin;
  List<HistoryEntry>? _entries;
  String? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _generation++;
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_generation;
    setState(() { _loading = true; _entries = null; _error = null; });
    try {
      final entries = await _service.fetch(_network, _network.addressOf(widget.addresses));
      if (mounted && request == _generation) setState(() => _entries = entries);
    } catch (e) {
      if (mounted && request == _generation) setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Blockchain history', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 29)),
      const SizedBox(height: 8),
      const Text('Read-only public activity for the first derived address. This is not a complete account history. Token transfers, internal transfers and all networks may not be indexed.',
        style: TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 18),
      DropdownButtonFormField<ReceiveNetwork>(
        value: _network, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Choose network'),
        items: ReceiveNetwork.values.map((network) => DropdownMenuItem(
          value: network, child: Text(network.label, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (network) { if (network != null) { setState(() => _network = network); _load(); } },
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: _loading ? null : _load,
        icon: const Icon(Icons.refresh), label: const Text('Refresh history')),
      if (_loading) const Padding(padding: EdgeInsets.all(25),
        child: Center(child: CircularProgressIndicator())),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Activity unavailable: $_error', style: const TextStyle(color: Colors.orangeAccent))),
      if (_entries != null && _entries!.isEmpty) const Padding(
        padding: EdgeInsets.symmetric(vertical: 22), child: Text('No activity was returned by this public provider.')),
      for (final entry in _entries ?? <HistoryEntry>[])
        Card(child: ListTile(
          leading: Icon(entry.confirmed ? Icons.check_circle_outline : Icons.schedule,
            color: entry.confirmed ? const Color(0xFF8DF0CB) : Colors.orangeAccent),
          title: Text('${entry.id.length > 25 ? '${entry.id.substring(0, 13)}…${entry.id.substring(entry.id.length - 8)}' : entry.id}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text('${entry.confirmed ? 'Confirmed' : 'Unconfirmed / unknown'} · ${entry.source}\n${entry.time?.toString().substring(0, 16) ?? 'Time not available'}',
            style: const TextStyle(fontSize: 11)),
          trailing: IconButton(tooltip: 'Copy transaction ID', icon: const Icon(Icons.copy),
            onPressed: () => Clipboard.setData(ClipboardData(text: entry.id))),
        )),
    ]);
}
