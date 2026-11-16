import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

sealed class ServicesState extends Equatable {
  const ServicesState();
  @override
  List<Object?> get props => [];
}

final class ServicesInitial extends ServicesState {
  const ServicesInitial();
}

final class ServicesLoading extends ServicesState {
  const ServicesLoading();
}

/// One bike's service history loaded. Each record carries its own details
/// (`detail`, `detail2`), so the detail page needs no load of its own.
final class ServicesLoaded extends ServicesState {
  final List<ServiceEntity> services;

  /// True while a pull-to-refresh is fetching: [services] is still the old
  /// list, kept on screen so the list being pulled is not unmounted. It is also
  /// what makes the refreshed answer a *different* state even when the records
  /// are unchanged — a bloc drops an emit equal to the current state, and the
  /// pull indicator is waiting for exactly that emit.
  final bool refreshing;

  const ServicesLoaded(this.services, {this.refreshing = false});

  @override
  List<Object> get props => [services, refreshing];
}

final class ServicesError extends ServicesState {
  final String message;
  const ServicesError(this.message);

  @override
  List<Object> get props => [message];
}
