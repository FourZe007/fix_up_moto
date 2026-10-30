import 'package:equatable/equatable.dart';

/// The two kinds of invoice the backend keeps — Invoice Servis and Invoice
/// Sparepart. [wireValue] is what its `Kode` field expects, [transId] what the
/// receipt endpoint's `TransID` does.
enum InvoiceType {
  service('SERVICE', 'SNT'),
  sparepart('SPAREPART', 'PNT');

  /// The exact string `BrowseTrans` expects in `Kode`.
  final String wireValue;

  /// The `TransID` of this kind's receipt: `SNT` for a service, `PNT` for a
  /// sparepart (also the middle of its invoice numbers, e.g. "3101SNT26100001").
  final String transId;

  const InvoiceType(this.wireValue, this.transId);
}

/// One line of an invoice: a service done or a part sold.
class InvoiceLineEntity extends Equatable {
  /// The item's code, e.g. "SRV-061".
  final String code;

  /// What it is, e.g. "TUNE UP PAKET" (the backend shouts its names).
  final String name;

  /// A further description, e.g. "PERAWATAN BERKALA (PAKET SERVICE)". May be
  /// empty.
  final String note;

  /// How many. The backend sends 0 on a service line, where a count means
  /// nothing.
  final int quantity;

  /// The line's price before its own discount (see [discount]).
  final double price;

  /// What was taken off this line. 0 when nothing was.
  final double discount;

  const InvoiceLineEntity({
    required this.code,
    required this.name,
    required this.note,
    required this.quantity,
    required this.price,
    required this.discount,
  });

  @override
  List<Object> get props => [code, name, note, quantity, price, discount];
}

/// One invoice from `BrowseTrans` (`Jenis: "INVOICEBYMEMBER"`).
class InvoiceEntity extends Equatable {
  /// The invoice number, e.g. "3101SNT24090303".
  final String number;

  /// The branch it was issued by, e.g. "FIXUP MOTO - KUTISARI".
  final String workshopName;

  /// The day it was issued; null if the backend sent no readable date.
  final DateTime? date;

  /// The voucher used on it. Both empty when none was.
  final String voucherNo;
  final String voucherName;

  /// The price of everything before discount.
  final double subtotal;

  /// The discount on the whole invoice. 0 when none.
  final double discount;

  /// What was paid.
  final double total;

  final List<InvoiceLineEntity> lines;

  const InvoiceEntity({
    required this.number,
    required this.workshopName,
    required this.date,
    required this.voucherNo,
    required this.voucherName,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.lines,
  });

  /// Whether a voucher was used.
  bool get hasVoucher => voucherName.isNotEmpty || voucherNo.isNotEmpty;

  @override
  List<Object?> get props => [
    number,
    workshopName,
    date,
    voucherNo,
    voucherName,
    subtotal,
    discount,
    total,
    lines,
  ];
}
