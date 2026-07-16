import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

sealed class ServicesState extends Equatable {
  const ServicesState();
  @override
  List<Object?> get props => [];
}

final class ServicesInitial extends ServicesState { const ServicesInitial(); }
final class ServicesLoading extends ServicesState { const ServicesLoading(); }

/// Service list loaded — [services] may be filtered by category.
final class ServicesLoaded extends ServicesState {
  final List<ServiceEntity> services;
  const ServicesLoaded(this.services);

  @override
  List<Object> get props => [services];
}

/// Single service detail loaded.
final class ServiceDetailLoaded extends ServicesState {
  final ServiceEntity service;
  const ServiceDetailLoaded(this.service);

  @override
  List<Object> get props => [service];
}

final class ServicesError extends ServicesState {
  final String message;
  const ServicesError(this.message);

  @override
  List<Object> get props => [message];
}
