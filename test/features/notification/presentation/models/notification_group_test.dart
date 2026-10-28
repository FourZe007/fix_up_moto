import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/domain/entities/notification_entity.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_group.dart';

NotificationEntity message(String id, DateTime? date) => NotificationEntity(
  memberId: '0101202300000003',
  id: id,
  type: 'Service Reminder',
  message: 'Jangan lupa servis motor Anda',
  date: date,
  isSent: true,
  isRead: false,
  numberOfNotifications: 0,
  image: '',
  link: '',
);

List<String?> labelsOf(List<NotificationGroup> groups) => [
  for (final group in groups) group.label,
];

List<List<String>> idsOf(List<NotificationGroup> groups) => [
  for (final group in groups) [for (final n in group.notifications) n.id],
];

void main() {
  // A Wednesday afternoon: the middle of the day, so a few hours either way
  // cannot change which day it is.
  final now = DateTime(2024, 3, 13, 15, 30);

  group('groupNotificationsByDay', () {
    test('gives nothing for an empty inbox', () {
      expect(groupNotificationsByDay(const [], now: now), isEmpty);
    });

    test('names a message sent today Hari ini, whatever the time', () {
      for (final sent in [
        DateTime(2024, 3, 13),
        DateTime(2024, 3, 13, 0, 0, 1),
        DateTime(2024, 3, 13, 23, 59, 59),
      ]) {
        expect(
          labelsOf(groupNotificationsByDay([message('a', sent)], now: now)),
          [NotificationGroup.today],
          reason: '$sent',
        );
      }
    });

    test('names the day before Kemarin, even late at night and early in the '
        'morning', () {
      expect(
        labelsOf(
          groupNotificationsByDay([
            message('a', DateTime(2024, 3, 12)),
          ], now: now),
        ),
        [NotificationGroup.yesterday],
      );
      // A day boundary, not "24 hours ago": 00:10 now, 23:50 the evening before.
      expect(
        labelsOf(
          groupNotificationsByDay([
            message('a', DateTime(2024, 3, 12, 23, 50)),
          ], now: DateTime(2024, 3, 13, 0, 10)),
        ),
        [NotificationGroup.yesterday],
      );
    });

    test('gives anything older no heading at all', () {
      for (final sent in [
        DateTime(2024, 3, 11),
        DateTime(2024, 1, 1),
        DateTime(2023, 12, 12),
      ]) {
        expect(
          labelsOf(groupNotificationsByDay([message('a', sent)], now: now)),
          [null],
          reason: '$sent',
        );
      }
    });

    test('gives a message with no readable date no heading either', () {
      expect(
        labelsOf(groupNotificationsByDay([message('a', null)], now: now)),
        [null],
      );
    });

    test(
      'counts a message dated in the future as today, not as a lost one',
      () {
        expect(
          labelsOf(
            groupNotificationsByDay([
              message('a', DateTime(2024, 3, 20)),
            ], now: now),
          ),
          [NotificationGroup.today],
        );
      },
    );

    test('counts calendar days across a month and a year end', () {
      expect(
        labelsOf(
          groupNotificationsByDay([
            message('a', DateTime(2023, 12, 31)),
          ], now: DateTime(2024, 1, 1, 9)),
        ),
        [NotificationGroup.yesterday],
      );
      expect(
        labelsOf(
          groupNotificationsByDay([
            message('a', DateTime(2024, 2, 29)),
          ], now: DateTime(2024, 3, 1, 9)),
        ),
        [NotificationGroup.yesterday],
        reason: '2024 is a leap year',
      );
    });

    test('groups neighbours that share a heading, in the order they came', () {
      final groups = groupNotificationsByDay([
        message('t1', DateTime(2024, 3, 13)),
        message('t2', DateTime(2024, 3, 13)),
        message('y1', DateTime(2024, 3, 12)),
        message('o1', DateTime(2024, 3, 1)),
        message('o2', null),
      ], now: now);

      expect(labelsOf(groups), [
        NotificationGroup.today,
        NotificationGroup.yesterday,
        null,
      ]);
      expect(idsOf(groups), [
        ['t1', 't2'],
        ['y1'],
        ['o1', 'o2'],
      ]);
    });

    test('never reorders: a heading comes back if the list is not newest '
        'first', () {
      final groups = groupNotificationsByDay([
        message('o1', DateTime(2024, 3, 1)),
        message('t1', DateTime(2024, 3, 13)),
        message('o2', DateTime(2024, 3, 2)),
      ], now: now);

      expect(labelsOf(groups), [null, NotificationGroup.today, null]);
      // Flattened, the messages are exactly as they arrived.
      expect([for (final ids in idsOf(groups)) ...ids], ['o1', 't1', 'o2']);
    });

    test('does not touch the list it is given', () {
      final input = [
        message('a', DateTime(2024, 3, 13)),
        message('b', DateTime(2024, 3, 13)),
      ];
      groupNotificationsByDay(input, now: now);

      expect([for (final n in input) n.id], ['a', 'b']);
    });

    test('uses the real clock when none is given', () {
      final groups = groupNotificationsByDay([message('a', DateTime.now())]);

      expect(labelsOf(groups), [NotificationGroup.today]);
    });
  });

  test('NotificationGroup compares by label and messages', () {
    final a = message('a', null);

    expect(NotificationGroup('x', [a]), NotificationGroup('x', [a]));
    expect(NotificationGroup('x', [a]), isNot(NotificationGroup('y', [a])));
  });
}
