import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/domain/usecases/get_profile_usecase.dart';
import 'package:fix_up_moto/domain/usecases/update_profile_usecase.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase _getProfile;
  final UpdateProfileUseCase _updateProfile;

  ProfileBloc({
    required GetProfileUseCase getProfile,
    required UpdateProfileUseCase updateProfile,
  })  : _getProfile = getProfile,
        _updateProfile = updateProfile,
        super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
  }

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    final result = await _getProfile();
    result.fold(
      (f) => emit(ProfileError(f.message)),
      (user) => emit(ProfileLoaded(user: user)),
    );
  }

  Future<void> _onUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    final result = await _updateProfile(
      UpdateProfileParams(name: event.name, phone: event.phone),
    );
    result.fold(
      (f) => emit(ProfileError(f.message)),
      (user) {
        emit(const ProfileActionSuccess('Profile updated successfully'));
        emit(ProfileLoaded(user: user));
      },
    );
  }
}
