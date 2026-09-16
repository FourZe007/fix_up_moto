import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/go_router_refresh_stream.dart';
import 'package:fix_up_moto/core/widgets/splash_page.dart';
import 'package:fix_up_moto/features/auth/domain/entities/google_account_identity.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/complete_google_profile_page.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/login_page.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/register_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/bookings_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:fix_up_moto/features/feeds/presentation/pages/feeds_page.dart';
import 'package:fix_up_moto/features/home/presentation/pages/home_page.dart';
import 'package:fix_up_moto/features/membership/presentation/pages/membership_page.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/add_motorcycle_page.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/profile_page.dart';
import 'package:fix_up_moto/features/services/presentation/pages/service_detail_page.dart';
import 'package:fix_up_moto/features/workshops/presentation/pages/workshop_list_page.dart';
import 'package:fix_up_moto/core/widgets/main_shell.dart';
import 'package:fix_up_moto/core/router/route_names.dart';

/// Centralised GoRouter configuration for the entire app.
///
/// Key behaviours:
/// - **Auth guard**: the [redirect] callback inspects [AuthBloc] state before
///   every navigation event; unauthenticated users are sent to login,
///   authenticated users are prevented from re-entering the login screen.
/// - **Shell route**: the five main tabs (home, bookings, membership, feeds,
///   profile) live inside a [ShellRoute] that renders [MainShell], keeping
///   the bottom navigation bar persistent across tab switches. Services has
///   no tab of its own — its past-transaction history lives inside the
///   Bookings tab instead.
/// - **Nested routes**: service detail is a deep child so it inherits the
///   shell's scaffold. Create-booking is the opposite on purpose — a
///   top-level route outside the ShellRoute, so it renders full-screen
///   without the bottom nav bar attached.
class AppRouter {
  AppRouter._(); // static-only class — never instantiated

