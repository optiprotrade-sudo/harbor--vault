# Harbor Vault v1.4 — Personal Android Wallet Beta

Harbor Vault is a Flutter, non-custodial **prototype** for one owner. It has
receive-address previews for multiple chains, selective public balance and
history lookups, a review-only Send screen, local encrypted seed storage,
notification history, and a private Owner Panel.

The **v1.4 update** fixes the duplicate Android biometric prompt with a
single-attempt unlock coordinator, turns the locked background into a
**Welcome back** screen, and groups Security/Owner options into concise
expandable cards. Its automatic biometric retry is disabled at the OS wrapper
level; manual retry remains available. The owner can select 1-, 2-, or 3-minute
inactivity locking; leaving the app locks it immediately.

The locked screen must not reveal wallet addresses, recovery words or balances.
Device biometric/face/PIN behavior depends on the Android phone and enrolled
unlock methods. The app never stores an unlock PIN itself.

See **START-HERE.txt** for updating the existing private GitHub repository using
a single push, and **RELEASE-v1.4.md** for the release change log and test plan.

## Development and security status

**Not approved for real funds.** Sending and broadcasting are disabled.
Address derivation, recovery, account discovery, signing, backup behavior and
third-party providers have not completed independent security testing. The
public balance APIs can see which addresses you query. Keep recovery words
private and offline; never upload them or signing keys to GitHub.
