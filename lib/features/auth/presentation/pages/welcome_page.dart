import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/auth_logo.dart';
import 'package:fix_up_moto/features/auth/presentation/widgets/welcome_feature_carousel.dart';

/// The front door for everyone who is logged out: the logo, what the app does,
/// and two ways on — "Get started" to register, or "Masuk" for members who
/// already have an account.
///
/// [AppRouter] sends every logged-out state here first (a cold start with no
/// session, a logout, an expired session). It holds no state and reads no BLoC.
///
/// Layout: the logo, headline and feature carousel scroll as one block, spaced
/// out to fill a tall screen; the buttons are pinned below it, so they are on
/// screen on a short phone or with large text too.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // SliverFillRemaining(hasScrollBody: false) makes this block at
              // least as tall as the viewport — so the Spacers can spread it
              // out on a tall phone — and lets it scroll when it is taller.
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Each gap is a fixed minimum plus a share of
                          // whatever room is left: on a tall phone the Spacers
                          // spread the content out, and on a short one they
                          // collapse but the minimums keep it from bunching up.
                          const SizedBox(height: 32),
                          const Spacer(flex: 2),

                          // ── Logo over a soft red glow ───────────────────
                          const Center(child: _Hero()),

                          const SizedBox(height: 32),
                          const Spacer(flex: 2),

                          // ── What the app is, and does ───────────────────
                          _Reveal(
                            start: 0.35,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Servis motor jadi lebih mudah & terpercaya',
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Booking bengkel, kumpulkan poin, dan chat '
                                  'dengan Mika dalam satu aplikasi.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 28),
                                // Full-width cards that swipe and advance on
                                // their own — see WelcomeFeatureCarousel.
                                const WelcomeFeatureCarousel(),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pinned actions ──────────────────────────────────────────────
            _Reveal(start: 0.6, child: const _Actions()),
          ],
        ),
      ),
    );
  }
}

/// The logo, drawn large, over a soft glow in its own red.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      // The glow is bigger than the logo that sizes this Stack, and is meant
      // to spill past it.
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -60,
          right: -60,
          top: -110,
          bottom: -110,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AuthLogo.red.withValues(alpha: 0.14),
                    // Same red, not Colors.transparent (transparent black),
                    // which would grey the fade out.
                    AuthLogo.red.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        const AuthLogo(width: 200),
      ],
    );
  }
}

/// "Get started" at full width, with the way in for existing members under it.
class _Actions extends StatelessWidget {
  const _Actions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // push(), not go(): the welcome screen is the root, and Login and
          // Register show a back arrow that returns to it.
          ElevatedButton(
            key: const Key('welcome-get-started'),
            onPressed: () => context.push(RouteNames.register),
            style: ElevatedButton.styleFrom(
              // The same pill as the Sign In button.
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: const Text('Get started'),
          ),
          // A Wrap, not a Row: it flows onto a second line on a narrow screen
          // or with large text instead of overflowing.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Sudah punya akun?'),
              TextButton(
                key: const Key('welcome-login'),
                onPressed: () => context.push(RouteNames.login),
                // Colour comes from textButtonTheme, so dark mode works.
                child: const Text(
                  'Masuk',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fades [child] in and lifts it a few pixels, starting [start] of the way
/// through a shared 900 ms entrance — so the logo (which animates itself),
/// then the text and tiles, then the buttons arrive one after another.
/// Skipped when the OS asks for no animations.
class _Reveal extends StatelessWidget {
  final double start;
  final Widget child;

  const _Reveal({required this.start, required this.child});

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 900);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
