import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/domain/usecases/get_dashboard_stats_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

/// Manages the home dashboard state.
/// Provided at the [HomePage] level — not global — since it's only needed there.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetDashboardStatsUseCase _getDashboardStats;

  HomeBloc({required GetDashboardStatsUseCase getDashboardStats})
      : _getDashboardStats = getDashboardStats,
        super(const HomeInitial()) {
    on<HomeStatsRequested>(_onStatsRequested);
  }

  Future<void> _onStatsRequested(
    HomeStatsRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());
    final result = await _getDashboardStats();
    result.fold(
      (failure) => emit(HomeError(failure.message)),
      (stats)   => emit(HomeLoaded(stats)),
    );
  }
}
