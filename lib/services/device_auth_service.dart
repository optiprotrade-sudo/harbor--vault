import 'package:local_auth/local_auth.dart';

/// Uses the phone's registered PIN/passcode/pattern or biometrics.
/// No custom PIN hash or secret is stored by Harbor Vault.
/// Not a replacement for auditing OS keystore/device security.
class DeviceAuthService {
  final LocalAuthentication _authentication;
  DeviceAuthService([LocalAuthentication? authentication])
      : _authentication = authentication ?? LocalAuthentication();

  Future<bool> supported() => _authentication.isDeviceSupported();

  Future<bool> authenticate({required String reason}) async {
    try {
      if (!await supported()) return false;
      return await _authentication.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          // We manage the app resume lifecycle ourselves. `stickyAuth: true`
          // may reopen the OS prompt when returning from it on some devices.
          stickyAuth: false,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      // Fail closed on unavailable, cancelled, locked-out or misconfigured auth.
      return false;
    }
  }
}
