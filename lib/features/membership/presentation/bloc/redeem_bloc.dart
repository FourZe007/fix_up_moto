import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/membership/domain/usecases/redeem_reward_usecase.dart';
import 'redeem_event.dart';
import 'redeem_state.dart';

/// Spends the member's points on a voucher (the Klaim button).
///
/// Kept apart from [RewardsBloc] so the voucher list stays on screen while a
/// claim is in flight instead of being swapped for a loading state. Provided by
/// [MembershipPage] next to it, above everything a tab switch or stats reload
/// can unmount, so a claim that finishes while another tab is showing is still
/// reported.
class RedeemBloc extends Bloc<RedeemEvent, RedeemState> {
  final RedeemRewardUseCase _redeemReward;

  RedeemBloc({required RedeemRewardUseCase redeemReward})
    : _redeemReward = redeemReward,
      super(const RedeemInitial()) {
    on<RedeemRequested>(_onRequested);
  }

  Future<void> _onRequested(
    RedeemRequested event,
    Emitter<RedeemState> emit,
  ) async {
    // The buttons are off while a claim runs, but a request that still got
    // through (a double tap in the same frame) must not spend points twice.
    if (state is RedeemInProgress) return;

    emit(RedeemInProgress(event.pointId));
    final result = await _redeemReward(
      RedeemRewardParams(pointId: event.pointId),
    );
    result.fold(
      (failure) => emit(RedeemFailure(failure.message)),
      (message) =>
          emit(RedeemSuccess(voucherName: event.voucherName, message: message)),
    );
  }
}
