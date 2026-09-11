import 'package:equatable/equatable.dart';

sealed class FeedsEvent extends Equatable {
  const FeedsEvent();
  @override
  List<Object> get props => [];
}

/// Dispatched when the Feeds tab mounts or the user pulls to refresh.
final class FeedsRequested extends FeedsEvent {
  const FeedsRequested();
}
