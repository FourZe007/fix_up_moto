import 'package:equatable/equatable.dart';

sealed class ServicesEvent extends Equatable {
  const ServicesEvent();
  @override
  List<Object?> get props => [];
}

/// Load (or reload) the service history of one bike. [plateNo] is required: the
/// backend answers per plate, so there is nothing to load without one.
final class ServicesListRequested extends ServicesEvent {
  final String serviceType;
  final String plateNo;

  const ServicesListRequested({
    this.serviceType = 'SERVICEHISTORY',
    required this.plateNo,
  });

  @override
  List<Object?> get props => [serviceType, plateNo];
}

/// Pull-to-refresh: load the same bike's history again **without** blanking the
/// list. [ServicesListRequested] shows the full-screen spinner first, which would
/// unmount the very list being pulled; this one keeps the list on screen
/// ([ServicesLoaded.refreshing]) until the new records arrive.
final class ServicesRefreshRequested extends ServicesEvent {
  final String serviceType;
  final String plateNo;

  const ServicesRefreshRequested({
    this.serviceType = 'SERVICEHISTORY',
    required this.plateNo,
  });

  @override
  List<Object?> get props => [serviceType, plateNo];
}