  static final GoRouter router = GoRouter(
    // Opens on the splash route, which exists purely to hold the frame while
    // AuthBloc restores any cached session. The redirect below moves off it.
    initialLocation: RouteNames.splash,

    // ── Re-evaluate the guard when auth state changes ───────────────────────
    // Without this the redirect below runs exactly once at startup, against a
    // state that has not resolved yet, and is never consulted again — which
    // left an unauthenticated launch sitting on the dashboard.
    refreshListenable: GoRouterRefreshStream(sl<AuthBloc>().stream),

    // ── Authentication Guard ────────────────────────────────────────────────
    // Runs on every navigation AND every AuthBloc emission. Returns a redirect
    // path string, or null to proceed.
    redirect: (BuildContext context, GoRouterState state) {
      // Read the bloc from the service locator rather than the context:
      // AuthBloc is a lazy singleton, so this cannot resolve a different
      // instance than the UI, and it does not depend on where the router sits
      // relative to the provider in the widget tree.
      final authState = sl<AuthBloc>().state;

      final currentPath = state.matchedLocation;
      final onSplash = currentPath == RouteNames.splash;
      final onCompleteGoogleProfile =
          currentPath == RouteNames.completeGoogleProfile;
      final onAuthRoute =
          currentPath == RouteNames.login ||
          currentPath == RouteNames.register ||
          // No backend session exists while this page is on screen — it must
          // be reachable while unauthenticated, same as login/register, or
          // the guard would bounce the user straight back to /login the
          // instant AuthGoogleIdentityObtained navigates them here.
          onCompleteGoogleProfile;

      // The complete-profile page needs a GoogleAccountIdentity passed
      // through `extra`. `extra` is an in-memory-only value — it is never
      // part of the URL and cannot survive a process restart, which Android
      // can trigger by recreating the app's Activity while Google's account
      // picker briefly takes the foreground. When that happens GoRouter tries
      // to restore this same path with no `extra` at all, and the page's
      // `state.extra as GoogleAccountIdentity` cast would crash with a
      // TypeError. Catch it here instead and send the user back to sign in
      // again rather than crash.
      if (onCompleteGoogleProfile && state.extra is! GoogleAccountIdentity) {
        return RouteNames.login;
      }

      // Cold start, session check still running. AuthInitial means *only* this
      // — AuthBloc deliberately does not emit AuthLoading during the check.
      if (authState is AuthInitial) {
        return onSplash ? null : RouteNames.splash;
      }

      // Live session — bounce off splash and the auth routes, allow the rest.
      if (authState is AuthAuthenticated) {
        return (onSplash || onAuthRoute) ? RouteNames.home : null;
      }

      // An operation is in flight (login / logout / register). Leave the user
      // exactly where they are; moving them now would yank the login form out
      // from under them mid-request. This arm must stay below the
      // authenticated check so a completed login is handled above.
      if (authState is AuthLoading) return null;

      // Unauthenticated — the only pages reachable are the auth ones.
      return onAuthRoute ? null : RouteNames.login;
    },

    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(path: RouteNames.splash, builder: (_, _) => const SplashPage()),

      // ── Public routes ─────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.login,
        // pageBuilder gives a fade transition instead of the default slide
        pageBuilder: (_, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginPage(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (_, _) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteNames.completeGoogleProfile,
        // The identity travels via `extra` rather than query parameters —
        // it's a plain in-memory value from this same session, never a URL
        // a user could type or a deep link that needs to survive a cold start.
        builder: (_, state) {
          // Belt-and-braces: the redirect guard above already sends the user
          // to /login before this builder runs without a valid identity, so
          // in normal operation `state.extra` is always a GoogleAccountIdentity
          // here. `as?` (safe cast) with a fallback means that if this route
          // is ever reached some other way — a widget test building it
          // directly, or a future code path that bypasses the guard — it
          // degrades to an empty identity instead of throwing a TypeError.
          final identity =
              state.extra as GoogleAccountIdentity? ??
              const GoogleAccountIdentity(email: '');
          return CompleteGoogleProfilePage(identity: identity);
        },
      ),

      // Deliberately top-level routes, not nested under any ShellRoute
      // branch — both render full-screen with no bottom nav bar attached,
      // unlike ServiceDetailPage which stays inside the shell on purpose.
      // Still protected by the redirect guard above like any other non-auth
      // route.
      GoRoute(
        path: RouteNames.createBooking,
        builder: (_, _) => const CreateBookingPage(),
      ),
      // Reached from both Home's picker and Create Booking's — it used to be
      // nested under /home on the assumption only Home would ever push it,
      // which broke the moment Create Booking (a route outside the shell
      // entirely) started pushing the same path: GoRouter had to rebuild
      // Home's whole branch to resolve /home/workshops, colliding with the
      // Home page instance already sitting in the Navigator and tripping a
      // Flutter-internal key assertion. Top-level avoids that ancestry
      // entirely, the same reasoning as createBooking above.
      GoRoute(
        path: RouteNames.workshops,
        builder: (_, _) => const WorkshopListPage(),
      ),

      // ── Shell route: main tabs with persistent bottom nav bar ──────────────
      ShellRoute(
        // MainShell wraps every tab page; receives the active tab as [child]
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (_, _) => const HomePage(),
          ),
          GoRoute(
            path: RouteNames.bookings,
            builder: (_, _) => const BookingsPage(),
            routes: [
              // Services has no tab of its own — its history lives in the
              // "History" segment of this tab instead — but the detail
              // screen still needs its own route to push to. Nested here
              // (not under a standalone /services) so it sits above Bookings
              // in the back stack and stays inside the shell scaffold.
              GoRoute(
                path:
                    'services/detail/:id', // full path: /bookings/services/detail/:id
                builder: (_, state) =>
                    ServiceDetailPage(serviceId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.membership,
            builder: (_, _) => const MembershipPage(),
          ),
          GoRoute(path: RouteNames.feeds, builder: (_, _) => const FeedsPage()),
          GoRoute(
            path: RouteNames.profile,
            builder: (_, _) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'motorcycle/add', // full path: /profile/motorcycle/add
                builder: (_, _) => const AddMotorcyclePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
