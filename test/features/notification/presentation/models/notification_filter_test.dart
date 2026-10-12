import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/bloc/notification_event.dart';
import 'package:fix_up_moto/features/notification/presentation/models/notification_filter.dart';

void main() {
  group('FlagChoice.apiValue', () {
    test('only "yes" ticked is "1"', () {
      expect(const FlagChoice(yes: true, no: false).apiValue, '1');
    });

    test('only "no" ticked is "0"', () {
      expect(const FlagChoice(yes: false, no: true).apiValue, '0');
    });

    test('both ticked is no filter', () {
      expect(const FlagChoice(yes: true, no: true).apiValue, '');
      expect(FlagChoice.both.apiValue, '');
    });

    test('neither ticked is no filter too, not an empty result', () {
      expect(const FlagChoice(yes: false, no: false).apiValue, '');
    });

    test('copyWith changes one box and keeps the other', () {
      const choice = FlagChoice(yes: true, no: false);

      expect(choice.copyWith(no: true), FlagChoice.both);
      expect(choice.copyWith(yes: false), const FlagChoice(yes: false, no: false));
      expect(choice.copyWith(), choice);
    });
  });

  group('NotificationFilter', () {
    test('the defaults are the whole sent inbox: IsSent "1", IsRead ""', () {
      expect(NotificationFilter.defaults.isSent, '1');
      expect(NotificationFilter.defaults.isRead, '');
      expect(NotificationFilter.defaults.isDefault, isTrue);
    });

    test('the defaults match what the backend call and the event default to', () {
      // If these ever drift apart, opening the page and applying "defaults"
      // would ask for different things.
      const params = GetNotificationsParams();
      const event = NotificationsRequested();

      expect(NotificationFilter.defaults.isSent, params.isSent);
      expect(NotificationFilter.defaults.isRead, params.isRead);
      expect(NotificationFilter.defaults.isSent, event.isSent);
      expect(NotificationFilter.defaults.isRead, event.isRead);
    });

    test('each field maps to its own parameter', () {
      const filter = NotificationFilter(
        sent: FlagChoice(yes: false, no: true),
        read: FlagChoice(yes: true, no: false),
      );

      expect(filter.isSent, '0');
      expect(filter.isRead, '1');
      expect(filter.isDefault, isFalse);
    });

    test('copyWith changes one field and keeps the other', () {
      final unreadOnly = NotificationFilter.defaults.copyWith(
        read: const FlagChoice(yes: false, no: true),
      );

      expect(unreadOnly.isRead, '0');
      expect(unreadOnly.isSent, '1');
      expect(unreadOnly.isDefault, isFalse);
    });

    test('equal filters compare equal, so "back to defaults" is recognised', () {
      final changedAndBack = NotificationFilter.defaults
          .copyWith(read: const FlagChoice(yes: true, no: false))
          .copyWith(read: FlagChoice.both);

      expect(changedAndBack, NotificationFilter.defaults);
      expect(changedAndBack.isDefault, isTrue);
    });
  });
}
