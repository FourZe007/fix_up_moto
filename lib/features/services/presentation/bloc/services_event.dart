import 'package:equatable/equatable.dart';

sealed class ServicesEvent extends Equatable {
  const ServicesEvent();
  @override
  List<Object?> get props => [];
}

/// Load (or reload) the service list, optionally filtered by category.
final class ServicesListRequested extends ServicesEvent {
  final String serviceType;
  final String? plateNo;

  const ServicesListRequested({
    this.serviceType = 'SERVICEHISTORY',
    this.plateNo,
  });

  @override
  List<Object?> get props => [serviceType, plateNo];
}

/// Load full details for a single service by its ID.
final class ServiceDetailRequested extends ServicesEvent {
  final String serviceId;
  const ServiceDetailRequested(this.serviceId);

  @override
  List<Object> get props => [serviceId];
}
