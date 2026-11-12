import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/phone_input_formatter.dart';
import 'package:fix_up_moto/core/helpers/text_formatter.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
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

/// "Lupa password?" — the first of the two screens a logged-out member uses to
/// get back into a phone-registered account.
///
/// They type their phone number; the app finds the member, sends a 6-digit code
/// to that number's WhatsApp (through the existing OTP page) and, once the right
/// code is typed, opens [ResetPasswordPage] to choose the new password.
///
/// **What the code does and does not protect.** The code is made and checked in
/// the app, like every other OTP here, so it stops anyone using *this screen*
/// from going further without the member's WhatsApp. It cannot stop someone who
/// talks to the server directly: the reset call itself carries no proof of the
/// code. See the notes on `PasswordResetRemoteDataSource`.
///
/// Reached from Login's "Lupa password?" link. A top-level route with its own
/// page-scoped [PasswordResetBloc].
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PasswordResetBloc>(),
      // The same warm wash as Login: a fixed backdrop around a Scaffold whose
      // own background and bar are transparent.
      child: WarmWash(
        child: Scaffold(
          key: const Key('forgot-password-page'),
          backgroundColor: Colors.transparent,
          appBar: const AuthAppBar(),
          body: const _ForgotPasswordBody(),
        ),
      ),
    );
  }
}

class _ForgotPasswordBody extends StatefulWidget {
  const _ForgotPasswordBody();

  @override
  State<_ForgotPasswordBody> createState() => _ForgotPasswordBodyState();
}

class _ForgotPasswordBodyState extends State<_ForgotPasswordBody> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  /// True while the OTP page is open, so a second "member found" cannot open
  /// another.
  bool _verifying = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onSendPressed() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<PasswordResetBloc>().add(
      // Sent as typed: PhoneNumber.toSubscriberNumber strips the leading zero at
      // the data layer, where the backend rule lives.
      PasswordResetMemberRequested(_phoneController.text.trim()),
    );
  }

  /// Asks for the code, and only if the right one is typed moves on to choosing
  /// a password. Backing out of the code page returns here with the number
  /// still typed and nothing sent.
  Future<void> _verifyThenContinue(PasswordResetMember member) async {
    if (_verifying) return;
    _verifying = true;
    final verified = await context.push<bool>(
      RouteNames.otp,
      extra: OtpRequest.toPhone(
        purpose: OtpPurpose.resetPassword,
        phone: member.phone,
      ),
    );
    _verifying = false;
    if (verified != true || !mounted) return;

    context.push(RouteNames.resetPassword, extra: member);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The same grey as Login's subtitle: the theme's own is too pale on the
    // warm wash. Light mode only, since on the dark theme's black it would
    // vanish.
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.brightness == Brightness.light ? AppColors.grey700 : null,
    );

    return BlocConsumer<PasswordResetBloc, PasswordResetState>(
      listener: (context, state) {
        if (state is PasswordResetError) {
          // The backend shouts its wording in capitals; tidied at display time.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TextFormatter.fromUppercase(state.message)),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        } else if (state is PasswordResetMemberFound) {
          _verifyThenContinue(state.member);
        }
      },
      builder: (context, state) {
        final isLoading = state is PasswordResetLoading;

        return SafeArea(
          // Identical recipe to LoginPage, for identical reasons — see that file
          // for why each of the four layers exists.
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          const Center(
                            child: ResetIconTile(
                              icon: Icons.lock_open_outlined,
                              background: AppColors.peachMist,
                              border: AppColors.peachHairline,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Lupa password?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          // Padding, not a width-capping ConstrainedBox: this
                          // column sits in an IntrinsicHeight (see above), which
                          // measures a ConstrainedBox's child at the full width
                          // rather than the capped one, so it counts a line too
                          // few and the column overflows.
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Masukkan nomor telepon yang kamu pakai saat '
                              'mendaftar. Kami kirim kode verifikasi lewat '
                              'WhatsApp.',
                              textAlign: TextAlign.center,
                              style: subtitleStyle,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // The same field as Login's: a fixed +62, and the
                          // formatter drops a typed leading 0 / 62 / +62.
                          AuthTextField(
                            controller: _phoneController,
                            label: 'Phone number',
                            hint: '81234567889',
                            prefixText: '+62',
                            keyboardType: TextInputType.phone,
                            inputFormatters: const [
                              PhoneNumberInputFormatter(),
                            ],
                            textInputAction: TextInputAction.done,
                            enabled: !isLoading,
                            validator: Validators.phone,
                          ),
                          const SizedBox(height: 24),

                          ElevatedButton(
                            key: const Key('forgot-password-send'),
                            // Disabled while looking the number up, so a
                            // double tap cannot send two codes.
                            onPressed: isLoading ? null : _onSendPressed,
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
                                : const Text('Kirim Kode'),
                          ),
                          const SizedBox(height: 24),

                          const _GoogleAccountNote(),

                          // Pushed to the bottom when there is room, and
                          // scrolled away when there is not — like Login's
                          // Register link, and not pinned, so it can never push
                          // the button off a short screen.
                          const SizedBox(height: 16),
                          const Spacer(),
                          const Divider(),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Sudah ingat password?'),
                              TextButton(
                                // Back to Login, which this was opened from;
                                // opened with nothing underneath, go there.
                                onPressed: isLoading
                                    ? null
                                    : () => context.canPop()
                                          ? context.pop()
                                          : context.go(RouteNames.login),
                                child: const Text(
                                  'Masuk',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Tells a member who signed up with Google that they have no password to
/// reset, so they do not wait for a code that will never come.
class _GoogleAccountNote extends StatelessWidget {
  const _GoogleAccountNote();

  @override
  Widget build(BuildContext context) {
    // White in light mode and light grey in dark mode, so its text needs the
    // dark-on-light colours: LightSurfaceScope supplies them, and the Builder
    // lets the text read the theme it sets up.
    return LightSurfaceScope(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Container(
            key: const Key('forgot-password-google-note'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.peachHairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Mendaftar dengan Google? Akun Google tidak memakai '
                    'password. Kembali ke halaman masuk dan pilih “Masuk '
                    'dengan Google”.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
