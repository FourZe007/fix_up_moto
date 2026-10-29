import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';

part 'invoice_model.g.dart';

/// JSON model for one record from `BrowseTrans` (`Jenis: "INVOICEBYMEMBER"`):
///
/// ```json
/// { "Jenis": "SERVICE", "BSName": "FIXUP MOTO - KUTISARI",
///   "TransNo": "3101SNT24090303", "TransDate": "2024-09-16",
///   "VoucherNo": "", "VoucherName": "", "TQty": 0,
///   "TPriceNett": 65000.0000, "TDiscNett": 0.0000, "TotalNett": 65000.0000,
///   "Detail": [ { "UnitID": "SRV-061", "ItemName": "TUNE UP PAKET",
///                 "ItemNote": "PERAWATAN BERKALA (PAKET SERVICE)", "Qty": 0,
///                 "PriceNett": 60000.0000, "DiscNett": 0.0000 } ] }
/// ```
///
/// `Jenis` (the page already knows which kind it asked for) and `TQty` are not
/// read. Text fields default to empty and numbers to 0 rather than failing the
/// whole list over one record with a missing key.
@JsonSerializable(createToJson: false)
class InvoiceModel {
  @JsonKey(name: 'BSName', defaultValue: '')
  final String workshopName;

  @JsonKey(name: 'TransNo', defaultValue: '')
  final String transNo;

  @JsonKey(name: 'TransDate', defaultValue: '')
  final String transDate;

  @JsonKey(name: 'VoucherNo', defaultValue: '')
  final String voucherNo;

  @JsonKey(name: 'VoucherName', defaultValue: '')
  final String voucherName;

  @JsonKey(name: 'TPriceNett', fromJson: _doubleFromJson)
  final double priceNett;

  @JsonKey(name: 'TDiscNett', fromJson: _doubleFromJson)
  final double discNett;

  @JsonKey(name: 'TotalNett', fromJson: _doubleFromJson)
  final double totalNett;

  @JsonKey(name: 'Detail', fromJson: _linesFromJson)
  final List<InvoiceLineModel> lines;

  const InvoiceModel({
    required this.workshopName,
    required this.transNo,
    required this.transDate,
    required this.voucherNo,
    required this.voucherName,
    required this.priceNett,
    required this.discNett,
    required this.totalNett,
    required this.lines,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) =>
      _$InvoiceModelFromJson(json);

  /// Converts to the Domain entity returned to callers.
  InvoiceEntity toEntity() => InvoiceEntity(
    number: transNo.trim(),
    workshopName: workshopName.trim(),
    // `TransDate` is a plain `yyyy-MM-dd`; anything unreadable becomes null
    // (shown as no date) instead of throwing.
    date: DateTime.tryParse(transDate),
    voucherNo: voucherNo.trim(),
    voucherName: voucherName.trim(),
    subtotal: priceNett,
    discount: discNett,
    total: totalNett,
    lines: lines.map((line) => line.toEntity()).toList(),
  );
}

/// One entry of an invoice's `Detail` array.
@JsonSerializable(createToJson: false)
class InvoiceLineModel {
  @JsonKey(name: 'UnitID', defaultValue: '')
  final String unitId;

  @JsonKey(name: 'ItemName', defaultValue: '')
  final String itemName;

  @JsonKey(name: 'ItemNote', defaultValue: '')
  final String itemNote;

  @JsonKey(name: 'Qty', fromJson: _intFromJson)
  final int qty;

  @JsonKey(name: 'PriceNett', fromJson: _doubleFromJson)
  final double priceNett;

  @JsonKey(name: 'DiscNett', fromJson: _doubleFromJson)
  final double discNett;

  const InvoiceLineModel({
    required this.unitId,
    required this.itemName,
    required this.itemNote,
    required this.qty,
    required this.priceNett,
    required this.discNett,
  });

  factory InvoiceLineModel.fromJson(Map<String, dynamic> json) =>
      _$InvoiceLineModelFromJson(json);

  InvoiceLineEntity toEntity() => InvoiceLineEntity(
    code: unitId.trim(),
    name: itemName.trim(),
    note: itemNote.trim(),
    quantity: qty,
    price: priceNett,
    discount: discNett,
  );
}

// ── Converter helpers ──────────────────────────────────────────────────────

/// Reads an amount whether the backend sends it as a number (`65000.0000`) or
/// a string (`"65000.0000"`). Anything else, including a missing value, is 0.
double _doubleFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

/// Reads a count whether the backend sends it as a number (`2`, `2.0`) or a
/// string (`"2"`). Anything else, including a missing value, is 0.
int _intFromJson(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return double.tryParse(value.trim())?.toInt() ?? 0;
  return 0;
}

/// An invoice's lines, or none when `Detail` is missing or not a list.
List<InvoiceLineModel> _linesFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => InvoiceLineModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
