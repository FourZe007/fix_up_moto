import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';

sealed class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

/// Initial state — data has never been loaded.
final class HomeInitial extends HomeState {
  const HomeInitial();
}

/// Dashboard stats are being fetched from the API.
final class HomeLoading extends HomeState {
  const HomeLoading();
}

/// Stats loaded successfully — render the dashboard cards.
final class HomeLoaded extends HomeState {
  final DashboardStatsEntity stats;
  const HomeLoaded(this.stats);

  @override
  List<Object> get props => [stats];
}

/// API call failed — show an error banner with a retry button.
final class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);

  @override
  List<Object> get props => [message];
}
