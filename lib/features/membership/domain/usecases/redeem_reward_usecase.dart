import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/membership/domain/repositories/rewards_repository.dart';

/// Spends the member's points on one voucher; returns the server's confirmation
/// text.
class RedeemRewardUseCase extends UseCase<String, RedeemRewardParams> {
  final RewardsRepository repository;
  RedeemRewardUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(RedeemRewardParams params) {
    return repository.redeemReward(pointId: params.pointId);
  }
}

class RedeemRewardParams extends Equatable {
  /// The voucher to claim (`RewardEntity.pointId`).
  final String pointId;

  const RedeemRewardParams({required this.pointId});

  @override
  List<Object> get props => [pointId];
}
