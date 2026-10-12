/// Controls when Harbor Vault may automatically open the Android identity prompt.
///
/// Android may briefly report an inactive/paused lifecycle while its biometric
/// prompt is on screen. That transition must not queue a second prompt.
/// The coordinator has no wallet data, keys or operating-system dependencies.
class UnlockPromptCoordinator {
  bool _pendingAutomatic = false;
  bool _promptInFlight = false;
  bool _backgroundedOutsidePrompt = false;

  bool get promptInFlight => _promptInFlight;
  bool get hasPendingAutomatic => _pendingAutomatic;

  /// Request ONE automatic prompt after an existing wallet is detected.
  void existingWalletFound() => _pendingAutomatic = true;

  /// Ignore activity transitions caused by our own system authentication UI.
  void appBackgrounded() {
    if (!_promptInFlight) _backgroundedOutsidePrompt = true;
  }

  /// Only a genuine return from background creates a new automatic attempt.
  void appResumed({required bool locked}) {
    if (_backgroundedOutsidePrompt && locked) _pendingAutomatic = true;
    _backgroundedOutsidePrompt = false;
  }

  bool beginAutomatic({required bool locked, required bool foreground}) {
    if (!_pendingAutomatic || _promptInFlight || !locked || !foreground) {
      return false;
    }
    _pendingAutomatic = false; // Consumed before Android is invoked.
    _promptInFlight = true;
    return true;
  }

  /// A manual retry is always possible after a failed or cancelled attempt.
  bool beginManual({required bool locked}) {
    if (!locked || _promptInFlight) return false;
    _pendingAutomatic = false;
    _promptInFlight = true;
    return true;
  }

  void finished() => _promptInFlight = false;

  /// Locking from inactivity or the Lock button waits for manual retry.
  void lockedLocally() {
    _pendingAutomatic = false;
    _backgroundedOutsidePrompt = false;
  }
}
