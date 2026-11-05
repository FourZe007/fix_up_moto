import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';

/// What to tell the member about new inbox messages, as plain text — the same
/// words whether it ends up as an in-app banner or a system notification.
class InboxAlert extends Equatable {
  /// Identifies the alert, so showing it twice replaces rather than stacks.
  final String key;
  final String title;
  final String body;

  const InboxAlert({
    required this.key,
    required this.title,
    required this.body,
  });

  /// Up to this many new messages get a notification each; more than that and
  /// they are folded into one, so a phone that was off for a week does not
  /// answer with a wall of notifications.
  static const int maxSeparate = 3;

  /// The alerts for [fresh]: one per message, or a single summary when there
  /// are more than [maxSeparate].
  ///
  /// A message is titled by its type — the server's own wording, such as
  /// "Service Booking Confirmed", exactly as the inbox titles it.
  static List<InboxAlert> of(List<NotificationEntity> fresh) {
    if (fresh.isEmpty) return const [];
    if (fresh.length > maxSeparate) return [summary(fresh.length)];
    return [
      for (final n in fresh)
        InboxAlert(key: n.id, title: _text(n.type), body: _text(n.message)),
    ];
  }

  /// "N notifikasi baru", for when naming each one would be too much.
  static InboxAlert summary(int count) => InboxAlert(
    key: 'inbox-summary',
    title: '$count notifikasi baru',
    body: 'Buka Kotak Masuk untuk membacanya.',
  );

  /// The one alert for an in-app banner, which can only show a single line of
  /// news at a time.
  static InboxAlert single(List<NotificationEntity> fresh) =>
      fresh.length == 1 ? of(fresh).first : summary(fresh.length);

  // A blank type or text would leave an empty notification.
  static String _text(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Notifikasi baru' : trimmed;
  }

  @override
  List<Object> get props => [key, title, body];
}
