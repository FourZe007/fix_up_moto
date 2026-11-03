import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_app_bar.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_channel.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/domain/otp_code_generator.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_bloc.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_event.dart';
import 'package:fix_up_moto/features/otp/presentation/bloc/otp_state.dart';

/// Asks the member for the code that was just sent to their WhatsApp or email,
/// before an action that touches their account goes ahead.
///
/// Opened with `await context.push<bool>(RouteNames.otp, extra: request)` and
/// closes with `true` only when the right code was typed. Backing out, by the
/// arrow or the system button, closes it with nothing, which every caller reads
/// as "not verified" and so does nothing.
///
/// It sends the code as soon as it opens, so the caller needs no separate "send"
/// step. Reachable logged-out (registering) and logged-in (changing a password,
/// editing a profile) alike: see [AppRouter.guard].
class OtpVerificationPage extends StatelessWidget {
  final OtpRequest request;

  const OtpVerificationPage({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Page-scoped factory: each verification gets a fresh bloc and so a fresh
      // code. Starting it here sends the first one.
      create: (_) => sl<OtpBloc>()..add(OtpStarted(request)),
      // The same warm wash as Login: a fixed backdrop around a Scaffold whose
      // own background and bar are transparent.
      child: WarmWash(
        child: Scaffold(
          key: const Key('otp-page'),
          backgroundColor: Colors.transparent,
          appBar: const AuthAppBar(),
          body: _OtpBody(request: request),
        ),
      ),
    );
  }
}

class _OtpBody extends StatefulWidget {
  final OtpRequest request;

  const _OtpBody({required this.request});

  @override
  State<_OtpBody> createState() => _OtpBodyState();
}

