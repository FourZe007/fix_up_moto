import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/notification/presentation/models/notification_link.dart';

void main() {
  group('NotificationLink.tryParse', () {
    group('is null when there is nothing to open', () {
      for (final link in [
        '',
        '   ',
        '-',
        'fixupmoto.com/promo',
        'ftp://fixupmoto.com/file',
        'mailto:cs@fixupmoto.com',
        'not a link',
      ]) {
        test('for "$link"', () {
          expect(NotificationLink.tryParse(link), isNull);
        });
      }
    });

    group('knows a Google Form', () {
      for (final link in [
        'https://forms.gle/AbCdEf123',
        'https://docs.google.com/forms/d/e/1FAIpQLSabc/viewform',
        'https://docs.google.com/forms/d/e/1FAIpQLSabc/viewform?usp=sf_link',
        'https://docs.google.com/a/fixupmoto.com/forms/d/e/abc/viewform',
        'https://docs.google.com/forms/u/0/d/abc/edit',
        'https://forms.google.com/abc',
        'HTTPS://FORMS.GLE/AbCdEf123',
        '  https://forms.gle/AbCdEf123  ',
      ]) {
        test('for "$link"', () {
          expect(NotificationLink.tryParse(link)?.kind, LinkKind.googleForm);
        });
      }
    });

    group('calls anything else a plain page', () {
      for (final link in [
        'https://fixupmoto.com/promo',
        'http://fixupmoto.com',
        'https://docs.google.com/document/d/abc/edit',
        'https://drive.google.com/forms/abc',
        'https://notforms.gle/abc',
        'https://fixupmoto.com/?next=https://forms.gle/abc',
      ]) {
        test('for "$link"', () {
          expect(NotificationLink.tryParse(link)?.kind, LinkKind.other);
        });
      }
    });

    test('keeps the address, trimmed', () {
      final link = NotificationLink.tryParse('  https://forms.gle/AbCdEf123 ');

      expect(link?.uri, Uri.parse('https://forms.gle/AbCdEf123'));
    });
  });
}
