// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvoiceModel _$InvoiceModelFromJson(Map<String, dynamic> json) => InvoiceModel(
  workshopName: json['BSName'] as String? ?? '',
  transNo: json['TransNo'] as String? ?? '',
  transDate: json['TransDate'] as String? ?? '',
  voucherNo: json['VoucherNo'] as String? ?? '',
  voucherName: json['VoucherName'] as String? ?? '',
  priceNett: _doubleFromJson(json['TPriceNett']),
  discNett: _doubleFromJson(json['TDiscNett']),
  totalNett: _doubleFromJson(json['TotalNett']),
  lines: _linesFromJson(json['Detail']),
);

InvoiceLineModel _$InvoiceLineModelFromJson(Map<String, dynamic> json) =>
    InvoiceLineModel(
      unitId: json['UnitID'] as String? ?? '',
      itemName: json['ItemName'] as String? ?? '',
      itemNote: json['ItemNote'] as String? ?? '',
      qty: _intFromJson(json['Qty']),
      priceNett: _doubleFromJson(json['PriceNett']),
      discNett: _doubleFromJson(json['DiscNett']),
    );
