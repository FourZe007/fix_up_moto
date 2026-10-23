import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/helpers/external_link.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/widgets/confirm_panel_scope.dart';
import 'package:fix_up_moto/core/widgets/profile_avatar.dart';
import 'package:fix_up_moto/core/widgets/warm_section.dart';
import 'package:fix_up_moto/core/widgets/warm_wash.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fix_up_moto/features/auth/presentation/bloc/auth_event.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/notification/presentation/cubit/notification_count_cubit.dart';
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
    // The icon colour comes from the active Theme rather than an AppColors
    // constant, so this bar follows light/dark automatically when ThemeCubit
    // changes MaterialApp's themeMode — no cubit read needed here. The icons
    // are coloured explicitly because the app's AppBarTheme hard-codes a white
    // title style.
    // Light and Dark mode disabled temporary, but the codes still exist inside
    // the project
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return BlocProvider(
      // Page-scoped factory, fetched on mount — same as MembershipPage.
      create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
      // This tab stays alive while hidden, so it reloads when something that
      // changes the stats happens elsewhere (e.g. a bike is added).
      child: RefreshOn(
        kind: DataKind.stats,
        onRefresh: (context) =>
            context.read<HomeBloc>().add(const HomeStatsRequested()),
        // Hosts the confirmation panels (sign out, delete profile): they slide
        // up in the root Overlay, above this Scaffold and the bottom bar.
        child: ConfirmPanelScope(child: _scaffold(context, onSurface)),
      ),
    );
  }

  Widget _scaffold(BuildContext context, Color onSurface) {
    // The page keeps its theme background; a warm wash fades in from the top.
    // The wash is a fixed backdrop *around* the Scaffold, whose own background
    // and AppBar are transparent: it shows behind the bar, and the rows scroll
    // below the bar rather than under its icons.
    return WarmWash(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          // title: const Text('Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 20,
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.settings_outlined),
          //     style: IconButton.styleFrom(foregroundColor: onSurface),
          //     tooltip: 'Settings',
          //     // push, not go: go would replace the whole back stack, leaving
          //     // Settings with no way back to Profile.
          //     onPressed: () => context.push(RouteNames.settings),
          //   ),
          //   IconButton(
          //     icon: const Icon(Icons.logout),
          //     style: IconButton.styleFrom(foregroundColor: onSurface),
          //     tooltip: 'Sign out',
          //     onPressed: () => _confirmLogout(context),
          //   ),
          // ],
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
                    onPressed: () => context.read<HomeBloc>().add(
                      const HomeStatsRequested(),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            HomeLoaded(:final stats) => _ProfileBody(stats: stats),
          },
        ),
      ),
    );
  }
}

