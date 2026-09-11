import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/feeds/domain/usecases/get_feeds_usecase.dart';
import 'feeds_event.dart';
import 'feeds_state.dart';

/// Provided at the [FeedsPage] level — not global — since it's only needed there.
class FeedsBloc extends Bloc<FeedsEvent, FeedsState> {
  final GetFeedsUseCase _getFeeds;

  FeedsBloc({required GetFeedsUseCase getFeeds})
      : _getFeeds = getFeeds,
        super(const FeedsInitial()) {
    on<FeedsRequested>(_onRequested);
  }

  Future<void> _onRequested(
    FeedsRequested event,
    Emitter<FeedsState> emit,
  ) async {
    emit(const FeedsLoading());
    final result = await _getFeeds();
    result.fold(
      (failure) => emit(FeedsError(failure.message)),
      (posts) => emit(FeedsLoaded(posts)),
    );
  }
}
