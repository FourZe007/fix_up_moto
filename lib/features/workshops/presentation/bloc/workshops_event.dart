import 'package:equatable/equatable.dart';

sealed class WorkshopsEvent extends Equatable {
  const WorkshopsEvent();
  @override
  List<Object> get props => [];
}

/// Dispatched when the workshop list mounts or the user pulls to refresh.
final class WorkshopsRequested extends WorkshopsEvent {
  const WorkshopsRequested();
}
