import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/promos/domain/usecases/get_promo_images_usecase.dart';
import 'promos_event.dart';
import 'promos_state.dart';

/// Provided at the [_PromoCarousel] level — not global — since it's only
/// needed there.
class PromosBloc extends Bloc<PromosEvent, PromosState> {
  final GetPromoImagesUseCase _getPromoImages;

  PromosBloc({required GetPromoImagesUseCase getPromoImages})
      : _getPromoImages = getPromoImages,
        super(const PromosInitial()) {
    on<PromoImagesRequested>(_onRequested);
  }

  Future<void> _onRequested(
    PromoImagesRequested event,
    Emitter<PromosState> emit,
  ) async {
    emit(const PromosLoading());
    final result = await _getPromoImages();
    result.fold(
      (failure) => emit(PromosError(failure.message)),
      (images) => emit(PromosLoaded(images)),
    );
  }
}
