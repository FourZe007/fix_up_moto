import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/profile/domain/entities/motorcycle_entity.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

final class ProfileInitial extends ProfileState { const ProfileInitial(); }
final class ProfileLoading extends ProfileState { const ProfileLoading(); }

final class ProfileLoaded extends ProfileState {
  final UserEntity user;
  final List<MotorcycleEntity> motorcycles;

  const ProfileLoaded({required this.user, this.motorcycles = const []});

  @override
  List<Object> get props => [user, motorcycles];

  ProfileLoaded copyWith({
    UserEntity? user,
    List<MotorcycleEntity>? motorcycles,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      motorcycles: motorcycles ?? this.motorcycles,
    );
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
