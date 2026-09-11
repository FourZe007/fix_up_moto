import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';
import 'package:fix_up_moto/features/feeds/domain/repositories/feeds_repository.dart';

class GetFeedsUseCase extends NoParamsUseCase<List<FeedEntity>> {
  final FeedsRepository repository;
  GetFeedsUseCase(this.repository);

  @override
  Future<Either<Failure, List<FeedEntity>>> call() {
    return repository.getFeeds();
  }
}
