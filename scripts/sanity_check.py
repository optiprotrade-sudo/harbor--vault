"""Static integrity checks; not a substitute for Flutter compilation or security audit."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
expected = {
    'lib/main.dart': ['SELF-CUSTODY  •  v1.0', 'HistoryScreen(', 'OwnerScreen(', '_Page.locked'],
    'lib/screens/send_screen.dart': ['Review transfer · simulation', 'Broadcast disabled', 'Choose coin & network'],
    'lib/screens/owner_screen.dart': ['Owner panel', 'Verify'],
    'lib/screens/history_screen.dart': ['Blockchain history'],
    'lib/services/wallet_engine.dart': ['words = 12', "words == 12 ? 16 : 32", 'tronAddressFromEthHex'],
    'lib/models/wallet_listing.dart': ['ReceiveNetwork.usdtTrc20', 'ReceiveNetwork.usdtErc20'],
    'lib/services/device_auth_service.dart': ['LocalAuthentication'],
    'pubspec.yaml': ['local_auth:', 'version: 1.0.0+10'],
    'scripts/prepare_android.py': ['FlutterFragmentActivity', 'android.permission.USE_BIOMETRIC'],
}
for rel,required in expected.items():
    t=(root/rel).read_text(encoding='utf-8')
    for marker in required:
        if marker not in t:
            raise SystemExit(f'Missing expected v1.0 feature: {rel} does not include {marker!r}')
print('Consolidated v1.0 static preflight passed. Flutter compilation and security audit are separate.')
