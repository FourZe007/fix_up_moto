import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

final class ProfileInitial extends ProfileState { const ProfileInitial(); }
final class ProfileLoading extends ProfileState { const ProfileLoading(); }

final class ProfileLoaded extends ProfileState {
  final UserEntity user;

  const ProfileLoaded({required this.user});

  @override
  List<Object> get props => [user];

  ProfileLoaded copyWith({UserEntity? user}) {
    return ProfileLoaded(user: user ?? this.user);
  }
}

final class ProfileActionSuccess extends ProfileState {
  final String message;
  const ProfileActionSuccess(this.message);

  @override
  List<Object> get props => [message];
}

final class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object> get props => [message];
}
