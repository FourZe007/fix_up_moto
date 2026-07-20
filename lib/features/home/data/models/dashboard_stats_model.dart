import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';

part 'dashboard_stats_model.g.dart';

/// JSON model for the membership dashboard API response.
@JsonSerializable()
class DashboardStatsModel {
  @JsonKey(name: 'Status')
  final String status;

  @JsonKey(name: 'MemberID')
  final String memberId;

  @JsonKey(name: 'MemberName')
  final String memberName;

  @JsonKey(name: 'EmailAddress')
  final String emailAddress;

  @JsonKey(name: 'PhoneNo')
  final String phoneNo;

  @JsonKey(name: 'Active')
  final bool active;

  @JsonKey(name: 'Qty')
  final int qty;

  @JsonKey(name: 'Point')
  final int point;

  @JsonKey(name: 'Detail')
  final List<PointDetailModel> detail;

  @JsonKey(name: 'Detail2')
  final List<VoucherDetailModel> detail2;

  const DashboardStatsModel({
    required this.status,
    required this.memberId,
    required this.memberName,
    required this.emailAddress,
    required this.phoneNo,
    required this.active,
    required this.qty,
    required this.point,
    required this.detail,
    required this.detail2,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsModelFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardStatsModelToJson(this);

  /// Converts to the Domain entity returned to callers.
  DashboardStatsEntity toEntity() => DashboardStatsEntity(
        status: status,
        memberId: memberId,
        memberName: memberName,
        emailAddress: emailAddress,
        phoneNo: phoneNo,
        active: active,
        qty: qty,
        point: point,
        detail: detail.map((e) => e.toEntity()).toList(),
        detail2: detail2.map((e) => e.toEntity()).toList(),
      );
}

/// A single point-earning history entry from the `Detail` list.
@JsonSerializable()
class PointDetailModel {
  @JsonKey(name: 'TransDate')
  final String transDate;

  @JsonKey(name: 'PointID')
  final String pointId;

  @JsonKey(name: 'PointName')
  final String pointName;

  @JsonKey(name: 'PointQty')
  final int pointQty;

  const PointDetailModel({
    required this.transDate,
    required this.pointId,
    required this.pointName,
    required this.pointQty,
  });

  factory PointDetailModel.fromJson(Map<String, dynamic> json) =>
      _$PointDetailModelFromJson(json);

  Map<String, dynamic> toJson() => _$PointDetailModelToJson(this);

  PointDetailEntity toEntity() => PointDetailEntity(
        transDate: transDate,
        pointId: pointId,
        pointName: pointName,
        pointQty: pointQty,
      );
}

/// A single voucher entry from the `Detail2` list.
@JsonSerializable()
class VoucherDetailModel {
  @JsonKey(name: 'RedeemDate')
  final String redeemDate;

  @JsonKey(name: 'ExpirationDate')
  final String expirationDate;

  @JsonKey(name: 'VoucherNo')
  final String voucherNo;

  @JsonKey(name: 'StatusVoucher')
  final int statusVoucher;

  @JsonKey(name: 'VoucherID')
  final String voucherId;

  @JsonKey(name: 'VoucherName')
  final String voucherName;

  @JsonKey(name: 'StatusVoucherMemo')
  final String statusVoucherMemo;

  @JsonKey(name: 'VoucherAmount')
  final double voucherAmount;

  const VoucherDetailModel({
    required this.redeemDate,
    required this.expirationDate,
    required this.voucherNo,
    required this.statusVoucher,
    required this.voucherId,
    required this.voucherName,
    required this.statusVoucherMemo,
    required this.voucherAmount,
  });

  factory VoucherDetailModel.fromJson(Map<String, dynamic> json) =>
      _$VoucherDetailModelFromJson(json);

  Map<String, dynamic> toJson() => _$VoucherDetailModelToJson(this);

  VoucherDetailEntity toEntity() => VoucherDetailEntity(
        redeemDate: redeemDate,
        expirationDate: expirationDate,
        voucherNo: voucherNo,
        statusVoucher: statusVoucher,
        voucherId: voucherId,
        voucherName: voucherName,
        statusVoucherMemo: statusVoucherMemo,
        voucherAmount: voucherAmount,
      );
}
