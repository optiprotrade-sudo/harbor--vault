import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Device-bound encrypted storage. The recovery phrase is NEVER synced.
/// This is a starter: needs an independently reviewed threat model/audit.
class VaultStorage {
  static const _secretKey = 'harbor_vault_bip39_v1';
  final FlutterSecureStorage _storage;
  VaultStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> exists() => _storage.containsKey(key: _secretKey);
  Future<String?> getPhrase() => _storage.read(key: _secretKey);
  Future<void> storePhrase(String phrase) => _storage.write(key: _secretKey, value: phrase);
  Future<void> remove() => _storage.delete(key: _secretKey);
}
