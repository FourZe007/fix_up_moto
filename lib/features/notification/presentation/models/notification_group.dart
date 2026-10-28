import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';

/// A run of inbox messages shown under one day heading.
class NotificationGroup extends Equatable {
  /// What the heading says: [today] or [yesterday]. Null for everything older
  /// and for a message with no readable date, which get no heading: the inbox
  /// comes newest first, so whatever follows Kemarin is plainly older.
  final String? label;
  final List<NotificationEntity> notifications;

  const NotificationGroup(this.label, this.notifications);

  static const today = 'Hari ini';
  static const yesterday = 'Kemarin';

  @override
  List<Object?> get props => [label, notifications];
}

/// Splits [notifications] into day groups, for headings above the list.
///
/// Only *neighbouring* messages with the same heading are grouped, so the order
/// the backend sent them in is never changed — if the list is not strictly
/// newest first, a heading simply appears again further down. A message dated
/// today or later (a clock a day ahead) counts as today; one older than
/// yesterday, or with no date, has no heading (a null [NotificationGroup.label]).
/// [now] is for tests.
List<NotificationGroup> groupNotificationsByDay(
  List<NotificationEntity> notifications, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final groups = <NotificationGroup>[];

  for (final notification in notifications) {
    final label = _labelOf(notification.date, clock);

    if (groups.isNotEmpty && groups.last.label == label) {
      groups.last.notifications.add(notification);
    } else {
      groups.add(NotificationGroup(label, [notification]));
    }
  }
  return groups;
}

String? _labelOf(DateTime? date, DateTime now) {
  if (date == null) return null;

  // Whole calendar days, counted in UTC so a daylight-saving change cannot
  // make a day 23 hours long and round it down to zero.
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;

  if (days <= 0) return NotificationGroup.today;
  if (days == 1) return NotificationGroup.yesterday;
  return null;
}
