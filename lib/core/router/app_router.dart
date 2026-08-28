import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/go_router_refresh_stream.dart';
import 'package:fix_up_moto/core/widgets/splash_page.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_state.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/login_page.dart';
import 'package:fix_up_moto/features/auth/presentation/pages/register_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/bookings_page.dart';
import 'package:fix_up_moto/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:fix_up_moto/features/home/presentation/pages/home_page.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/add_motorcycle_page.dart';
import 'package:fix_up_moto/features/profile/presentation/pages/profile_page.dart';
import 'package:fix_up_moto/features/services/presentation/pages/service_detail_page.dart';
import 'package:fix_up_moto/features/services/presentation/pages/services_page.dart';
import 'package:fix_up_moto/core/widgets/main_shell.dart';
import 'package:fix_up_moto/core/router/route_names.dart';

/// Centralised GoRouter configuration for the entire app.
///
/// Key behaviours:
/// - **Auth guard**: the [redirect] callback inspects [AuthBloc] state before
///   every navigation event; unauthenticated users are sent to login,
///   authenticated users are prevented from re-entering the login screen.
/// - **Shell route**: the four main tabs (home, services, bookings, profile)
///   live inside a [ShellRoute] that renders [MainShell], keeping the bottom
///   navigation bar persistent across tab switches.
/// - **Nested routes**: service detail and create-booking screens are deep
///   children so they inherit the shell's scaffold.
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
      final onAuthRoute =
          currentPath == RouteNames.login ||
          currentPath == RouteNames.register;

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
      GoRoute(
        path: RouteNames.splash,
        builder: (_, _) => const SplashPage(),
      ),

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
            path: RouteNames.services,
            builder: (_, _) => const ServicesPage(),
            routes: [
              // Detail screen is a child of /services so it sits above it in
              // the back stack and still inside the shell scaffold
              GoRoute(
                path: 'detail/:id', // full path: /services/detail/:id
                builder: (_, state) => ServiceDetailPage(
                  serviceId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: RouteNames.bookings,
            builder: (_, _) => const BookingsPage(),
            routes: [
              GoRoute(
                path: 'create', // full path: /bookings/create
                builder: (_, _) => const CreateBookingPage(),
              ),
            ],
          ),
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
