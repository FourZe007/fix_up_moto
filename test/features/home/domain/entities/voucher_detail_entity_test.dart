import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';

VoucherDetailEntity voucher({
  String expirationDate = '2026-11-20',
  String memo = 'AKTIF',
}) => VoucherDetailEntity(
  redeemDate: '2026-11-01',
  expirationDate: expirationDate,
  voucherNo: 'V-1',
  statusVoucher: 1,
  voucherId: 'B01',
  voucherName: 'FREE OIL CHANGE',
  statusVoucherMemo: memo,
  voucherAmount: 50000,
);

void main() {
  group('VoucherDetailEntity.isExpiredOn', () {
    // Mid-afternoon, so the time of day can never be what decides it.
    final today = DateTime(2026, 11, 11, 15, 30);

    test('a future expiry date is not expired', () {
      expect(voucher(expirationDate: '2026-11-20').isExpiredOn(today), isFalse);
    });

    test('an expiry date before today is expired', () {
      expect(voucher(expirationDate: '2026-11-10').isExpiredOn(today), isTrue);
    });

    test('expiring today is still good today', () {
      expect(voucher(expirationDate: '2026-11-11').isExpiredOn(today), isFalse);
    });

    test('a time of day on the expiry date does not change that', () {
      expect(
        voucher(expirationDate: '2026-11-11T00:00:00').isExpiredOn(today),
        isFalse,
      );
      expect(
        voucher(expirationDate: '2026-11-10T23:59:59').isExpiredOn(today),
        isTrue,
      );
    });

    test('the server saying KADALUARSA is expired, whatever the date', () {
      expect(
        voucher(
          expirationDate: '2027-01-01',
          memo: 'KADALUARSA',
        ).isExpiredOn(today),
        isTrue,
      );
    });

    test('the status text is matched without regard to case or spaces', () {
      expect(voucher(memo: ' kadaluarsa ').isExpiredOn(today), isTrue);
    });

    test('a date that cannot be read cannot be ruled out, so it is not '
        'expired', () {
      expect(voucher(expirationDate: 'next week').isExpiredOn(today), isFalse);
      expect(voucher(expirationDate: '').isExpiredOn(today), isFalse);
    });

    test('other status text is not guessed at', () {
      // Which other codes mean "used" is not confirmed yet, so none of them is
      // treated as expired.
      expect(voucher(memo: 'TERPAKAI').isExpiredOn(today), isFalse);
      expect(voucher(memo: '').isExpiredOn(today), isFalse);
    });
  });
}
