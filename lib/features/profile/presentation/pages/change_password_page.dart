import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_purpose.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/profile_state.dart';

/// Where a phone-registered member changes their password: the old one, the new
/// one, and the new one again.
///
/// Reached via `context.push(RouteNames.changePassword)` — a top-level route,
/// so it provides its own [ProfileBloc] rather than assuming an ancestor does.
/// Google accounts never get here: their password is derived, not chosen, and
/// the Profile page hides the row (see `GooglePassword`). The repository
/// refuses them too, as a backstop.
///
/// The member stays signed in afterwards — the session stores no password — so
/// success is just a snackbar and a pop back to Profile.
class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The colour comes from the active Theme rather than an AppColors
    // constant, so this bar follows light/dark automatically. The title and
    // arrow are coloured explicitly because the app's AppBarTheme hard-codes a
    // white title style.
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return BlocProvider(
      // Page-scoped factory, like every other page's blocs.
      create: (_) => sl<ProfileBloc>(),
      // The same warm wash as the Profile and Edit Profile pages: a fixed
      // backdrop *around* the Scaffold, whose own background and AppBar are
      // transparent.
      child: WarmWash(
        child: Scaffold(
          key: const Key('change-password-page'),
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'Ganti Password',
              style: TextStyle(color: onSurface, fontSize: 20),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(foregroundColor: onSurface),
              onPressed: () => context.pop(),
            ),
          ),
          body: const _ChangePasswordForm(),
        ),
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  /// The rule for a new password: the one registration enforces, so a member
  /// cannot pick something sign-up would have refused. Local, Bahasa-language
  /// checks, like Edit Profile's — the shared `Validators` messages are English
  /// and Login/Register's wording is not this page's to change. Keep the hint
  /// under the field in step with [_validateNew].
  static String get _rule =>
      'Minimal ${AppConstants.minPasswordLength} karakter, ada huruf besar dan '
      'angka';

  // Passwords are checked exactly as typed: never trimmed.
  String? _validateOld(String? value) {
    if (value == null || value.isEmpty) return 'Sandi lama wajib diisi';
    return null;
  }

  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) return 'Sandi baru wajib diisi';
    if (value.length < AppConstants.minPasswordLength ||
        !value.contains(RegExp(r'[A-Z]')) ||
        !value.contains(RegExp(r'[0-9]'))) {
      return _rule;
    }
    // Read when the form validates, not when the page builds: typing does not
    // rebuild it, so a value taken earlier would be stale.
    if (value == _oldController.text) {
      return 'Sandi baru harus berbeda dari sandi lama';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _newController.text) return 'Konfirmasi sandi tidak sama';
    return null;
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// True while the OTP page is open, so a second tap cannot open another.
  bool _verifying = false;

  Future<void> _submit() async {
    if (_verifying || !(_formKey.currentState?.validate() ?? false)) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    // The new password is only sent once the member has typed the code sent to
    // the WhatsApp of their account. Backing out returns here with the fields
    // as they were, and nothing is sent.
    _verifying = true;
    final verified = await context.push<bool>(
      RouteNames.otp,
      extra: OtpRequest.forMember(
        user: authState.user,
        purpose: OtpPurpose.changePassword,
      ),
    );
    _verifying = false;
    if (verified != true || !mounted) return;

    context.read<ProfileBloc>().add(
      ProfileChangePasswordRequested(
        oldPassword: _oldController.text,
        newPassword: _newController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The same grey as the Profile page's contact lines: the theme's own is too
    // pale on the warm wash.
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.brightness == Brightness.dark ? null : AppColors.grey700,
    );

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileActionSuccess) {
          // Shown by the app's root messenger, so it outlives this page. The
          // member stays signed in: nothing about the session changes.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          context.pop();
        } else if (state is ProfileError) {
          // The fields keep what was typed, so one correction and a retry is
          // all a wrong old password costs.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is ProfileLoading;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  AuthTextField(
                    controller: _oldController,
                    label: 'Sandi Lama',
                    hint: 'Masukkan sandi lama',
                    prefixIcon: Icons.lock_outlined,
                    obscureText: true,
                    enabled: !isLoading,
                    validator: _validateOld,
                  ),
                  // The rule sits under its field, so it is read before it is
                  // broken.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _rule,
                          key: const Key('password-rule'),
                          style: hintStyle,
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
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
