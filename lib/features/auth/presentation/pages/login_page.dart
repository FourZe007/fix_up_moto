import 'dart:developer';

import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/core/helpers/phone_input_formatter.dart';
import 'package:fix_up_moto/core/helpers/validators.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_app_bar.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_logo.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_text_field.dart';

/// Login screen — the first page unauthenticated users see.
///
/// Top to bottom: the brand logo, a centred headline, the phone and password
/// fields, "Sign In", an "atau" divider with a labelled Google button, and the
/// way to Register. It sits on the same warm orange wash as the Welcome screen
/// ([WarmWash]), so the logo has a warm backdrop and the white fields stand out
/// from it.
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
    log('Username: ${_phoneController.text}');
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
    // The wash is a fixed backdrop *around* the Scaffold, whose own background
    // and bar are transparent, so it shows behind the bar and the scrolling
    // content moves over it — the same recipe as the Profile pages.
    return WarmWash(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Back arrow only — to the welcome screen this was opened from.
        appBar: const AuthAppBar(),
        body: BlocConsumer<AuthBloc, AuthState>(
          // listener: handles one-time side effects (navigation, SnackBars)
          listener: (context, state) {
            // Only while this page is the one on screen. Register and the
            // Google profile page are pushed on top of Login, which stays
            // mounted underneath still listening to the same AuthBloc — so
            // without this an error they cause would be reported twice, once
            // by each page.
            if (state is AuthError &&
                (ModalRoute.of(context)?.isCurrent ?? true)) {
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
            // not "authenticated" or "unauthenticated" — it is a one-shot
            // signal carrying data the destination page needs, which a redirect
            // (no access to arbitrary payloads) cannot express. Push directly
            // instead.
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
            final theme = Theme.of(context);

            // The subtitle's usual grey is about 3.9:1 on the orange tint, under
            // the 4.5:1 that small text should have; grey700 is about 5:1. Light
            // mode only — on the dark theme's black grey700 would vanish, so
            // there the theme's own colour stays.
            final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.light
                  ? AppColors.grey700
                  : null,
            );

            return SafeArea(
              // ── Why these four layers ────────────────────────────────────
              // Each one exists to solve the problem the one above it creates:
              //
              // 1. LayoutBuilder    — hands us constraints.maxHeight, i.e. the
              //                       real viewport after SafeArea and Padding.
              // 2. SingleChildScroll— lets the content scroll, so the keyboard
              //                       (manifest uses adjustResize) can never
              //                       overflow the Column.
              //    …but a scroll view gives its child UNBOUNDED height, and
              //    Spacer/Expanded throw on unbounded height.
              // 3. ConstrainedBox   — minHeight keeps the Column at least a
              //                       full screen tall, so it still fills a
              //                       tall phone.
              //    …minHeight alone sets a floor, not a ceiling, so height is
              //    still unbounded and Spacer still throws.
              // 4. IntrinsicHeight  — bounds the height to the content's
              //                       natural height, which is what finally
              //                       lets Spacer resolve.
              //
              // Cost: IntrinsicHeight re-measures its subtree, so it is a poor
              // choice inside a long list. For a form with a handful of
              // children it is the standard, correct recipe.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // Subtract the padding we just added, or the content is
                        // 48px taller than the viewport and always scrolls a
                        // little.
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: IntrinsicHeight(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Logo ──────────────────────────────────────
                              // Just under the bar, centred. 176 px wide is a
                              // little under Welcome's 220: the same mark, in
                              // proportion to a page that also holds a form.
                              const SizedBox(height: 8),
                              const Center(child: AuthLogo(width: 176)),

                              // The gap between the logo and the headline: a
                              // fixed minimum plus whatever room is left, so
                              // on a tall phone the form sits in the lower
                              // middle, and on a short one the minimum keeps
                              // the two from bunching up.
                              const SizedBox(height: 24),
                              const Spacer(),

                              // ── Header ───────────────────────────────────
                              Text(
                                'Welcome back',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to manage your bookings',
                                textAlign: TextAlign.center,
                                style: subtitleStyle,
                              ),
                              const SizedBox(height: 32),

                              // ── Phone number field ────────────────────────
                              // The phone number is the login credential, not
                              // an email. The fixed +62 and the example number
                              // show how to fill it in before it is tapped, and
                              // the formatter drops a typed leading 0 / 62 /
                              // +62 as the member types, so the field holds
                              // what the backend wants (812…). The data layer
                              // still normalises as a safety net.
                              AuthTextField(
                                controller: _phoneController,
                                label: 'Phone number',
                                hint: '81234567889',
                                prefixText: '+62',
                                keyboardType: TextInputType.phone,
                                inputFormatters: const [
                                  PhoneNumberInputFormatter(),
                                ],
                                validator: Validators.phone,
                              ),
                              const SizedBox(height: 16),

                              // ── Password field ────────────────────────────
                              AuthTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Masukkan password',
                                prefixIcon: Icons.lock_outlined,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Password is required'
                                    : null,
                              ),

                              // ── Lupa password ─────────────────────────────
                              // Right-aligned under the field it is about,
                              // where the eye goes after a failed Sign In. It
                              // is for phone accounts only: a Google account
                              // has no password to forget, and the page it
                              // opens says so. Disabled mid-login, like the
                              // Register link, so nobody navigates away from a
                              // request that is still running.
                              //
                              // primaryDark in light mode, not the theme's
                              // primary: this is small text on the page's
                              // lower, plain background, where primary is about
                              // 3.5:1 and primaryDark about 6:1. On the dark
                              // theme's black the theme's own colour stays.
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: const Key('login-forgot-password'),
                                  onPressed: isLoading
                                      ? null
                                      : () => context.push(
                                          RouteNames.forgotPassword,
                                        ),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.brightness == Brightness.light
                                        ? AppColors.primaryDark
                                        : null,
                                    // 44 high, as tall as the design's link
                                    // row, without the extra padding a default
                                    // button's tap target adds around it.
                                    minimumSize: const Size(0, 44),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Lupa password?',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // ── Login button ──────────────────────────────
                              ElevatedButton(
                                // Disable while loading to prevent double-tap
                                onPressed: isLoading ? null : _onLoginPressed,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadiusGeometry.circular(
                                      40,
                                    ),
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
                                    : const Text('Sign In'),
                              ),

                              // ── "atau" + Google ───────────────────────────
                              const SizedBox(height: 16),
                              _GoogleSignInSection(isLoading: isLoading),

                              // ── Register link ─────────────────────────────
                              // Last, under a rule, and quieter than Sign In —
                              // the way in for the few who have no account.
                              // It is the last item of the scrolling column
                              // and not a pinned footer on purpose: pinned, it
                              // would take height above the keyboard and could
                              // push Sign In off a short screen. Here it sits
                              // at the bottom when there is room, and scrolls
                              // away when there is not.
                              //
                              // ONE tappable widget, not a TextButton wrapping
                              // another TextButton: overlapping tap targets
                              // give screen readers two conflicting labels, and
                              // the inner button ignored isLoading, which let
                              // users navigate away mid-login.
                              const SizedBox(height: 16),
                              const Spacer(),
                              const Divider(),
                              // A Wrap, not a Row: on a narrow screen or with
                              // large text it flows onto a second line instead
                              // of overflowing (as the welcome screen's does).
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('Tidak punya akun?'),
                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () =>
                                              context.push(RouteNames.register),
                                    // Colour comes from textButtonTheme
                                    // (AppColors.primary) rather than a
                                    // hardcoded Colors.blue, so dark mode
                                    // works.
                                    child: const Text(
                                      'Daftar disini',
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
        ),
      ),
    );
  }
}

