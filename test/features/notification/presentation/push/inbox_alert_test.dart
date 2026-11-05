import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/presentation/push/inbox_alert.dart';

import '../../../../support/inbox_stand_ins.dart';

void main() {
  group('InboxAlert.of', () {
    test('is empty for no messages', () {
      expect(InboxAlert.of(const []), isEmpty);
    });

    test('titles a message by its type, as the inbox does', () {
      final alerts = InboxAlert.of([
        inboxMessage(
          'N1',
          type: 'Service Booking Confirmed',
          message: 'Booking Anda sudah dikonfirmasi.',
        ),
      ]);

      expect(alerts, [
        const InboxAlert(
          key: 'N1',
          title: 'Service Booking Confirmed',
          body: 'Booking Anda sudah dikonfirmasi.',
        ),
      ]);
    });

    test('gives up to three messages one alert each', () {
      final alerts = InboxAlert.of([
        inboxMessage('N1'),
        inboxMessage('N2'),
        inboxMessage('N3'),
      ]);

      expect(alerts.map((a) => a.key), ['N1', 'N2', 'N3']);
    });

    test('folds more than three into one summary', () {
      final alerts = InboxAlert.of([
        for (var i = 1; i <= 4; i++) inboxMessage('N$i'),
      ]);

      expect(alerts, hasLength(1));
      expect(alerts.single.title, '4 notifikasi baru');
      expect(alerts.single.body, contains('Kotak Masuk'));
    });

    test('never leaves a title or body empty', () {
      final alerts = InboxAlert.of([
        inboxMessage('N1', type: ' ', message: ''),
      ]);

      expect(alerts.single.title, 'Notifikasi baru');
      expect(alerts.single.body, 'Notifikasi baru');
    });

    test('trims stray whitespace', () {
      final alerts = InboxAlert.of([
        inboxMessage('N1', type: ' Poin ', message: ' Halo\n'),
      ]);

      expect(alerts.single.title, 'Poin');
      expect(alerts.single.body, 'Halo');
    });
  });

  group('InboxAlert.single (the banner, which shows one thing at a time)', () {
    test('is the message itself when there is one', () {
      final alert = InboxAlert.single([inboxMessage('N1', type: 'Poin')]);

      expect(alert.title, 'Poin');
    });

    test('is the summary when there are two or more', () {
      final alert = InboxAlert.single([inboxMessage('N1'), inboxMessage('N2')]);

      expect(alert.title, '2 notifikasi baru');
    });
  });
}
