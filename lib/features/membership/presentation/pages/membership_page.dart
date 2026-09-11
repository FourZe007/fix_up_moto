import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return switch (state) {
            HomeInitial() || HomeLoading() => const Center(
              child: CircularProgressIndicator(),
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
    );
  }
}

class _MembershipBody extends StatelessWidget {
  final DashboardStatsEntity stats;
  const _MembershipBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<HomeBloc>().add(const HomeStatsRequested()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Point balance card ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Loyalty Points', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text('${stats.point}', style: theme.textTheme.displayLarge),
                  const SizedBox(height: 8),
                  // The server's own wording about the membership — same
                  // field the login refusal message reads.
                  Text(stats.status, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Point history ────────────────────────────────────────────────
          Text('Point History', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (stats.detail.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No point activity yet'),
            )
          else
            ...stats.detail.map(
              (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(entry.pointName),
                  subtitle: Text(entry.transDate),
                  trailing: Text(
                    '+${entry.pointQty}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.green,
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
              (voucher) => Card(
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
        ],
      ),
    );
  }
}