class _OtpBodyState extends State<_OtpBody> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text;
    if (code.length == OtpCodeGenerator.length) {
      context.read<OtpBloc>().add(OtpCodeSubmitted(code));
    }
  }

  static String _minutesAndSeconds(int total) {
    final minutes = total ~/ 60;
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    // Same reasoning as Login's subtitle: the theme's usual grey is too pale on
    // the orange tint in light mode; on the dark theme's black grey700 would
    // vanish, so there the theme's own colour stays.
    final quiet = theme.textTheme.bodyMedium?.copyWith(
      color: isLight ? AppColors.grey700 : null,
    );

    return BlocConsumer<OtpBloc, OtpState>(
      // Only the moments the field itself must react to: a right code (leave),
      // a new code on its way or just out (clear it and focus it), a wrong code
      // or a dead one (clear it). Not every second's tick.
      listenWhen: (previous, current) => switch (current) {
        OtpVerified() => true,
        OtpSending() => true,
        OtpAwaitingCode() =>
          previous is OtpSending ||
              (previous is OtpAwaitingCode &&
                  previous.attemptsLeft != current.attemptsLeft),
        OtpCodeUnusable() => previous is! OtpCodeUnusable,
        _ => false,
      },
      listener: (context, state) {
        if (state is OtpVerified) {
          context.pop(true);
          return;
        }
        _controller.clear();
        if (state is OtpAwaitingCode) {
          // After this frame, not now: the field is still switched off while
          // the code was being sent, and a switched-off field refuses focus.
          // Once it is on, focusing it is what brings the keyboard up.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _focus.requestFocus();
          });
        }
      },
      builder: (context, state) {
        final awaiting = state is OtpAwaitingCode ? state : null;
        final channel = widget.request.channel;
        // Font Awesome icons are drawn by FaIcon, Material ones by Icon.
        final Widget icon = channel == OtpChannel.whatsapp
            ? const FaIcon(
                FontAwesomeIcons.whatsapp,
                size: 34,
                color: AppColors.primary,
              )
            : const Icon(
                Icons.mail_outline,
                size: 34,
                color: AppColors.primary,
              );

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    // Without this the icon sits in the circle's top-left corner.
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight.withValues(alpha: 0.18),
                    ),
                    child: icon,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Verifikasi',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kode ${OtpCodeGenerator.length} digit dikirim ke '
                  '${channel.label}',
                  textAlign: TextAlign.center,
                  style: quiet,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.request.maskedDestination,
                  key: const Key('otp-destination'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),

                _CodeBoxes(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: awaiting != null,
                  hasError: awaiting?.lastWasWrong ?? false,
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 12),

                // One line under the boxes that says what is going on. A live
                // region, so a screen reader announces a wrong code as it
                // appears.
                Semantics(
                  liveRegion: true,
                  child: SizedBox(
                    key: const Key('otp-message'),
                    height: 24,
                    child: Center(child: _message(theme, quiet, state)),
                  ),
                ),
                const SizedBox(height: 24),

                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => ElevatedButton(
                    key: const Key('otp-submit'),
                    onPressed:
                        awaiting != null &&
                            _controller.text.length == OtpCodeGenerator.length
                        ? _submit
                        : null,
                    style: ElevatedButton.styleFrom(
                      // The same pill as Sign In.
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: const Text('Verifikasi'),
                  ),
                ),
                const SizedBox(height: 8),

                // A Wrap, not a Row, so large text flows onto a second line.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Belum menerima kode?'),
                    _resendButton(context, state),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _message(ThemeData theme, TextStyle? quiet, OtpState state) {
    final error = quiet?.copyWith(color: theme.colorScheme.error);

    return switch (state) {
      OtpSending() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Mengirim kode…', style: quiet),
        ],
      ),
      OtpAwaitingCode(:final lastWasWrong, :final attemptsLeft)
          when lastWasWrong =>
        Text('Kode salah. Sisa $attemptsLeft percobaan.', style: error),
      OtpAwaitingCode(:final expiresIn) => Text(
        'Kode berlaku ${_minutesAndSeconds(expiresIn)}',
        style: quiet,
      ),
      OtpCodeUnusable(:final reason) => Text(
        reason == OtpUnusableReason.expired
            ? 'Kode kedaluwarsa.'
            : 'Terlalu banyak percobaan.',
        style: error,
      ),
      OtpSendFailed(:final message) => Text(
        message,
        style: error,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _resendButton(BuildContext context, OtpState state) {
    final (enabled, label) = switch (state) {
      OtpSendFailed() => (true, 'Coba lagi'),
      OtpAwaitingCode(:final resendIn) || OtpCodeUnusable(:final resendIn) =>
        resendIn > 0
            ? (false, 'Kirim ulang ($resendIn dtk)')
            : (true, 'Kirim ulang'),
      _ => (false, 'Kirim ulang'),
    };

    return TextButton(
      key: const Key('otp-resend'),
      onPressed: enabled
          ? () => context.read<OtpBloc>().add(const OtpResendRequested())
          : null,
      child: Text(label),
    );
  }
}

/// [OtpCodeGenerator.length] boxes that show the digits typed so far.
///
/// One invisible text field sits over them and does the real work (keyboard,
/// paste, the OS offering a code it just received), so there is a single caret
/// and no hopping between six little fields.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final VoidCallback onSubmitted;

  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final text = controller.text;

              return Row(
                children: [
                  for (var i = 0; i < OtpCodeGenerator.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _CodeBox(
                        key: Key('otp-box-$i'),
                        digit: i < text.length ? text[i] : '',
                        // The next box to be filled lights up while the field
                        // has focus.
                        active:
                            enabled &&
                            focusNode.hasFocus &&
                            i == text.length.clamp(0, 5),
                        // Red says "that one was wrong": it goes as soon as the
                        // next code is being typed, while the line under the
                        // boxes still says how many tries are left.
                        error: hasError && text.isEmpty,
                        enabled: enabled,
                        color: theme.colorScheme.surface,
                        textColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: Semantics(
                label: 'Kode verifikasi ${OtpCodeGenerator.length} digit',
                textField: true,
                child: TextField(
                  key: const Key('otp-input'),
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  autofocus: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(OtpCodeGenerator.length),
                  ],
                  onSubmitted: (_) => onSubmitted(),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String digit;
  final bool active;
  final bool error;
  final bool enabled;
  final Color color;
  final Color textColor;

  const _CodeBox({
    super.key,
    required this.digit,
    required this.active,
    required this.error,
    required this.enabled,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = error
        ? AppColors.error
        : active
        ? AppColors.primary
        : AppColors.grey400;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? color : color.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: active || error ? 2 : 1),
      ),
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
