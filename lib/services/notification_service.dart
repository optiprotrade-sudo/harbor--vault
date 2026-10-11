import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Only neutral operational metadata is stored: never wallet addresses,
/// recovery phrases, private keys, recipient names or transfer amounts.
class VaultNotice {
  final String id;
  final DateTime createdAt;
  final String title;
  final String message;
  final String kind;
  final bool read;

  const VaultNotice({required this.id, required this.createdAt,
    required this.title, required this.message, required this.kind,
    this.read = false});

  VaultNotice markRead() => VaultNotice(id: id, createdAt: createdAt,
    title: title, message: message, kind: kind, read: true);

  Map<String, Object?> toJson() => {
    'id': id, 'date': createdAt.toUtc().toIso8601String(), 'title': title,
    'message': message, 'kind': kind, 'read': read,
  };

  static VaultNotice? fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final date = DateTime.tryParse(raw['date']?.toString() ?? '');
    final id = raw['id'];
    final title = raw['title'];
    final message = raw['message'];
    final kind = raw['kind'];
    if (id is! String || id.isEmpty || date == null || title is! String ||
        message is! String || kind is! String) return null;
    return VaultNotice(id: id, createdAt: date.toLocal(), title: title,
      message: message, kind: kind, read: raw['read'] == true);
  }
}

class VaultNoticeHistory {
  static const maxEntries = 100;

  static List<VaultNotice> decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      final raw = jsonDecode(encoded);
      if (raw is! List) return [];
      final notices = raw.map(VaultNotice.fromJson).whereType<VaultNotice>().toList();
      notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notices.take(maxEntries).toList();
    } catch (_) {
      return [];
    }
  }

  static String encode(List<VaultNotice> items) =>
      jsonEncode(items.take(maxEntries).map((item) => item.toJson()).toList());

  static int unreadCount(List<VaultNotice> items) =>
      items.where((item) => !item.read).length;

  static List<VaultNotice> add(List<VaultNotice> items, VaultNotice notice) =>
      [notice, ...items.where((item) => item.id != notice.id)]
          .take(maxEntries).toList();

  static List<VaultNotice> markAllRead(List<VaultNotice> items) =>
      items.map((item) => item.markRead()).toList();
}

/// Kept on device in Android-encrypted storage. This is app history, not
/// system push notifications or an off-device monitoring service.
class VaultNotificationStore {
  static const storageKey = 'harbor_vault_local_notices_v12';
  final FlutterSecureStorage _storage;
  VaultNotificationStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<VaultNotice>> load() async =>
      VaultNoticeHistory.decode(await _storage.read(key: storageKey));

  Future<void> save(List<VaultNotice> items) =>
      _storage.write(key: storageKey, value: VaultNoticeHistory.encode(items));

  Future<void> clear() => _storage.delete(key: storageKey);
}
