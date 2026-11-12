import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fix_up_moto/features/password_reset/domain/usecases/find_member_for_reset_usecase.dart';
import 'package:fix_up_moto/features/password_reset/domain/usecases/reset_password_usecase.dart';
import 'password_reset_event.dart';
import 'password_reset_state.dart';

/// Runs the two server calls of a forgotten-password reset: finding the member
/// by phone, then setting their new password.
///
/// Each of the two pages creates its own instance (a page-scoped factory), so
/// the first page's "member found" can never leak into the second.
///
/// It does **not** check the verification code: that is the OTP page's job, and
/// this bloc is only asked to set a password once the page has seen it pass.
class PasswordResetBloc extends Bloc<PasswordResetEvent, PasswordResetState> {
  final FindMemberForResetUseCase _findMember;
  final ResetPasswordUseCase _resetPassword;

  PasswordResetBloc({
    required FindMemberForResetUseCase findMember,
    required ResetPasswordUseCase resetPassword,
  }) : _findMember = findMember,
       _resetPassword = resetPassword,
       super(const PasswordResetInitial()) {
    on<PasswordResetMemberRequested>(_onMemberRequested);
    on<PasswordResetSubmitted>(_onSubmitted);
  }

  Future<void> _onMemberRequested(
    PasswordResetMemberRequested event,
    Emitter<PasswordResetState> emit,
  ) async {
    emit(const PasswordResetLoading());
    final result = await _findMember(
      FindMemberForResetParams(phone: event.phone),
    );
    result.fold(
      (f) => emit(PasswordResetError(f.message)),
      (member) => emit(PasswordResetMemberFound(member)),
    );
  }

  Future<void> _onSubmitted(
    PasswordResetSubmitted event,
    Emitter<PasswordResetState> emit,
  ) async {
    emit(const PasswordResetLoading());
    final result = await _resetPassword(
      ResetPasswordParams(
        memberId: event.memberId,
        newPassword: event.newPassword,
      ),
    );
    result.fold(
      (f) => emit(PasswordResetError(f.message)),
      (_) => emit(const PasswordResetSuccess()),
    );
  }
}
