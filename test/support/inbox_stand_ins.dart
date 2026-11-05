import 'dart:async';

import 'package:fix_up_moto/core/push/local_notifier.dart';
import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_background.dart';

/// An inbox message with only what a test cares about.
NotificationEntity inboxMessage(
  String id, {
  String type = 'Service Booking Confirmed',
  String message = 'Booking Anda sudah dikonfirmasi.',
  bool isRead = false,
  String memberId = 'M-001',
}) => NotificationEntity(
  memberId: memberId,
  id: id,
  type: type,
  message: message,
  date: DateTime(2026, 11, 5),
  isSent: true,
  isRead: isRead,
  numberOfNotifications: 0,
  image: '',
  link: '',
);

/// A [LocalNotifier] that records what it was asked to show.
class FakeLocalNotifier implements LocalNotifier {
  /// What [canShow] answers: whether the phone lets the app notify.
  bool allowed;

  /// What [launchedByTap] answers: a tap started the app.
  bool startedByTap;

  /// Makes [show] throw, to test that a failed notification is not "seen".
  bool throwOnShow = false;

  int inits = 0;

  /// Every notification shown, in order.
  final List<({String key, String title, String body})> shown = [];

  final StreamController<void> tapController =
      StreamController<void>.broadcast();

  FakeLocalNotifier({this.allowed = true, this.startedByTap = false});

  @override
  Future<void> init() async => inits++;

  @override
  Future<bool> canShow() async => allowed;

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
  }) async {
    if (throwOnShow) throw StateError('notification failed');
    shown.add((key: key, title: title, body: body));
  }

  @override
  Stream<void> get taps => tapController.stream;

  @override
  Future<bool> launchedByTap() async => startedByTap;
}

/// An [InboxBackgroundScheduler] that only counts.
class FakeInboxScheduler implements InboxBackgroundScheduler {
  int scheduled = 0;
  int cancelled = 0;

  @override
  Future<void> schedule() async => scheduled++;

  @override
  Future<void> cancel() async => cancelled++;
}
