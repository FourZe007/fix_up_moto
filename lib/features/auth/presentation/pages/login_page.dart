import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';

/// Login screen — the first page unauthenticated users see.
///
/// Uses [BlocConsumer] to:
/// - Listen for [AuthError] state changes (side effects)
/// - Build the form UI reactively from the current state
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    // Validate all fields before dispatching the event
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        AuthLoginRequested(
          // Sent as typed — PhoneNumber.toSubscriberNumber strips the
          // leading zero at the data layer, where the backend rule lives.
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        // listener: handles one-time side effects (navigation, SnackBars)
        listener: (context, state) {
          if (state is AuthError) {
            // Show error without navigating away — user stays on the form
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }

          // The one manual push in this whole file. AppRouter's redirect
          // handles every other transition, but AuthGoogleIdentityObtained is
          // not "authenticated" or "unauthenticated" — it is a one-shot signal
          // carrying data the destination page needs, which a redirect (no
          // access to arbitrary payloads) cannot express. Push directly instead.
          if (state is AuthGoogleIdentityObtained) {
            context.push(
              RouteNames.completeGoogleProfile,
              extra: GoogleAccountIdentity(
                displayName: state.displayName,
                email: state.email,
              ),
            );
          }
        },
        // builder: rebuilds the UI whenever state changes
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            // ── Why these four layers ──────────────────────────────────────
            // Each one exists to solve the problem the one above it creates:
            //
            // 1. LayoutBuilder    — hands us constraints.maxHeight, i.e. the
            //                       real viewport after SafeArea and Padding.
            // 2. SingleChildScroll— lets the content scroll, so the keyboard
            //                       (manifest uses adjustResize) can never
            //                       overflow the Column.
            //    …but a scroll view gives its child UNBOUNDED height, and
            //    Spacer/Expanded throw on unbounded height.
            // 3. ConstrainedBox   — minHeight keeps the Column at least a full
            //                       screen tall, so it still fills a tall phone.
            //    …minHeight alone sets a floor, not a ceiling, so height is
            //    still unbounded and Spacer still throws.
            // 4. IntrinsicHeight  — bounds the height to the content's natural
            //                       height, which is what finally lets Spacer
            //                       resolve.
            //
            // Cost: IntrinsicHeight re-measures its subtree, so it is a poor
            // choice inside a long list. For a form with a handful of children
            // it is the standard, correct recipe.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Subtract the padding we just added, or the content is
                      // 48px taller than the viewport and always scrolls a little.
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The two Spacers now centre the form in the space
                            // ABOVE the Google footer, not in the whole screen.
                            const Spacer(),

                            // ── Header ─────────────────────────────────────
                            Text(
                              'Welcome back',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to manage your bookings',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 40),

                            // ── Phone number field ──────────────────────────
                            // The phone number is the login credential, not an
                            // email. Typing the leading 0 is fine — it is
                            // stripped before the request is sent.
                            AuthTextField(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: '081234567890',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: 16),

                            // ── Password field ──────────────────────────────
                            AuthTextField(
                              controller: _passwordController,
                              label: 'Password',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Password is required'
                                  : null,
                            ),
                            const SizedBox(height: 32),

                            // ── Login button ────────────────────────────────
                            ElevatedButton(
                              // Disable while loading to prevent double-tap
                              onPressed: isLoading ? null : _onLoginPressed,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),

                            // ── Register link ───────────────────────────────
                            // ONE tappable widget, not a TextButton wrapping
                            // another TextButton: overlapping tap targets give
                            // screen readers two conflicting labels, and the
                            // inner button ignored isLoading, which let users
                            // navigate away mid-login.
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Tidak punya akun?'),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () => context.push(RouteNames.register),
                                  // Colour comes from textButtonTheme
                                  // (AppColors.primary) rather than a hardcoded
                                  // Colors.blue, so dark mode works.
                                  child: const Text(
                                    'Daftar disini',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // ── Footer: sits at the bottom when there is room,
                            //    and scrolls with everything else when there
                            //    isn't (keyboard open on a short screen).
                            _GoogleSignInSection(isLoading: isLoading),
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
      ),
    );
  }
}

/// "Continue with Google" footer: a labelled divider plus an outlined button.
///
/// Split into its own widget so the page's build method stays readable, and so
/// the divider/button pair can be reused on the register page later.
class _GoogleSignInSection extends StatelessWidget {
  final bool isLoading;

  const _GoogleSignInSection({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Labelled divider — Expanded on each side so the rule fills whatever
        // space the centred label leaves, at any screen width.
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'atau masuk dengan',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),

        // Align opts this child OUT of the Column's CrossAxisAlignment.stretch.
        // Under stretch the parent hands down a TIGHT width equal to the full
        // column width, and `minimumSize` only sets a floor — it cannot shrink
        // a box whose width is already forced. Align passes loose constraints
        // down instead, which is what finally lets the button size to its
        // content.
        Align(
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : () => context.read<AuthBloc>().add(
                    const AuthGoogleIdentityRequested(),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(32, 32),
              // elevatedButtonTheme sets 24/14 padding app-wide; without
              // overriding it here the button keeps 48px of horizontal
              // padding around a 28px logo and looks nothing like a
              // 32x32 button.
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Image.asset(
              'assets/images/google_logo.png',
              width: 28,
              height: 28,
              // The source PNG is 3840x3840. Decoded at full size that is
              // ~59 MB of RAM (3840 * 3840 * 4 bytes) for a 28px icon.
              // cacheWidth decodes it at display resolution instead.
              cacheWidth: (28 * MediaQuery.devicePixelRatioOf(context)).round(),
            ),
          ),
        ),
      ],
    );
  }
}
