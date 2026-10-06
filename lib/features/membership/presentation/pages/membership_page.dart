import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/core/refresh/refresh_on.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';

/// Loyalty status: points, point-earning history, and vouchers.
///
/// **No new domain or data layer needed.** [DashboardStatsEntity] — already
/// fetched by [HomeBloc] for Home's greeting header — already carries
/// `point`, `detail` (point history), and `detail2` (vouchers). This page
/// gets its own [HomeBloc] instance and fires its own fetch on mount, the
/// same page-scoped-factory pattern every tab uses, rather than sharing
/// Home's instance — the two tabs' data lifecycles are independent even
/// though the shape is identical.
class MembershipPage extends StatelessWidget {
  const MembershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
      child: const _MembershipView(),
    );
  }
}

class _MembershipView extends StatelessWidget {
  const _MembershipView();

  @override
  Widget build(BuildContext context) {
    // This tab stays alive while hidden, so it reloads when something that
    // changes the stats happens elsewhere (e.g. a bike is added).
    return RefreshOn(
      kind: DataKind.stats,
      onRefresh: (context) =>
          context.read<HomeBloc>().add(const HomeStatsRequested()),
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.primary),
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            return switch (state) {
              HomeInitial() || HomeLoading() => const Center(
                child: Column(
                  spacing: 20,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.backgroundLight),

                    Text(
                      'Loading...',
                      style: TextStyle(color: AppColors.backgroundLight),
                    ),
                  ],
                ),
              ),
              HomeError(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<HomeBloc>().add(
                        const HomeStatsRequested(),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              HomeLoaded(:final stats) => _MembershipBody(stats: stats),
            };
          },
        ),
      ),
    );
  }
}

class _MembershipBody extends StatelessWidget {
  final DashboardStatsEntity stats;

  const _MembershipBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // RefreshIndicator reacts to a *scrollable* being pulled past its top — it
    // does nothing around a plain Column, which is why wrapping the two
    // widgets directly never refreshed. So the page is a CustomScrollView with
    // one sliver the exact height of the viewport (hasScrollBody: true, no
    // content measuring): nothing actually scrolls, but AlwaysScrollable lets
    // it be pulled, so pulling anywhere on the page — the balance card
    // included — refreshes.
    //
    // Inside it the balance card keeps its natural height and the box takes ALL
    // the remaining height (Expanded), so it runs down to the bottom of the
    // page. This page's body ends where MainShell's navigation bar begins, so
    // that is already just above the bar. Only the box's own list scrolls.
    return RefreshIndicator(
      // The box's list is a second Scrollable nested under the page's, so its
      // notifications arrive one level deeper; the default (depth 0 only) would
      // ignore pulls that start inside the box.
      notificationPredicate: (notification) => notification.depth <= 1,
      onRefresh: () async =>
          context.read<HomeBloc>().add(const HomeStatsRequested()),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  // ── Point balance card ──────────────────────────────────────────
                  // Cards are white in light mode, light grey in dark — see
                  // LightSurfaceScope. The Builder makes the text styles below come
                  // from the scoped theme, not from the outer `theme`.
                  Builder(
                    builder: (context) {
                      final cardTheme = Theme.of(context);

                      return Card(
                        margin: EdgeInsets.zero,
                        // Flat, like the Profile tiles: the page behind is
                        // orange, so the white card stands out without a shadow.
                        elevation: 0,
                        child: Container(
                          width: double.infinity,
                          // A floor, not a fixed height: it grows with a larger
                          // system font instead of clipping.
                          constraints: const BoxConstraints(minHeight: 120),
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 16,
                            children: [
                              // Left: the quiet label with its QR icon, then
                              // the balance as the one hero of the card.
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 6,
                                      children: [
                                        Text(
                                          'Point Anda',
                                          style: cardTheme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.3,
                                              ),
                                        ),
                                        // Same grey as the label so it reads as
                                        // part of it. Not tappable yet — there
                                        // is no QR screen to open.
                                        const Icon(
                                          Icons.qr_code_2,
                                          size: 20,
                                          color: AppColors.grey600,
                                          semanticLabel: 'QR code',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // scaleDown: a very large balance shrinks
                                    // to fit the left side instead of
                                    // overflowing it.
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        spacing: 6,
                                        children: [
                                          Text(
                                            '${stats.point}',
                                            style: cardTheme
                                                .textTheme
                                                .displayLarge
                                                ?.copyWith(fontSize: 40),
                                          ),
                                          // Same "pts" wording as Home's
                                          // greeting chip.
                                          Text(
                                            'pts',
                                            style:
                                                cardTheme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Right: the member / loyalty icon as a quiet
                              // accent — a soft orange tint, no outline.
                              // assets/images/logo.png is still a blank
                              // placeholder (69 bytes); swap the icon for
                              // Image.asset(AssetConstants.logo) once a real
                              // logo exists.
                              Container(
                                key: const Key('member-badge'),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.card_membership,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Spacing
                  const SizedBox(height: 20),

                  // One rounded box around both the history and the voucher sections,
                  // filling the rest of the page. clipBehavior keeps the scrolling
                  // entries inside its rounded corners.
                  Expanded(
                    child: Container(
                      // margin: const EdgeInsets.all(16),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          // ── Point history ────────────────────────────────────────────────
                          Text(
                            'Point History',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (stats.detail.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No point activity yet'),
                            )
                          else
                            ...stats.detail.map(
                              (entry) => LightSurfaceScope(
                                child: Builder(
                                  builder: (context) => Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.history),
                                      title: Text(entry.pointName),
                                      subtitle: Text(entry.transDate),
                                      trailing: Text(
                                        '+${entry.pointQty}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(color: Colors.green),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // ── Vouchers ─────────────────────────────────────────────────────
                          Text('Vouchers', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (stats.detail2.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No vouchers yet'),
                            )
                          else
                            ...stats.detail2.map(
                              (voucher) => LightSurfaceScope(
                                child: Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.card_giftcard),
                                    title: Text(voucher.voucherName),
                                    subtitle: Text(
                                      '${voucher.statusVoucherMemo} · expires ${voucher.expirationDate}',
                                    ),
                                    trailing: Text(
                                      'Rp${voucher.voucherAmount.toStringAsFixed(0)}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
