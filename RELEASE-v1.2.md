# Harbor Vault v1.2 • Personal beta

Built on the v1.1 source. One clean update package with the required source,
tests, GitHub build workflow, and one-push Windows script.

## New

- Header bell replaces the old version label.
- Dismissible overlay panel; tapping outside dismisses it.
- Unread count, per-entry read, mark all read, clear all with confirmation.
- Local encrypted notification history (up to 100 entries), timestamped and
  limited to nonsensitive event metadata; no hosted notifications or push.
- Relevant wallet events: unlock, background/idle lock, backup verification,
  address copy, public balance check, simulated transfer review.
- Manual Owner testing checklist with saved progress and reset option.
- Version is now located in Security and Owner.
- Tests for notice read state, JSON encoding and bounded history.

## Not included

- Actual spending, private-key transaction signatures and broadcasts.
- Off-device notification sync, blockchain event subscriptions, public launch.
- A security audit or verified account discovery for arbitrary existing wallets.

Do not deposit any cryptocurrency into this beta.
