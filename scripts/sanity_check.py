"""Static integrity checks; not a substitute for Flutter compilation or security audit."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
expected = {
    'lib/main.dart': ['Icons.notifications_none', 'VaultNoticeHistory', 'HistoryScreen(', 'OwnerScreen(', '_Page.locked', '_queueAutomaticUnlock', 'Welcome back', '_unlockError', 'UnlockPromptCoordinator'],
    'lib/screens/send_screen.dart': ['Review transfer · simulation', 'Verify identity', 'Choose coin & network'],
    'lib/screens/owner_screen.dart': ['Owner panel', 'testing checklist', 'About Harbor Vault'],
    'lib/screens/history_screen.dart': ['Blockchain history'],
    'lib/services/wallet_engine.dart': ['words = 12', "words == 12 ? 16 : 32", 'tronAddressFromEthHex'],
    'lib/models/wallet_listing.dart': ['ReceiveNetwork.usdtTrc20', 'ReceiveNetwork.usdtErc20'],
    'lib/services/notification_service.dart': ['VaultNotificationStore', 'markAllRead', 'maxEntries = 100'],
    'test/notification_service_test.dart': ['unreadCount', 'history is capped'],
    'lib/services/device_auth_service.dart': ['LocalAuthentication', 'AuthenticationOptions(', 'biometricOnly: false'],
    'lib/services/auto_lock_policy.dart': ['defaultMinutes = 2', 'options = [1, 2, 3]'],
    'lib/screens/owner_screen.dart': ['Version 1.4.0', 'testing checklist'],
    'lib/services/unlock_prompt_coordinator.dart': ['beginAutomatic', 'beginManual', 'appResumed'],
    'test/unlock_prompt_coordinator_test.dart': ['real background return', 'fresh launch automatically'],
    'lib/services/wallet_preferences.dart': ['getAutoLockMinutes', 'setAutoLockMinutes'],
    'test/auto_lock_policy_test.dart': ['AutoLockPolicy.timeout'],
    'pubspec.yaml': ['local_auth:', 'version: 1.4.0+14'],
    'scripts/prepare_android.py': ['FlutterFragmentActivity', 'android.permission.USE_BIOMETRIC'],
}
for rel,required in expected.items():
    t=(root/rel).read_text(encoding='utf-8')
    for marker in required:
        if marker not in t:
            raise SystemExit(f'Missing expected v1.3 feature: {rel} does not include {marker!r}')
print('Consolidated v1.4 static preflight passed. Flutter compilation and security audit are separate.')
