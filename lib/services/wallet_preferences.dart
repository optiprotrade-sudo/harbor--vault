import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auto_lock_policy.dart';

/// Local-only owner preferences, separate from the recovery phrase key.
class WalletPreferences {
  static const nameKey = 'harbor_vault_owner_label_v1';
  static const backupKey = 'harbor_vault_backup_verified_v1';
  static const autoRefreshKey = 'harbor_vault_auto_refresh_v1';
  static const autoLockKey = 'harbor_vault_auto_lock_minutes_v1';
  static const checklistKey = 'harbor_vault_manual_test_checklist_v12';

  final FlutterSecureStorage _storage;
  WalletPreferences({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String> getWalletName() async =>
      await _storage.read(key: nameKey) ?? 'My Harbor Wallet';

  Future<void> setWalletName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 48) {
      throw const FormatException('Wallet name must contain 1–48 characters');
    }
    await _storage.write(key: nameKey, value: trimmed);
  }

  Future<int> getAutoLockMinutes() async {
    final saved = int.tryParse(await _storage.read(key: autoLockKey) ?? '');
    return saved != null && AutoLockPolicy.valid(saved)
        ? saved : AutoLockPolicy.defaultMinutes;
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    if (!AutoLockPolicy.valid(minutes)) {
      throw ArgumentError.value(minutes, 'minutes', 'Choose 1, 2 or 3');
    }
    await _storage.write(key: autoLockKey, value: minutes.toString());
  }

  Future<bool> isBackupVerified() async =>
      await _storage.read(key: backupKey) == 'true';

  Future<void> setBackupVerified(bool value) =>
      _storage.write(key: backupKey, value: value.toString());

  Future<Set<String>> getChecklistDone() async {
    try {
      final raw = await _storage.read(key: checklistKey);
      if (raw == null) return <String>{};
      final data = jsonDecode(raw);
      if (data is! List) return <String>{};
      return data.whereType<String>().take(50).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setChecklistDone(Set<String> done) async =>
      _storage.write(key: checklistKey, value: jsonEncode(done.toList()));

  Future<void> resetForNewWallet() async {
    await _storage.delete(key: checklistKey);
    await _storage.delete(key: backupKey);
  }
}
