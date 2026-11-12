import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_app_bar.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_bloc.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_event.dart';
import 'package:fix_up_moto/features/password_reset/presentation/bloc/password_reset_state.dart';
import 'package:fix_up_moto/features/password_reset/presentation/widgets/reset_icon_tile.dart';

/// "Buat password baru" — the second screen of a forgotten-password reset,
/// reached only after the right code was typed on the OTP page.
///
/// A new password and its confirmation, under the same rule as registration and
/// Ganti Password. "Simpan" runs the reset against the server; on success the
/// member is sent back to Login with a message, and signs in themselves — the
/// reset starts no session.
///
/// The [member] arrives as the route's `extra`; the guard sends a restored route
/// that has none back to Login (see `AppRouter.guard`).
class ResetPasswordPage extends StatelessWidget {
  final PasswordResetMember member;

  const ResetPasswordPage({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PasswordResetBloc>(),
      child: WarmWash(
        child: Scaffold(
          key: const Key('reset-password-page'),
          backgroundColor: Colors.transparent,
          appBar: const AuthAppBar(),
          body: _ResetPasswordForm(member: member),
        ),
      ),
    );
  }
}

class _ResetPasswordForm extends StatefulWidget {
  final PasswordResetMember member;

  const _ResetPasswordForm({required this.member});

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  /// The rule for a new password: the one registration and Ganti Password
  /// enforce, so a member cannot pick something sign-up would have refused.
  /// Local, Bahasa-language checks, like Ganti Password's. Keep the hint under
  /// the field in step with [_validateNew].
  static String get _rule =>
      'Minimal ${AppConstants.minPasswordLength} karakter, ada huruf besar dan '
      'angka';

  // Passwords are checked exactly as typed: never trimmed.
  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) return 'Sandi baru wajib diisi';
    if (value.length < AppConstants.minPasswordLength ||
        !value.contains(RegExp(r'[A-Z]')) ||
        !value.contains(RegExp(r'[0-9]'))) {
      return _rule;
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    // Read when the form validates, not when the page builds: typing does not
    // rebuild it, so a value taken earlier would be stale.
    if (value != _newController.text) return 'Konfirmasi sandi tidak sama';
    return null;
  }

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<PasswordResetBloc>().add(
      PasswordResetSubmitted(
        memberId: widget.member.memberId,
        newPassword: _newController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    // The same greys as Login and Ganti Password: the theme's own is too pale on
    // the warm wash. Light mode only, since on the dark theme's black they would
    // vanish.
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isLight ? AppColors.grey700 : null,
    );
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: isLight ? AppColors.grey700 : null,
    );
    // Where the code went, with its middle hidden — the same line the OTP page
    // shows — so the member sees which number this is for.
    final maskedPhone = OtpRequest.toPhone(
      purpose: OtpPurpose.resetPassword,
      phone: widget.member.phone,
    ).maskedDestination;

    return BlocConsumer<PasswordResetBloc, PasswordResetState>(
      listener: (context, state) {
        if (state is PasswordResetSuccess) {
          // Shown by the app's root messenger, so it outlives this page. `go`,
          // not `pop`: the stack under this page is Login and the code page's
          // leftovers, and the member should land on a fresh Login.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password berhasil diubah. Silakan masuk.'),
            ),
          );
          context.go(RouteNames.login);
        } else if (state is PasswordResetError) {
          // The fields keep what was typed, so one correction and a retry is
          // all a refusal costs.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextFormatter.fromUppercase(state.message)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is PasswordResetLoading;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Center(
                    child: ResetIconTile(
                      icon: Icons.check_circle_outline,
                      background: AppColors.successBackground,
                      border: Color(0xFFC8E6C9),
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Buat password baru',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 310),
                      child: Text(
                        'Kode benar. Pilih password baru untuk $maskedPhone.',
                        key: const Key('reset-password-subtitle'),
                        textAlign: TextAlign.center,
                        style: subtitleStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // The rule sits under its field, so it is read before it is
                  // broken.
                  AuthTextField(
                    controller: _newController,
                    label: 'Sandi Baru',
                    hint: 'Masukkan sandi baru',
                    prefixIcon: Icons.lock_outlined,
                    obscureText: true,
                    enabled: !isLoading,
                    validator: _validateNew,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      _rule,
                      key: const Key('password-rule'),
                      style: hintStyle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmController,
                    label: 'Konfirmasi Sandi Baru',
                    hint: 'Ulangi sandi baru',
                    prefixIcon: Icons.lock_outlined,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    key: const Key('reset-password-save'),
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: AppSpinner(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
