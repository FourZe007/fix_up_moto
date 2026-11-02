import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/change_password_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:fix_up_moto/features/profile/domain/usecases/update_profile_usecase.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase _getProfile;
  final UpdateProfileUseCase _updateProfile;
  final ChangePasswordUseCase _changePassword;

  ProfileBloc({
    required GetProfileUseCase getProfile,
    required UpdateProfileUseCase updateProfile,
    required ChangePasswordUseCase changePassword,
  }) : _getProfile = getProfile,
       _updateProfile = updateProfile,
       _changePassword = changePassword,
       super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
    on<ProfileChangePasswordRequested>(_onChangePasswordRequested);
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
      UpdateProfileParams(
        name: event.name,
        phone: event.phone,
        email: event.email,
      ),
    );
    // No ProfileLoaded after this: the write returns no member record, so the
    // page that asked re-reads the member itself (via DataRefreshCubit).
    result.fold(
      (f) => emit(ProfileError(f.message)),
      (_) => emit(const ProfileActionSuccess('Profil berhasil diperbarui')),
    );
  }

  Future<void> _onChangePasswordRequested(
    ProfileChangePasswordRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    final result = await _changePassword(
      ChangePasswordParams(
        oldPassword: event.oldPassword,
        newPassword: event.newPassword,
      ),
    );
    // A refusal (a wrong old password) arrives as a failure carrying the
    // server's own wording, which the page shows as it is.
    result.fold(
      (f) => emit(ProfileError(f.message)),
      (_) => emit(const ProfileActionSuccess('Sandi berhasil diubah')),
    );
  }
}
