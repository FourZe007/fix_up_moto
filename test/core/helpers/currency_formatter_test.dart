import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/core/helpers/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.rupiah', () {
    test('writes Rp, a space and dots between the thousands', () {
      expect(CurrencyFormatter.rupiah(65000), 'Rp 65.000');
      expect(CurrencyFormatter.rupiah(1250000), 'Rp 1.250.000');
      expect(CurrencyFormatter.rupiah(500), 'Rp 500');
      expect(CurrencyFormatter.rupiah(0), 'Rp 0');
    });

    test('reads the backend\'s four-decimal amounts as whole rupiah', () {
      expect(CurrencyFormatter.rupiah(65000.0000), 'Rp 65.000');
    });

    test('rounds a fraction away', () {
      expect(CurrencyFormatter.rupiah(1999.6), 'Rp 2.000');
    });

    test('puts the minus before the Rp', () {
      expect(CurrencyFormatter.rupiah(-5000), '-Rp 5.000');
    });
  });
}
