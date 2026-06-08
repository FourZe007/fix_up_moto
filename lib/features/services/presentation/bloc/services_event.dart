import 'package:equatable/equatable.dart';

sealed class ServicesEvent extends Equatable {
  const ServicesEvent();
  @override
  List<Object?> get props => [];
}

/// Load (or reload) the service list, optionally filtered by category.
final class ServicesListRequested extends ServicesEvent {
  final String? categoryId;
  const ServicesListRequested({this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}

/// Load full details for a single service by its ID.
final class ServiceDetailRequested extends ServicesEvent {
  final String serviceId;
  const ServiceDetailRequested(this.serviceId);

  @override
  List<Object> get props => [serviceId];
}
