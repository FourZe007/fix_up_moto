import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_bloc.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_event.dart';
import 'package:fix_up_moto/features/profile/presentation/bloc/bikes_state.dart';

/// Shows the signed-in member and the sign-out action.
///
/// The member's details come from the dashboard stats record ([HomeBloc]) —
/// the same `BrowseTrans` record Home and Membership read, which carries the
/// real phone number — not from the cached login record, which has none.
/// [AuthBloc] is only used here to sign out. `ProfileBloc` stays registered in
/// the DI container for when the `BrowseMember` endpoint is confirmed.
class ProfilePage extends StatelessWidget {
  /// Whether the Settings button is shown. Hidden for now along with the
  /// theme switch it leads to (see [AppConstants.themeSwitchEnabled]); the
  /// Settings page and its route are still in place.
  // final bool showSettings;

  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Both colours come from the active Theme rather than AppColors constants,
    // so this bar follows light/dark automatically when ThemeCubit changes
    // MaterialApp's themeMode — no cubit read needed here. The title and arrow
    // are coloured explicitly because the app's AppBarTheme hard-codes a white
    // title style.
    // Light and Dark mode disabled temporary, but the codes still exist inside
    // the project
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return BlocProvider(
      // Page-scoped factory, fetched on mount — same as MembershipPage.
      create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
      // This tab stays alive while hidden, so it reloads when something that
      // changes the stats happens elsewhere (e.g. a bike is added).
      child: RefreshOn(
        kind: DataKind.stats,
        onRefresh: (context) =>
            context.read<HomeBloc>().add(const HomeStatsRequested()),
        child: _scaffold(context, theme, onSurface),
      ),
    );
  }

  Widget _scaffold(BuildContext context, ThemeData theme, Color onSurface) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Profile'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            style: IconButton.styleFrom(foregroundColor: onSurface),
            tooltip: 'Settings',
            // push, not go: go would replace the whole back stack, leaving
            // Settings with no way back to Profile.
            onPressed: () => context.push(RouteNames.settings),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            style: IconButton.styleFrom(foregroundColor: onSurface),
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) => switch (state) {
          HomeInitial() ||
          HomeLoading() => const Center(child: CircularProgressIndicator()),
          HomeError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Text(message),
                ElevatedButton(
                  onPressed: () =>
                      context.read<HomeBloc>().add(const HomeStatsRequested()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          HomeLoaded(:final stats) => _ProfileBody(stats: stats),
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    // Resolve the bloc BEFORE opening the dialog. Reaching for it afterwards
    // would mean touching a BuildContext across the dialog's dismissal.
    final authBloc = context.read<AuthBloc>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);

              // No navigation here on purpose. AuthBloc emits
              // AuthUnauthenticated, GoRouterRefreshStream notifies the router,
              // and the redirect guard sends the user to /login.
              authBloc.add(const AuthLogoutRequested());
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// The backend sends `-` (or nothing) for a field the member never filled in.
bool _hasValue(String value) {
  final trimmed = value.trim();
  return trimmed.isNotEmpty && trimmed != '-';
}

class _ProfileBody extends StatelessWidget {
  final DashboardStatsEntity stats;

  const _ProfileBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Row(
                spacing: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar — initial only; the stats record has no photo.
                  CircleAvatar(
                    radius: 40,
                    child: Text(
                      stats.memberName.isNotEmpty
                          ? stats.memberName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),

                  // User profile
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      Text(
                        stats.memberName,
                        style: theme.textTheme.headlineSmall,
                      ),
                      if (_hasValue(stats.phoneNo))
                        Text(
                          '0${stats.phoneNo}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (_hasValue(stats.emailAddress))
                        Text(
                          stats.emailAddress,
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ],
              ),
              // const SizedBox(height: 12),
              // Text(user.name, style: theme.textTheme.headlineSmall),

              // The backend's own wording about the membership — the same field
              // that explains a refused sign-in.
              // Text(user.status, style: theme.textTheme.bodyMedium),

              // Both absent from the SAMP member record today, so only shown
              // once an endpoint actually provides them.
              // if (user.phone != null)
              //   Text(user.phone!, style: theme.textTheme.bodyMedium),
              // if (user.email != null)
              //   Text(user.email!, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Two compact stat tiles. Their height comes from padding + content,
        // not a fixed `height`, so a larger system font grows the tile
        // instead of clipping it.
        Row(
          spacing: 12,
          children: [
            // Total Registered Bikes → My Bikes. push, not go: My Bikes is a
            // top-level route and go would replace the whole back stack.
            Expanded(
              // child: _BikeStatTile(
              //   onTap: () => context.push(RouteNames.myBikes),
              // ),
              child: _StatTile(
                key: const Key('bike-count-column'),
                icon: Icons.two_wheeler_outlined,
                label: 'My Bikes',
                onTap: () => context.push(RouteNames.myBikes),
                value: Text('${stats.qty}'),
              ),
            ),

            // Total Points → Member tab (a tab switch, where go is right).
            // The value stays a dash until its data source is chosen.
            Expanded(
              child: _StatTile(
                key: const Key('points-stat-tile'),
                icon: Icons.star_outline,
                label: 'Points',
                onTap: () => context.go(RouteNames.membership),
                value: Text('${stats.point}'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        const Divider(),

        // This section is just a shortcut into the dedicated MyBikesPage now
        // (see its own BikesBloc) — this placeholder never loaded a real list
        // itself.
        ListTile(
          title: Text('My Bikes', style: theme.textTheme.titleMedium),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(RouteNames.addBike),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Belum ada motor terdaftar'),
        ),
      ],
    );
  }
}

/// One compact stat shortcut: icon beside a value over a label, with a
/// chevron — the whole tile is the tap target.
///
/// [value] is built without any text style; it picks up the bold value style
/// set here, so callers don't need the theme (which, inside the
/// [LightSurfaceScope], isn't the one their own `context` sees).
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Widget value;
  final String label;
  final VoidCallback onTap;

  const _StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // White (light grey in dark) surface, so in dark mode the text needs the
    // light theme's dark colours too.
    return LightSurfaceScope(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.grey200),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  spacing: 10,
                  children: [
                    Icon(icon, color: AppColors.primary, size: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // minHeight, not height: keeps the tile from
                          // jumping when the spinner becomes the number,
                          // without clipping at a larger font size.
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 22),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: DefaultTextStyle.merge(
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                child: value,
                              ),
                            ),
                          ),
                          Text(label, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.grey400,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Total Registered Bikes": the count is the length of the same list the My
/// Bikes page shows, so the two can't disagree. It owns a page-scoped
/// [BikesBloc], the same pattern every other page uses, so [ProfilePage]
/// itself doesn't need one.
// class _BikeStatTile extends StatelessWidget {
//   final VoidCallback onTap;
//
//   const _BikeStatTile({required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (_) => sl<BikesBloc>()..add(const BikesLoadRequested()),
//       child: _StatTile(
//         key: const Key('bike-count-column'),
//         icon: Icons.two_wheeler_outlined,
//         label: 'My Bikes',
//         onTap: onTap,
//         value: BlocBuilder<BikesBloc, BikesState>(
//           builder: (context, state) => switch (state) {
//             BikesLoaded(:final bikes) => Text('${bikes.length}'),
//             BikesError() => const Text('–'),
//             BikesInitial() || BikesLoading() || BikesAdded() => const SizedBox(
//               width: 16,
//               height: 16,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             ),
//           },
//         ),
//       ),
//     );
//   }
// }
