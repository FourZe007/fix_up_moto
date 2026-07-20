// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_stats_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardStatsModel _$DashboardStatsModelFromJson(Map<String, dynamic> json) =>
    DashboardStatsModel(
      status: json['Status'] as String,
      memberId: json['MemberID'] as String,
      memberName: json['MemberName'] as String,
      emailAddress: json['EmailAddress'] as String,
      phoneNo: json['PhoneNo'] as String,
      active: json['Active'] as bool,
      qty: json['Qty'] as int,
      point: json['Point'] as int,
      detail: (json['Detail'] as List<dynamic>)
          .map((e) => PointDetailModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      detail2: (json['Detail2'] as List<dynamic>)
          .map((e) => VoucherDetailModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DashboardStatsModelToJson(
  DashboardStatsModel instance,
) => <String, dynamic>{
  'Status': instance.status,
  'MemberID': instance.memberId,
  'MemberName': instance.memberName,
  'EmailAddress': instance.emailAddress,
  'PhoneNo': instance.phoneNo,
  'Active': instance.active,
  'Qty': instance.qty,
  'Point': instance.point,
  'Detail': instance.detail,
  'Detail2': instance.detail2,
};

PointDetailModel _$PointDetailModelFromJson(Map<String, dynamic> json) =>
    PointDetailModel(
      transDate: json['TransDate'] as String,
      pointId: json['PointID'] as String,
      pointName: json['PointName'] as String,
      pointQty: json['PointQty'] as int,
    );

Map<String, dynamic> _$PointDetailModelToJson(PointDetailModel instance) =>
    <String, dynamic>{
      'TransDate': instance.transDate,
      'PointID': instance.pointId,
      'PointName': instance.pointName,
      'PointQty': instance.pointQty,
    };

VoucherDetailModel _$VoucherDetailModelFromJson(Map<String, dynamic> json) =>
    VoucherDetailModel(
      redeemDate: json['RedeemDate'] as String,
      expirationDate: json['ExpirationDate'] as String,
      voucherNo: json['VoucherNo'] as String,
      statusVoucher: json['StatusVoucher'] as int,
      voucherId: json['VoucherID'] as String,
      voucherName: json['VoucherName'] as String,
      statusVoucherMemo: json['StatusVoucherMemo'] as String,
      voucherAmount: json['VoucherAmount'] as double,
    );

Map<String, dynamic> _$VoucherDetailModelToJson(VoucherDetailModel instance) =>
    <String, dynamic>{
      'RedeemDate': instance.redeemDate,
      'ExpirationDate': instance.expirationDate,
      'VoucherNo': instance.voucherNo,
      'StatusVoucher': instance.statusVoucher,
      'VoucherID': instance.voucherId,
      'VoucherName': instance.voucherName,
      'StatusVoucherMemo': instance.statusVoucherMemo,
      'VoucherAmount': instance.voucherAmount,
    };
