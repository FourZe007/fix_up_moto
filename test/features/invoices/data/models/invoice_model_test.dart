import 'package:flutter_test/flutter_test.dart';

import 'package:fix_up_moto/features/invoices/data/models/invoice_model.dart';

void main() {
  // The record as the backend sends it (a service invoice with two lines).
  final json = <String, dynamic>{
    'Jenis': 'SERVICE',
    'BSName': 'FIXUP MOTO - KUTISARI',
    'TransNo': '3101SNT24090303',
    'TransDate': '2024-09-16',
    'VoucherNo': '',
    'VoucherName': '',
    'TQty': 0,
    'TPriceNett': 65000.0000,
    'TDiscNett': 0.0000,
    'TotalNett': 65000.0000,
    'Detail': [
      {
        'UnitID': 'S-REG-OTH',
        'ItemName': 'SERVICE LAIN-LAIN',
        'ItemNote': 'CHEMICAL CLEANING',
        'Qty': 0,
        'PriceNett': 5000.0000,
        'DiscNett': 0.0000,
      },
      {
        'UnitID': 'SRV-061',
        'ItemName': 'TUNE UP PAKET',
        'ItemNote': 'PERAWATAN BERKALA (PAKET SERVICE)',
        'Qty': 0,
        'PriceNett': 60000.0000,
        'DiscNett': 0.0000,
      },
    ],
  };

  test('reads the documented record', () {
    final model = InvoiceModel.fromJson(json);

    expect(model.workshopName, 'FIXUP MOTO - KUTISARI');
    expect(model.transNo, '3101SNT24090303');
    expect(model.transDate, '2024-09-16');
    expect(model.priceNett, 65000);
    expect(model.discNett, 0);
    expect(model.totalNett, 65000);
    expect(model.lines, hasLength(2));
    expect(model.lines.first.unitId, 'S-REG-OTH');
    expect(model.lines.last.itemName, 'TUNE UP PAKET');
    expect(model.lines.last.itemNote, 'PERAWATAN BERKALA (PAKET SERVICE)');
    expect(model.lines.last.priceNett, 60000);
  });

  test('converts to an entity with a real date and its lines', () {
    final entity = InvoiceModel.fromJson(json).toEntity();

    expect(entity.number, '3101SNT24090303');
    expect(entity.workshopName, 'FIXUP MOTO - KUTISARI');
    expect(entity.date, DateTime(2024, 9, 16));
    expect(entity.subtotal, 65000);
    expect(entity.discount, 0);
    expect(entity.total, 65000);
    expect(entity.hasVoucher, isFalse);
    expect(entity.lines.map((l) => l.code), ['S-REG-OTH', 'SRV-061']);
    expect(entity.lines.last.quantity, 0);
    expect(entity.lines.last.price, 60000);
  });

  test('keeps a voucher, a discount and a part quantity', () {
    final entity = InvoiceModel.fromJson({
      ...json,
      'VoucherNo': 'V-001',
      'VoucherName': 'DISKON OLI',
      'TDiscNett': 10000,
      'TotalNett': 55000,
      'Detail': [
        {
          'UnitID': 'P-1',
          'ItemName': 'BUSI',
          'ItemNote': '',
          'Qty': 2.0,
          'PriceNett': 30000,
          'DiscNett': 5000,
        },
      ],
    }).toEntity();

    expect(entity.hasVoucher, isTrue);
    expect(entity.voucherName, 'DISKON OLI');
    expect(entity.voucherNo, 'V-001');
    expect(entity.discount, 10000);
    expect(entity.total, 55000);
    expect(entity.lines.single.quantity, 2);
    expect(entity.lines.single.discount, 5000);
  });

  test('reads amounts and counts the backend sends as strings', () {
    final model = InvoiceModel.fromJson({
      ...json,
      'TPriceNett': '65000.0000',
      'TotalNett': ' 65000 ',
      'Detail': [
        {'Qty': '3', 'PriceNett': '1500.5'},
      ],
    });

    expect(model.priceNett, 65000);
    expect(model.totalNett, 65000);
    expect(model.lines.single.qty, 3);
    expect(model.lines.single.priceNett, 1500.5);
  });

  test('a record with nothing in it still parses, as empty and zero', () {
    final entity = InvoiceModel.fromJson(<String, dynamic>{}).toEntity();

    expect(entity.number, '');
    expect(entity.workshopName, '');
    expect(entity.date, isNull);
    expect(entity.total, 0);
    expect(entity.lines, isEmpty);
  });

  test('a Detail that is not a list is no lines', () {
    expect(InvoiceModel.fromJson({...json, 'Detail': null}).lines, isEmpty);
    expect(InvoiceModel.fromJson({...json, 'Detail': 'x'}).lines, isEmpty);
  });

  test('an unreadable date is no date, not an error', () {
    final entity = InvoiceModel.fromJson({
      ...json,
      'TransDate': 'not a date',
    }).toEntity();

    expect(entity.date, isNull);
  });
}
