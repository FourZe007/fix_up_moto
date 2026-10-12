import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/constants/translation_constants.dart';

void main() {
  group('TranslationConstants.translate', () {
    test('translates the notification type from the backend', () {
      expect(
        TranslationConstants.translate('Service Booking Confirmed'),
        'Booking Service Terkonfirmasi',
      );
    });

    test('ignores case and surrounding whitespace', () {
      for (final text in [
        'service booking confirmed',
        'SERVICE BOOKING CONFIRMED',
        '  Service Booking Confirmed  ',
      ]) {
        expect(
          TranslationConstants.translate(text),
          'Booking Service Terkonfirmasi',
          reason: '"$text"',
        );
      }
    });

    test('translates the failure messages the app raises', () {
      expect(
        TranslationConstants.translate('No internet connection'),
        'Tidak ada koneksi internet',
      );
      expect(
        TranslationConstants.translate('Session expired. Please sign in again.'),
        'Sesi berakhir. Silakan masuk kembali',
      );
      expect(TranslationConstants.translate('Access denied'), 'Akses ditolak');
      expect(
        TranslationConstants.translate('Resource not found'),
        'Data tidak ditemukan',
      );
      expect(
        TranslationConstants.translate('No signed-in member found'),
        'Anggota belum masuk. Silakan masuk kembali',
      );
    });

    test('leaves a sentence with no entry exactly as it came', () {
      expect(TranslationConstants.translate('Service Reminder'), 'Service Reminder');
      expect(TranslationConstants.translate('Gagal memuat'), 'Gagal memuat');
      expect(TranslationConstants.translate(''), '');
    });

    test('every key is lowercase and trimmed, or it could never match', () {
      for (final key in TranslationConstants.translations.keys) {
        expect(key, key.trim().toLowerCase(), reason: '"$key"');
      }
    });

    test('no value is empty', () {
      for (final entry in TranslationConstants.translations.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });
  });
}
