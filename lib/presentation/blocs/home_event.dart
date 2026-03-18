import 'package:equatable/equatable.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object> get props => [];
}

/// Dispatched when the home screen mounts or the user pulls to refresh.
final class HomeStatsRequested extends HomeEvent {
  const HomeStatsRequested();
}
