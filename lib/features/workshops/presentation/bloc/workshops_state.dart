import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

sealed class WorkshopsState extends Equatable {
  const WorkshopsState();
  @override
  List<Object?> get props => [];
}

final class WorkshopsInitial extends WorkshopsState {
  const WorkshopsInitial();
}

final class WorkshopsLoading extends WorkshopsState {
  const WorkshopsLoading();
}

final class WorkshopsLoaded extends WorkshopsState {
  final List<WorkshopEntity> workshops;
  const WorkshopsLoaded(this.workshops);

  @override
  List<Object> get props => [workshops];
}

final class WorkshopsError extends WorkshopsState {
  final String message;
  const WorkshopsError(this.message);

  @override
  List<Object> get props => [message];
}
