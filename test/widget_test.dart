import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/main.dart';

// Compile-time smoke test: the application entry widget is HarborVaultApp,
// not the default MyApp from flutter create. This does not validate wallet
// cryptography or encrypted storage.
void main() {
  test('Harbor Vault app entry widget exists', () {
    const app = HarborVaultApp();
    expect(app, isA<StatelessWidget>());
  });
}
