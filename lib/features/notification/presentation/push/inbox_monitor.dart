import 'dart:async';
import 'dart:developer';

import 'package:fix_up_moto/core/push/local_notifier.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_background.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_watcher.dart';

/// Keeps the app aware of new inbox messages, for as long as a member is signed
/// in. No UI: [PushBootstrap] drives it and turns what it reports into a banner,
/// a navigation, and (through [onUnread]) the bell's badge.
///
/// Two places look at the inbox, never at the same time in a way that matters
/// (both go through [InboxWatcher], which announces a message once):
/// - **While the app is open**: right away, whenever it comes back to the front,
///   and every [interval] — reported through [fresh] for an in-app banner.
/// - **While it is closed**: [InboxBackgroundScheduler], on Android, as a system
///   notification.
class InboxMonitor {
  final InboxWatcher _watcher;
  final InboxBackgroundScheduler _scheduler;
  final LocalNotifier _notifier;
  final void Function(int unread) _onUnread;
  final Duration _interval;

  final StreamController<List<NotificationEntity>> _fresh =
      StreamController<List<NotificationEntity>>.broadcast();

  Timer? _timer;
  String? _memberId;
  bool _foreground = true;
  bool _checking = false;

  InboxMonitor({
    required InboxWatcher watcher,
    required InboxBackgroundScheduler scheduler,
    required LocalNotifier notifier,
    required void Function(int unread) onUnread,
    Duration interval = const Duration(minutes: 2),
  }) : _watcher = watcher,
       _scheduler = scheduler,
       _notifier = notifier,
       _onUnread = onUnread,
       _interval = interval;

  /// New unread messages found while the app is open, each batch once.
  Stream<List<NotificationEntity>> get fresh => _fresh.stream;

  /// The member tapped one of the app's own notifications.
  Stream<void> get taps => _notifier.taps;

  /// Prepares the notifier. Returns whether a tap on one of the app's own
  /// notifications is what started the app. Never throws.
  Future<bool> init() async {
    try {
      await _notifier.init();
      return await _notifier.launchedByTap();
    } catch (e) {
      log('init failed: $e', name: 'InboxMonitor');
      return false;
    }
  }

  /// A member is signed in: look now, keep looking, and arrange for the
  /// background look. Calling it again for the same member changes nothing —
  /// a profile edit emits a new signed-in state without anyone having signed in.
  Future<void> signedIn(String memberId) async {
    if (_memberId == memberId) return;
    _memberId = memberId;
    unawaited(_scheduler.schedule());
    _restartTimer();
    await refresh();
  }

  /// The member signed out: stop looking and clear the badge.
  Future<void> signedOut() async {
    final wasSignedIn = _memberId != null;
    _memberId = null;
    _timer?.cancel();
    _timer = null;
    await _scheduler.cancel();
    if (wasSignedIn) _onUnread(0);
  }

  /// The app left the front: stop the timer (the background look takes over).
  void pause() {
    _foreground = false;
    _timer?.cancel();
    _timer = null;
  }

  /// The app is back: look now, since things may have happened meanwhile.
  Future<void> resume() async {
    _foreground = true;
    if (_memberId == null) return;
    _restartTimer();
    await refresh();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = _foreground
        ? Timer.periodic(_interval, (_) => unawaited(refresh()))
        : null;
  }

  /// Looks at the inbox once, now. Also for after the member reads a message,
  /// so the badge follows. A look already under way is not doubled.
  Future<void> refresh() async {
    final memberId = _memberId;
    if (memberId == null || _checking) return;
    _checking = true;
    try {
      final check = await _watcher.check(memberId);
      // Signed out, or someone else signed in, while the server was answering.
      if (check == null || _memberId != memberId) return;

      _onUnread(check.unread);
      if (check.fresh.isEmpty) return;

      // Sent to the background while waiting: nobody is looking at a banner, so
      // do not use the messages up. The background look (or the next resume)
      // still finds them new.
      if (!_foreground) return;

      _fresh.add(check.fresh);
      await check.markSeen();
    } catch (e) {
      log('Inbox look failed: $e', name: 'InboxMonitor');
    } finally {
      _checking = false;
    }
  }

  /// Stops everything and closes the streams. The monitor lives for the whole
  /// process, so only tests need this.
  Future<void> dispose() async {
    _timer?.cancel();
    await _fresh.close();
  }
}
