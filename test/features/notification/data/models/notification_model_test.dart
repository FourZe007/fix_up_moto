import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/data/models/notification_model.dart';

/// A real record from the NOTIFICATION response.
const tSample = <String, dynamic>{
  'MemberID': '0101202300000003',
  'NotificationID': '3101RSV23120023',
  'NotificationType': 'Service Booking Confirmed',
  'Notification':
      'Booking Service Anda Telah Dikonfirmasi.\r\n'
      'Demi pelayan yang maksimal, kami harap anda\r\n'
      'untuk datang 30 menit dari waktu yang ditentukan\r\n'
      '\r\n'
      'Terima Kasih',
  'SysDate': '2023-12-12',
  'IsSent': '1',
  'IsRead': '1',
  'Q': 0,
};

NotificationModel parse(Map<String, dynamic> overrides) =>
    NotificationModel.fromJson({...tSample, ...overrides});

void main() {
  group('fromJson', () {
    test('reads every field of a real record', () {
      final model = NotificationModel.fromJson(tSample);

      expect(model.notificationId, '3101RSV23120023');
      expect(model.notificationType, 'Service Booking Confirmed');
      expect(model.notification, startsWith('Booking Service Anda'));
      expect(model.sysDate, '2023-12-12');
      expect(model.isSent, isTrue);
      expect(model.isRead, isTrue);
    });

    test('ignores the keys it does not use (MemberID, Q)', () {
      expect(() => NotificationModel.fromJson(tSample), returnsNormally);
    });

    test('a missing text key is empty, not a crash', () {
      final model = NotificationModel.fromJson(const {'IsRead': '0'});

      expect(model.notificationId, '');
      expect(model.notificationType, '');
      expect(model.notification, '');
      expect(model.sysDate, '');
    });

    group('IsSent / IsRead flags', () {
      test('are true for the values the backend uses for yes', () {
        for (final yes in ['1', ' 1 ', 'true', 'TRUE', 1, 2, true]) {
          expect(parse({'IsRead': yes}).isRead, isTrue, reason: '$yes');
          expect(parse({'IsSent': yes}).isSent, isTrue, reason: '$yes');
        }
      });

      test('are false for no, empty, missing or unrecognised values', () {
        for (final no in ['0', '', ' ', 'false', 'abc', 0, false, null]) {
          expect(parse({'IsRead': no}).isRead, isFalse, reason: '$no');
          expect(parse({'IsSent': no}).isSent, isFalse, reason: '$no');
        }
      });

      test('are false when the key is absent', () {
        final model = NotificationModel.fromJson(const {});

        expect(model.isSent, isFalse);
        expect(model.isRead, isFalse);
      });
    });
  });

  group('toEntity', () {
    test('maps the fields, naming the type as the title', () {
      final entity = NotificationModel.fromJson(tSample).toEntity();

      expect(entity.id, '3101RSV23120023');
      expect(entity.type, 'Service Booking Confirmed');
      expect(entity.isSent, isTrue);
      expect(entity.isRead, isTrue);
    });

    test('turns the backend\'s \\r\\n into plain \\n and keeps the blank line', () {
      final entity = NotificationModel.fromJson(tSample).toEntity();

      expect(
        entity.message,
        'Booking Service Anda Telah Dikonfirmasi.\n'
        'Demi pelayan yang maksimal, kami harap anda\n'
        'untuk datang 30 menit dari waktu yang ditentukan\n'
        '\n'
        'Terima Kasih',
      );
      expect(entity.message, isNot(contains('\r')));
    });

    test('also fixes a lone \\r, and trims blank ends', () {
      final entity = parse({'Notification': '\r\n  one\rtwo  \r\n'}).toEntity();

      expect(entity.message, 'one\ntwo');
    });

    test('reads SysDate as that day', () {
      expect(
        NotificationModel.fromJson(tSample).toEntity().date,
        DateTime(2023, 12, 12),
      );
    });

    test('an empty or unreadable date is null, not a crash', () {
      expect(parse({'SysDate': ''}).toEntity().date, isNull);
      expect(parse({'SysDate': 'not a date'}).toEntity().date, isNull);
    });

    test('trims the type', () {
      expect(parse({'NotificationType': '  Promo  '}).toEntity().type, 'Promo');
    });
  });
}
