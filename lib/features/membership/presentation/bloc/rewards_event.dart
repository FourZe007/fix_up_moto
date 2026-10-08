import 'package:equatable/equatable.dart';

sealed class RewardsEvent extends Equatable {
  const RewardsEvent();
  @override
  List<Object> get props => [];
}

/// Dispatched the first time the Voucher tab is shown, and again on Retry or
/// pull-to-refresh.
final class RewardsRequested extends RewardsEvent {
  const RewardsRequested();
}
