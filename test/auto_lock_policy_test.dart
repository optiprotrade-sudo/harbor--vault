import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/services/auto_lock_policy.dart';

void main() {
  test('supported idle lock intervals are 1, 2, 3 minutes', () {
    expect(AutoLockPolicy.options, [1, 2, 3]);
    for (final minutes in AutoLockPolicy.options) {
      expect(AutoLockPolicy.valid(minutes), isTrue);
      expect(AutoLockPolicy.timeout(minutes), Duration(minutes: minutes));
    }
    expect(AutoLockPolicy.defaultMinutes, 2);
  });

  test('invalid and zero minute intervals fail closed', () {
    for (final minutes in [0, 4, -1, 99]) {
      expect(AutoLockPolicy.valid(minutes), isFalse);
      expect(() => AutoLockPolicy.timeout(minutes), throwsArgumentError);
    }
  });
}
