# Harbor Vault v1.2 — private wallet beta

Flutter Android-first personal wallet prototype. Uses local device authentication,
encrypted recovery phrase storage, first-address derivation on selected chains,
public balance lookups, a review-only Send UI, read-only history on selected
networks, an on-device Owner Panel and a local notification inbox.

**This is not safe for real funds.** Sending/broadcasting is disabled. Key
recovery and derivation, blockchain tracking and application security have not
been independently audited or fully tested against reference wallets.

See **START-HERE.txt** for the single-upload GitHub update process and
**RELEASE-v1.2.md** for the exact changes.

A locally persisted notice is not a blockchain event or an official receipt.
Encrypted data may be lost when uninstalling the app. Keep test-wallet recovery
phrases off-device and never upload them to GitHub.


## v1.3 combined security and notification update

Build includes the full v1.2 notification inbox and owner test checklist, plus
launch/return-to-app authentication. Existing encrypted wallets remain locked
until Android device authentication succeeds. Fingerprint/compatible biometric
methods and system device credentials are managed by Android `local_auth`.
Cancelling authentication leaves a retry screen. The inactivity timer remains
1/2/3 minutes; backgrounding locks immediately.

This is NOT a completed cryptocurrency wallet. Mainnet signing and sending are
still disabled, and restoring derived addresses has not been independently
validated. Do not store real funds.
