import 'package:equatable/equatable.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object> get props => [];
}

/// Loads the member's stats, or reloads them.
///
/// Dispatched at sign-in and whenever stats go out of date (see
/// `StatsBootstrap`), by a pull to refresh, and by a Retry button. Pages do not
/// send it on mount: they read what [HomeBloc] already holds.
final class HomeStatsRequested extends HomeEvent {
  const HomeStatsRequested();
}

/// Forgets the stats and drops any request still in flight. Dispatched at
/// sign-out, so one member's data never shows for the next.
final class HomeResetRequested extends HomeEvent {
  const HomeResetRequested();
}
