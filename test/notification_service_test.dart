import 'package:flutter_test/flutter_test.dart';
import 'package:harbor_vault/services/notification_service.dart';

void main() {
  VaultNotice sample(int index, {bool read = false}) => VaultNotice(
    id: 'sample-$index', createdAt: DateTime.utc(2026, 10, 10, 12, index % 60),
    title: 'Checked network', message: 'Provider status only',
    kind: 'wallet', read: read);

  test('notification history serializes without losing unread state', () {
    final original = [sample(2), sample(1, read: true)];
    final loaded = VaultNoticeHistory.decode(VaultNoticeHistory.encode(original));
    expect(loaded.map((n) => n.id).toList(), ['sample-2', 'sample-1']);
    expect(VaultNoticeHistory.unreadCount(loaded), 1);
    expect(loaded[1].read, true);
  });

  test('mark all read and clear is predictable', () {
    final original = [sample(1), sample(2)];
    final updated = VaultNoticeHistory.markAllRead(original);
    expect(VaultNoticeHistory.unreadCount(updated), 0);
    expect(VaultNoticeHistory.decode(null), isEmpty);
    expect(VaultNoticeHistory.decode('{not json'), isEmpty);
  });

  test('local history is capped and never duplicates the same id', () {
    var notices = <VaultNotice>[];
    for (var i = 0; i < 150; i++) {
      notices = VaultNoticeHistory.add(notices, sample(i));
    }
    expect(notices.length, VaultNoticeHistory.maxEntries);
    notices = VaultNoticeHistory.add(notices, sample(149));
    expect(notices.length, VaultNoticeHistory.maxEntries);
    expect(notices.first.id, 'sample-149');
  });

  test('malformed notice records are safely ignored', () {
    final decoded = VaultNoticeHistory.decode('[{"title":"missing"}]');
    expect(decoded, isEmpty);
  });
}
