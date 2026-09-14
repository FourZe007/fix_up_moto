import 'package:equatable/equatable.dart';

sealed class PromosEvent extends Equatable {
  const PromosEvent();
  @override
  List<Object> get props => [];
}

/// Dispatched when the promo carousel mounts.
final class PromoImagesRequested extends PromosEvent {
  const PromoImagesRequested();
}