/// Asks before deleting the profile, in the same panel as sign out.
///
/// Confirming does nothing yet: no delete endpoint is wired (`ModifyMode.delete`
/// exists but nothing calls it), so the panel is ready for when one is.
Future<void> _confirmDeleteProfile(BuildContext context) async {
  final confirmed = await ConfirmPanelScope.of(context).confirm(
    icon: Icons.delete,
    title: 'Hapus Profile',
    message:
        'Yakin ingin menghapus profile ini? Tindakan ini tidak dapat '
        'dibatalkan.',
    confirmLabel: 'Hapus',
    destructive: true,
  );
  if (!confirmed) return;
  // The delete call goes here once it exists.
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
    // The theme's body grey is too pale on the warm wash behind the header
    // (about 3.7:1), so the light theme uses a darker one (5:1); the dark
    // theme's own light text is already fine on black.
    final contactStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.brightness == Brightness.dark ? null : AppColors.grey700,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Row(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar — initial only; the stats record has no photo.
                  ProfileAvatar(
                    key: const Key('profile-avatar'),
                    name: stats.memberName,
                  ),

                  // User profile
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      Text(
                        stats.memberName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_hasValue(stats.phoneNo))
                        Text('0${stats.phoneNo}', style: contactStyle),
                      if (_hasValue(stats.emailAddress))
                        Text(stats.emailAddress, style: contactStyle),
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

        // The page is three titled groups, each one rounded card with its rows
        // split by hairlines, not a stack of separate cards.

        // ── Akun ──────────────────────────────────────────────────────────
        const SectionHeader('Akun'),
        SectionCard(
          children: [
            ActionRow(
              key: const Key('edit-profile'),
              name: 'Edit Profile',
              icon: Icon(Icons.edit, color: AppColors.primary, size: 20),
              // push, so back returns to Profile.
              onPressed: () => context.push(RouteNames.editProfile),
            ),
            // The balance sits in the row as a value. Member is a tab, where go
            // is right.
            ActionRow(
              key: const Key('points-row'),
              name: 'Point & Voucher',
              icon: Icon(
                Icons.star_outline,
                color: AppColors.primary,
                size: 20,
              ),
              value: '${stats.point} pts',
              onPressed: () => context.go(RouteNames.membership),
            ),
            // Notifications: the same page Home's bell opens, with the same
            // unread count (both read NotificationCountCubit). push, so back
            // returns to Profile.
            ActionRow(
              key: const Key('notification-card'),
              name: 'Kotak Masuk',
              icon: Icon(
                Icons.notifications_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => context.push(RouteNames.notification),
              // Hidden at 0, so the row is just a label and a chevron until
              // there is something unread.
              trailing: BlocBuilder<NotificationCountCubit, int>(
                builder: (context, count) => Badge(
                  isLabelVisible: count > 0,
                  label: Text(NotificationCountCubit.label(count)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Garasi ────────────────────────────────────────────────────────
        // The member's bikes and what was done to them. The bike count sits in
        // its row as a value: with the points (in Akun) it replaced the two
        // stat tiles that used to head the page. Point & Voucher is not here —
        // a garage holds bikes, and points are a membership benefit.
        const SectionHeader('Garasi'),
        SectionCard(
          children: [
            // My Bikes is a top-level route, so push: go would replace the
            // whole back stack.
            ActionRow(
              key: const Key('my-bikes-row'),
              name: 'Motor Saya',
              icon: Icon(
                Icons.two_wheeler_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              value: '${stats.qty}',
              onPressed: () => context.push(RouteNames.myBikes),
            ),
            // Bookings is a tab, where go is right.
            ActionRow(
              key: const Key('bookings-row'),
              name: 'Riwayat Booking',
              icon: Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => context.go(RouteNames.bookings),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── FixUp Moto ────────────────────────────────────────────────────
        const SectionHeader('FixUp Moto'),
        SectionCard(
          children: [
            ActionRow(
              key: const Key('whatsapp-service'),
              name: 'Layanan Whatsapp',
              icon: FaIcon(
                FontAwesomeIcons.whatsapp,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: () => openExternalLink(
                context,
                AppConstants.whatsappServiceUrl,
                failureMessage: 'WhatsApp tidak dapat dibuka',
              ),
            ),
            // A page whose address is not set yet is left out.
            if (AppConstants.instagramUrl.trim().isNotEmpty)
              ActionRow(
                key: const Key('instagram-link'),
                name: 'Instagram',
                icon: FaIcon(
                  FontAwesomeIcons.instagram,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () => openExternalLink(
                  context,
                  AppConstants.instagramUrl,
                  failureMessage: 'Instagram tidak dapat dibuka',
                ),
              ),
            if (AppConstants.tiktokUrl.trim().isNotEmpty)
              ActionRow(
                key: const Key('tiktok-link'),
                name: 'TikTok',
                icon: FaIcon(
                  FontAwesomeIcons.tiktok,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () => openExternalLink(
                  context,
                  AppConstants.tiktokUrl,
                  failureMessage: 'TikTok tidak dapat dibuka',
                ),
              ),
            ActionRow(
              key: const Key('privacy-policy'),
              name: 'Kebijakan Privasi',
              icon: Icon(
                Icons.menu_book_sharp,
                color: AppColors.primary,
                size: 20,
              ),
              // push, so back returns to Profile.
              onPressed: () => context.push(RouteNames.privacyPolicy),
            ),
            // ActionRow(
            //   key: const Key('terms-of-service'),
            //   name: 'Ketentuan Layanan',
            //   icon: Icon(
            //     Icons.info_outline_rounded,
            //     color: AppColors.primary,
            //     size: 20,
            //   ),
            //   onPressed: () {},
            // ),
          ],
        ),

        const SizedBox(height: 20),

        // Apart from the groups: it ends the account rather than opening
        // something. It asks first, but confirming does nothing yet — no delete
        // endpoint is wired.
        SectionCard(
          children: [
            ActionRow(
              key: const Key('delete-profile'),
              name: 'Hapus Profile',
              destructive: true,
              icon: Icon(Icons.delete, color: AppColors.error, size: 20),
              onPressed: () => _confirmDeleteProfile(context),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // The way out of the session. Below Hapus Profile, but a different kind
        // of action: brand-coloured and outlined rather than red.
        const _SignOutButton(),

        const SizedBox(height: 20),

        Center(child: Text('Versi Aplikasi 2.0.0')),

        // const Divider(),

        // // This section is just a shortcut into the dedicated MyBikesPage now
        // // (see its own BikesBloc) — this placeholder never loaded a real list
        // // itself.
        // ListTile(
        //   title: Text('My Bikes', style: theme.textTheme.titleMedium),
        //   trailing: IconButton(
        //     icon: const Icon(Icons.add),
        //     onPressed: () => context.push(RouteNames.addBike),
        //   ),
        // ),
        // const Padding(
        //   padding: EdgeInsets.all(16),
        //   child: Text('Belum ada motor terdaftar'),
        // ),
      ],
    );
  }
}

/// The full-width Keluar button at the foot of the page. Asks for confirmation
/// in the page's [ConfirmPanelScope], then signs the member out through
/// [AuthBloc].
///
/// Outlined in the same dark red (light orange in dark mode) as the group
/// headings, with the section cards' 12 px corners, so it sits with the rest of
/// the page but stays apart from the red Hapus Profile row above it.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  Future<void> _signOut(BuildContext context) async {
    // Resolve both BEFORE the await. Reaching for either afterwards would mean
    // touching a BuildContext across the panel's dismissal.
    final authBloc = context.read<AuthBloc>();
    final panel = ConfirmPanelScope.of(context);

    final confirmed = await panel.confirm(
      icon: Icons.logout,
      title: 'Keluar',
      message: 'Yakin ingin keluar dari akun ini?',
      confirmLabel: 'Keluar',
    );
    if (!confirmed) return;

    // No navigation here on purpose. AuthBloc emits AuthUnauthenticated,
    // GoRouterRefreshStream notifies the router, and the redirect guard sends
    // the user to /login. The panel has finished closing by now.
    authBloc.add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Same pairing as SectionHeader: the dark red passes on the light page, the
    // light orange on the dark theme's black one.
    final color = theme.brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primaryDark;

    return OutlinedButton.icon(
      key: const Key('sign-out'),
      onPressed: () => _signOut(context),
      icon: const Icon(Icons.logout, size: 20),
      label: const Text('Keluar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
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
