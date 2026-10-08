import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';

sealed class RewardsState extends Equatable {
  const RewardsState();
  @override
  List<Object?> get props => [];
}

/// Nothing requested yet — the Voucher tab has not been shown.
final class RewardsInitial extends RewardsState {
  const RewardsInitial();
}

final class RewardsLoading extends RewardsState {
  const RewardsLoading();
}

final class RewardsLoaded extends RewardsState {
  final List<RewardEntity> rewards;
  const RewardsLoaded(this.rewards);

  @override
  List<Object> get props => [rewards];
}

final class RewardsError extends RewardsState {
  final String message;
  const RewardsError(this.message);

  @override
  List<Object> get props => [message];
}
