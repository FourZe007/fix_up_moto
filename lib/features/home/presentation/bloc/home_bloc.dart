import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/home/domain/usecases/get_dashboard_stats_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

/// Holds the signed-in member's stats record for the whole app.
///
/// App-scoped, like `AuthBloc`: one lazy singleton, provided at the root with
/// `BlocProvider.value`. Home, Profile, MyPoint and Edit Profile all read the
/// same record, so none of them fetches on mount; `StatsBootstrap` loads it at
/// sign-in, reloads it when `DataRefreshCubit` says it is out of date, and
/// clears it at sign-out.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetDashboardStatsUseCase _getDashboardStats;

  /// Which request is the current one. Every request and every reset takes the
  /// next number, and an answer is used only if its number is still the latest.
  /// That drops an answer that arrives after sign-out (so it cannot land in the
  /// next member's state) and lets the newest of two overlapping requests win.
  int _requestSeq = 0;

  HomeBloc({required GetDashboardStatsUseCase getDashboardStats})
    : _getDashboardStats = getDashboardStats,
      super(const HomeInitial()) {
    on<HomeStatsRequested>(_onStatsRequested);
    on<HomeResetRequested>(_onResetRequested);
  }

  Future<void> _onStatsRequested(
    HomeStatsRequested event,
    Emitter<HomeState> emit,
  ) async {
    final seq = ++_requestSeq;

    // Stats already on screen stay on screen while they reload: swapping them
    // for a spinner would unmount whatever is showing them, including the Edit
    // Profile form with the member's typing in it.
    final current = state;
    final shown = current is HomeLoaded ? current.stats : null;
    if (shown != null) {
      emit(HomeLoaded(shown, refreshing: true));
    } else {
      emit(const HomeLoading());
    }

    final result = await _getDashboardStats();
    log('Home Dashboard Stats: $result', name: '_onStatsRequested');

    // A newer request or a reset happened meanwhile: this answer is stale.
    if (seq != _requestSeq) return;

    result.fold(
      // A failed reload keeps the old stats; only a first load has no stats to
      // fall back on, so only it shows the error.
      (failure) =>
          emit(shown != null ? HomeLoaded(shown) : HomeError(failure.message)),
      (stats) => emit(HomeLoaded(stats)),
    );
  }

  void _onResetRequested(HomeResetRequested event, Emitter<HomeState> emit) {
    _requestSeq++;
    emit(const HomeInitial());
  }
}
