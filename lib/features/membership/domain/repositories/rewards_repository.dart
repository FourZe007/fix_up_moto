import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';

abstract class RewardsRepository {
  Future<Either<Failure, List<RewardEntity>>> getRewards();

  /// Spends the signed-in member's points on the voucher [pointId]. Returns the
  /// server's own confirmation text on success.
  Future<Either<Failure, String>> redeemReward({required String pointId});
}
