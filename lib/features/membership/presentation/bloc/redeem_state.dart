import 'package:equatable/equatable.dart';

sealed class RedeemState extends Equatable {
  const RedeemState();
  @override
  List<Object?> get props => [];
}

/// Nothing claimed yet.
final class RedeemInitial extends RedeemState {
  const RedeemInitial();
}

/// A claim is on its way to the server. While this holds, every Klaim button is
/// off, so a second tap cannot spend the points twice.
final class RedeemInProgress extends RedeemState {
  /// The voucher being claimed — the one whose button shows the spinner.
  final String pointId;
  const RedeemInProgress(this.pointId);

  @override
  List<Object> get props => [pointId];
}

final class RedeemSuccess extends RedeemState {
  /// The voucher that was claimed.
  final String voucherName;

  /// The server's own confirmation text.
  final String message;

  const RedeemSuccess({required this.voucherName, required this.message});

  @override
  List<Object> get props => [voucherName, message];
}

final class RedeemFailure extends RedeemState {
  final String message;
  const RedeemFailure(this.message);

  @override
  List<Object> get props => [message];
}
