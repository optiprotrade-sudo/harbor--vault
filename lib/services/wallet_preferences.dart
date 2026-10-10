import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local-only owner preferences, separate from the recovery phrase key.
class WalletPreferences {
  static const nameKey = 'harbor_vault_owner_label_v1';
  static const backupKey = 'harbor_vault_backup_verified_v1';
  static const autoRefreshKey = 'harbor_vault_auto_refresh_v1';

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

  Future<bool> isBackupVerified() async =>
      await _storage.read(key: backupKey) == 'true';

  Future<void> setBackupVerified(bool value) =>
      _storage.write(key: backupKey, value: value.toString());

  Future<void> resetForNewWallet() async {
    await _storage.delete(key: backupKey);
  }
}
