import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/membership/domain/usecases/get_rewards_usecase.dart';
import 'rewards_event.dart';
import 'rewards_state.dart';

/// Loads the voucher list (point-priced rewards) for the Membership page's
/// Voucher tab.
///
/// Provided by [MembershipPage] *above* the stats `BlocBuilder`, not inside the
/// tab: `HomeBloc` emits a loading state on every refresh, which unmounts the
/// whole loaded body, so a bloc created in there would be thrown away (and the
/// list refetched) on every pull-to-refresh.
class RewardsBloc extends Bloc<RewardsEvent, RewardsState> {
  final GetRewardsUseCase _getRewards;

  RewardsBloc({required GetRewardsUseCase getRewards})
    : _getRewards = getRewards,
      super(const RewardsInitial()) {
    on<RewardsRequested>(_onRequested);
  }

  Future<void> _onRequested(
    RewardsRequested event,
    Emitter<RewardsState> emit,
  ) async {
    emit(const RewardsLoading());
    final result = await _getRewards();
    result.fold(
      (failure) => emit(RewardsError(failure.message)),
      (rewards) => emit(RewardsLoaded(rewards)),
    );
  }
}
