import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';

/// What one look at the inbox found.
class InboxCheck {
  /// Unread messages the member has not been told about yet, in the order the
  /// server sent them.
  final List<NotificationEntity> fresh;

  /// How many messages are unread in all, told about or not — the badge number.
  final int unread;

  final Future<void> Function() _markSeen;

  InboxCheck({
    required this.fresh,
    required this.unread,
    required Future<void> Function() markSeen,
  }) : _markSeen = markSeen;

  /// Remembers [fresh] as told, so the next look does not report them again.
  /// Call it once they were actually shown — a message that was found but could
  /// not be shown stays fresh for the next look.
  Future<void> markSeen() => _markSeen();
}

/// Finds out which inbox messages are new since the last look.
///
/// This is how the app learns about things the *server* did — points credited,
/// a booking confirmed — without the server pushing anything: the server already
/// writes those into the member's inbox, and the app asks for the inbox.
///
/// "New" means unread and not yet reported. What was reported is remembered per
/// member in [SharedPreferences], which also makes it shared between the app and
/// its background check (two isolates), so a message is announced once, by
/// whichever looks first.
class InboxWatcher {
  /// Prefix of the key holding one member's reported message ids.
  static const String seenKeyPrefix = 'inbox_seen_ids_';

  /// The most ids kept per member. Read messages never come back as unread, so
  /// only a long run of unread ones could ever fill it; the oldest go first.
  static const int maxRemembered = 200;

  final GetNotificationsUseCase _getNotifications;
  final SharedPreferences _prefs;

  InboxWatcher({
    required GetNotificationsUseCase getNotifications,
    required SharedPreferences prefs,
  }) : _getNotifications = getNotifications,
       _prefs = prefs;

  static String keyFor(String memberId) => '$seenKeyPrefix$memberId';

  /// Looks at [memberId]'s inbox. Null when it could not be read (offline, the
  /// server refused) — callers just try again later.
  ///
  /// The very first look for a member reports nothing as fresh: whatever is
  /// unread already was there before the app could have told anyone, and the
  /// badge and the inbox show it. Without that, a fresh install would announce
  /// the member's whole backlog.
  Future<InboxCheck?> check(String memberId) async {
    // The other isolate may have written since this one's copy was made.
    await _prefs.reload();

    final result = await _getNotifications(const GetNotificationsParams());
    final inbox = result.fold<List<NotificationEntity>?>((_) => null, (v) => v);
    if (inbox == null) return null;

    final unread = inbox.where((n) => !n.isRead).toList();
    final key = keyFor(memberId);
    final remembered = _prefs.getStringList(key);

    if (remembered == null) {
      await _remember(key, unread.map((n) => n.id));
      return InboxCheck(
        fresh: const [],
        unread: unread.length,
        markSeen: () async {},
      );
    }

    final seen = remembered.toSet();
    final fresh = unread.where((n) => !seen.contains(n.id)).toList();
    return InboxCheck(
      fresh: fresh,
      unread: unread.length,
      markSeen: () => _remember(key, fresh.map((n) => n.id)),
    );
  }

  /// Adds [ids] to what [key] holds. Reads it again first: the other isolate
  /// may have added to it between the look and now, and that must survive.
  Future<void> _remember(String key, Iterable<String> ids) async {
    await _prefs.reload();
    final all = <String>{...?_prefs.getStringList(key), ...ids}.toList();
    final kept = all.length > maxRemembered
        ? all.sublist(all.length - maxRemembered)
        : all;
    await _prefs.setStringList(key, kept);
  }
}
