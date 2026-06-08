import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/presentation/blocs/auth_bloc.dart';
import 'package:fix_up_moto/presentation/blocs/auth_state.dart';
import 'package:fix_up_moto/presentation/screens/login_page.dart';
import 'package:fix_up_moto/presentation/screens/register_page.dart';
import 'package:fix_up_moto/presentation/screens/bookings_page.dart';
import 'package:fix_up_moto/presentation/screens/create_booking_page.dart';
import 'package:fix_up_moto/presentation/screens/home_page.dart';
import 'package:fix_up_moto/presentation/screens/add_motorcycle_page.dart';
import 'package:fix_up_moto/presentation/screens/profile_page.dart';
import 'package:fix_up_moto/presentation/screens/service_detail_page.dart';
import 'package:fix_up_moto/presentation/screens/services_page.dart';
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
    // App opens on home; the redirect will push to login if unauthenticated
    initialLocation: RouteNames.home,

    // ── Authentication Guard ────────────────────────────────────────────────
    // Runs before every navigation. Returns a redirect path string, or null
    // to proceed normally.
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthBloc>().state;

      // True only when the user has a confirmed, live session
      final isAuthenticated = authState is AuthAuthenticated;

      // True while session check is still in progress (app cold start)
      final isLoading = authState is AuthLoading || authState is AuthInitial;

      final currentPath = state.matchedLocation;
      final isOnAuthRoute =
          currentPath == RouteNames.login ||
          currentPath == RouteNames.register;

      // Don't redirect while we're still checking the cached session —
      // prevents a flash-of-login-screen on every launch
      if (isLoading) return null;

      // Unauthenticated user trying to access a protected route → login
      if (!isAuthenticated && !isOnAuthRoute) return RouteNames.login;

      // Authenticated user landing on login/register → push to home
      if (isAuthenticated && isOnAuthRoute) return RouteNames.home;

      // No redirect needed — proceed to the requested route
      return null;
    },

    routes: [
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
