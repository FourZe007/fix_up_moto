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
  final String phone;
  final String email;
  const ProfileUpdateRequested({
    required this.name,
    required this.phone,
    required this.email,
  });

  @override
  List<Object?> get props => [name, phone, email];
}

/// The member asked to change their password. Both are exactly as typed —
/// passwords are never trimmed.
final class ProfileChangePasswordRequested extends ProfileEvent {
  final String oldPassword;
  final String newPassword;
  const ProfileChangePasswordRequested({
    required this.oldPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [oldPassword, newPassword];
}
