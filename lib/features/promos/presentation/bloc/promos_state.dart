import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/promos/domain/entities/promo_image_entity.dart';

sealed class PromosState extends Equatable {
  const PromosState();
  @override
  List<Object?> get props => [];
}

final class PromosInitial extends PromosState {
  const PromosInitial();
}

final class PromosLoading extends PromosState {
  const PromosLoading();
}

final class PromosLoaded extends PromosState {
  final List<PromoImageEntity> images;
  const PromosLoaded(this.images);

  @override
  List<Object> get props => [images];
}

final class PromosError extends PromosState {
  final String message;
  const PromosError(this.message);

  @override
  List<Object> get props => [message];
}
