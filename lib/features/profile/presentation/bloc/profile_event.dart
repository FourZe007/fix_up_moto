import 'package:equatable/equatable.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

final class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

final class ProfileUpdateRequested extends ProfileEvent {
  final String name;
  final String? phone;
  const ProfileUpdateRequested({required this.name, this.phone});

  @override
  List<Object?> get props => [name, phone];
}
