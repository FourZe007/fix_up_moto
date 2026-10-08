import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/membership/domain/entities/reward_entity.dart';
import 'package:fix_up_moto/features/membership/domain/repositories/rewards_repository.dart';

class GetRewardsUseCase extends NoParamsUseCase<List<RewardEntity>> {
  final RewardsRepository repository;
  GetRewardsUseCase(this.repository);

  @override
  Future<Either<Failure, List<RewardEntity>>> call() {
    return repository.getRewards();
  }
}
