import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/text_formatter.dart';

/// The backend shouts many names in capitals ("GRATIS GANTI OLI"); these cases
/// pin down how they are tidied for display, and what must be left alone.
void main() {
  group('TextFormatter.fromUppercase', () {
    String fix(String text) => TextFormatter.fromUppercase(text);

    group('shouted words', () {
      test('keeps only the first letter of each word uppercase', () {
        expect(fix('GRATIS GANTI OLI'), 'Gratis Ganti Oli');
      });

      test('handles a single word', () {
        expect(fix('DISKON'), 'Diskon');
      });

      test('leaves a single capital letter as it is', () {
        expect(fix('PAKET A'), 'Paket A');
      });

      test('works after a hyphen, slash or bracket', () {
        expect(fix('OLI-MESIN'), 'Oli-Mesin');
        expect(fix('SERVIS/GANTI'), 'Servis/Ganti');
        expect(fix('(PAKET HEMAT)'), '(Paket Hemat)');
      });

      test('keeps an apostrophe inside its word', () {
        expect(fix("MOTOR'S OIL"), "Motor's Oil");
        expect(fix('MOTOR’S OIL'), 'Motor’s Oil');
      });

      test('works for letters beyond A-Z', () {
        expect(fix('ÉCOLE ÜBER'), 'École Über');
      });
    });

    group('what it leaves alone', () {
      test('a word that already mixes cases', () {
        expect(fix('Rp'), 'Rp');
        expect(fix('iPhone'), 'iPhone');
        expect(fix('Gratis Ganti Oli'), 'Gratis Ganti Oli');
      });

      test('lowercase text is not capitalised', () {
        expect(fix('gratis ganti oli'), 'gratis ganti oli');
      });

      test('digits and punctuation', () {
        expect(fix('20.000,00 - 100%'), '20.000,00 - 100%');
      });

      test('the empty string', () {
        expect(fix(''), '');
      });
    });

    group('mixed text, as the API really sends it', () {
      test('tidies the shouted words and keeps "Rp." and the amount', () {
        expect(
          fix('DISKON JASA SERVICE Rp. 20.000,00'),
          'Diskon Jasa Service Rp. 20.000,00',
        );
      });

      test('treats each word on its own', () {
        expect(fix('Diskon JASA service'), 'Diskon Jasa service');
      });

      test('keeps spacing and line breaks exactly', () {
        expect(fix('  GRATIS   GANTI\nOLI  '), '  Gratis   Ganti\nOli  ');
      });

      test('letters stuck to digits are still a word', () {
        expect(fix('ZONA2 KM20'), 'Zona2 Km20');
      });
    });

    test('applying it twice changes nothing more', () {
      const text = 'DISKON JASA SERVICE Rp. 20.000,00';
      expect(fix(fix(text)), fix(text));
    });
  });
}
