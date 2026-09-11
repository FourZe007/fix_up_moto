import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';

abstract class FeedsRepository {
  /// Returns the Instagram feed, newest first (as the proxy returns it).
  Future<Either<Failure, List<FeedEntity>>> getFeeds();
}