/// "atau" divider plus a full-width, outlined "Masuk dengan Google" button.
///
/// Outlined and white, not filled, so "Sign In" above it stays the one loud
/// button on the page. Split into its own widget so the page's build method
/// stays readable, and so it can be reused on the register page later.
class _GoogleSignInSection extends StatelessWidget {
  final bool isLoading;

  const _GoogleSignInSection({required this.isLoading});

  @override
  Widget build(BuildContext context) {
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
                'atau',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),

        // The button is white in light mode and light grey in dark mode, so its
        // label needs the dark-on-light colours: LightSurfaceScope supplies
        // them, and the Builder lets the button read the theme it sets up.
        LightSurfaceScope(
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);

              return OutlinedButton(
                key: const Key('login-google-button'),
                onPressed: isLoading
                    ? null
                    : () => context.read<AuthBloc>().add(
                        const AuthGoogleIdentityRequested(),
                      ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurface,
                  // Same height as the Sign In button above it.
                  minimumSize: const Size.fromHeight(52),
                  // The same pill as Sign In.
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.grey400),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/google_logo.png',
                      width: 24,
                      height: 24,
                      // The source PNG is 3840x3840. Decoded at full size that
                      // is ~59 MB of RAM (3840 * 3840 * 4 bytes) for a 24px
                      // icon. cacheWidth decodes it at display resolution
                      // instead.
                      cacheWidth: (24 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      // The label beside it already says it.
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 12),
                    // Flexible, so the label wraps onto a second line with very
                    // large text instead of overflowing the button.
                    const Flexible(
                      child: Text(
                        'Masuk dengan Google',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
