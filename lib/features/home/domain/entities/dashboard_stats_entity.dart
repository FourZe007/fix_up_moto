import 'package:equatable/equatable.dart';

/// Membership record shown on the home dashboard.
/// Fetched from the Yamaha SAMP BrowseTrans endpoint.
class DashboardStatsEntity extends Equatable {
  /// Membership status, e.g. "AKTIF".
  final String status;

  /// Unique member identifier.
  final String memberId;

  /// Member's display name.
  final String memberName;

  /// Member's email address (may be empty).
  final String emailAddress;

  /// Member's phone number.
  final String phoneNo;

  /// Whether the membership is currently active.
  final bool active;

  /// Quantity metric returned by the endpoint (e.g. registered units).
  final int qty;

  /// Total loyalty points the member has accumulated.
  final int point;

  /// Point-earning history entries.
  final List<PointDetailEntity> detail;

  /// Redeemed / available vouchers.
  final List<VoucherDetailEntity> detail2;

  const DashboardStatsEntity({
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

  @override
  List<Object> get props => [
        status,
        memberId,
        memberName,
        emailAddress,
        phoneNo,
        active,
        qty,
        point,
        detail,
        detail2,
      ];
}

/// A single point-earning history entry (`Detail[]`).
class PointDetailEntity extends Equatable {
  /// Date the points were earned.
  final String transDate;

  /// Point rule identifier, e.g. "A01".
  final String pointId;

  /// Human-readable point rule name.
  final String pointName;

  /// Number of points earned in this transaction.
  final int pointQty;

  const PointDetailEntity({
    required this.transDate,
    required this.pointId,
    required this.pointName,
    required this.pointQty,
  });

  @override
  List<Object> get props => [transDate, pointId, pointName, pointQty];
}

/// A single voucher entry (`Detail2[]`).
class VoucherDetailEntity extends Equatable {
  /// Date the voucher was redeemed.
  final String redeemDate;

  /// Date the voucher expires.
  final String expirationDate;

  /// Unique voucher serial number.
  final String voucherNo;

  /// Numeric voucher status code.
  final int statusVoucher;

  /// Voucher rule identifier, e.g. "B01".
  final String voucherId;

  /// Human-readable voucher name.
  final String voucherName;

  /// Human-readable voucher status, e.g. "KADALUARSA".
  final String statusVoucherMemo;

  /// Monetary value of the voucher.
  final double voucherAmount;

  const VoucherDetailEntity({
    required this.redeemDate,
    required this.expirationDate,
    required this.voucherNo,
    required this.statusVoucher,
    required this.voucherId,
    required this.voucherName,
    required this.statusVoucherMemo,
    required this.voucherAmount,
  });

  @override
  List<Object> get props => [
        redeemDate,
        expirationDate,
        voucherNo,
        statusVoucher,
        voucherId,
        voucherName,
        statusVoucherMemo,
        voucherAmount,
      ];
}
