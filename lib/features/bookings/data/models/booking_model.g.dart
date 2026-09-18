// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) => BookingModel(
  bookingId: json['BookingID'] as String,
  bsName: json['BSName'] as String,
  bsAddress: json['BSAddress'] as String,
  bookDate: json['BookDate'] as String,
  bookTime: json['BookTime'] as String,
  plateNo: json['UPlateNo'] as String,
  unitId: json['UnitID'] as String,
  status: json['Status'] as String,
  notes: json['Notes'] as String?,
);

Map<String, dynamic> _$BookingModelToJson(BookingModel instance) =>
    <String, dynamic>{
      'BookingID': instance.bookingId,
      'BSName': instance.bsName,
      'BSAddress': instance.bsAddress,
      'BookDate': instance.bookDate,
      'BookTime': instance.bookTime,
      'UPlateNo': instance.plateNo,
      'UnitID': instance.unitId,
      'Status': instance.status,
      'Notes': instance.notes,
    };
