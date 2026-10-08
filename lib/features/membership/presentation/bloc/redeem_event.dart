import 'package:equatable/equatable.dart';

sealed class RedeemEvent extends Equatable {
  const RedeemEvent();
  @override
  List<Object> get props => [];
}

/// The member confirmed spending points on a voucher.
final class RedeemRequested extends RedeemEvent {
  /// Which voucher to claim (`RewardEntity.pointId`).
  final String pointId;

  /// Its display name, carried through only so the success message can name it.
  final String voucherName;

  const RedeemRequested({required this.pointId, required this.voucherName});

  @override
  List<Object> get props => [pointId, voucherName];
}
