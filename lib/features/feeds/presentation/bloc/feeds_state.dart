import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/feeds/domain/entities/feed_entity.dart';

sealed class FeedsState extends Equatable {
  const FeedsState();
  @override
  List<Object?> get props => [];
}

final class FeedsInitial extends FeedsState {
  const FeedsInitial();
}

final class FeedsLoading extends FeedsState {
  const FeedsLoading();
}

final class FeedsLoaded extends FeedsState {
  final List<FeedEntity> posts;
  const FeedsLoaded(this.posts);

  @override
  List<Object> get props => [posts];
}

final class FeedsError extends FeedsState {
  final String message;
  const FeedsError(this.message);

  @override
  List<Object> get props => [message];
}
