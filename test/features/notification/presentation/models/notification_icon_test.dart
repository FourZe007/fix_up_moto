import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/presentation/models/notification_icon.dart';

void main() {
  group('notificationIconOf', () {
    test('a booking gets the calendar, even though its type also says '
        'Service', () {
      expect(
        notificationIconOf('Service Booking Confirmed'),
        Icons.calendar_month_outlined,
      );
    });

    test('points get the gift card, as on the Welcome carousel', () {
      expect(notificationIconOf('Point Earned'), Icons.card_giftcard_outlined);
    });

    test('a reminder or any other service gets the wrench', () {
      expect(notificationIconOf('Service Reminder'), Icons.build_outlined);
      expect(notificationIconOf('Service Completed'), Icons.build_outlined);
      expect(notificationIconOf('Reminder'), Icons.build_outlined);
    });

    test('ignores the case', () {
      expect(
        notificationIconOf('SERVICE BOOKING CONFIRMED'),
        Icons.calendar_month_outlined,
      );
      expect(notificationIconOf('point earned'), Icons.card_giftcard_outlined);
    });

    test('a type it does not know gets a bell, as does a blank one', () {
      for (final type in ['Promo', 'Voucher Expiring', '', '   ']) {
        expect(
          notificationIconOf(type),
          Icons.notifications_outlined,
          reason: '"$type"',
        );
      }
    });
  });
}
