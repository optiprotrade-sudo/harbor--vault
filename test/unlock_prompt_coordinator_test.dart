import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/services/unlock_prompt_coordinator.dart';

void main() {
  test('fresh launch automatically prompts once, not again after Android resume', () {
    final gate = UnlockPromptCoordinator()..existingWalletFound();
    expect(gate.beginAutomatic(locked: true, foreground: true), isTrue);
    gate.appBackgrounded(); // Android biometric dialog changed lifecycle.
    gate.appResumed(locked: true);
    gate.finished(); // User cancelled the system prompt.
    expect(gate.beginAutomatic(locked: true, foreground: true), isFalse);
    expect(gate.beginManual(locked: true), isTrue);
  });

  test('real background return queues a single new prompt', () {
    final gate = UnlockPromptCoordinator()..existingWalletFound();
    expect(gate.beginAutomatic(locked: true, foreground: true), isTrue);
    gate.finished();
    gate.lockedLocally();
    gate.appBackgrounded();
    gate.appResumed(locked: true);
    expect(gate.beginAutomatic(locked: true, foreground: true), isTrue);
    gate.finished();
    expect(gate.beginAutomatic(locked: true, foreground: true), isFalse);
  });

  test('automatic prompt is not consumed when not foreground', () {
    final gate = UnlockPromptCoordinator()..existingWalletFound();
    expect(gate.beginAutomatic(locked: true, foreground: false), isFalse);
    expect(gate.hasPendingAutomatic, isTrue);
    expect(gate.beginAutomatic(locked: true, foreground: true), isTrue);
  });

  test('local idle lock does not silently request biometric retry', () {
    final gate = UnlockPromptCoordinator();
    gate.lockedLocally();
    expect(gate.beginAutomatic(locked: true, foreground: true), isFalse);
    expect(gate.beginManual(locked: true), isTrue);
  });
}
