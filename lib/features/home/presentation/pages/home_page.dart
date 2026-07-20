import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/stats_card.dart';

/// Home / dashboard screen — the default tab after login.
///
/// Provides [HomeBloc] locally (not globally) since stats are only needed here.
/// Fires [HomeStatsRequested] immediately on mount to load data.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // registerFactory ensures a fresh bloc each time the page is created
      create: (_) => sl<HomeBloc>()..add(const HomeStatsRequested()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return switch (state) {
            HomeInitial() || HomeLoading() =>
              const Center(child: CircularProgressIndicator()),
            HomeError(:final message) => _ErrorView(
                message: message,
                // Retry button re-dispatches the same event
                onRetry: () =>
                    context.read<HomeBloc>().add(const HomeStatsRequested()),
              ),
            HomeLoaded(:final stats) => _StatsView(stats: stats),
          };
        },
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  final DashboardStatsEntity stats;
  const _StatsView({required this.stats});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      // Pull-to-refresh re-fetches dashboard stats
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeStatsRequested());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          // 2-column grid of stat cards
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: 'Loyalty Points',
                  value: '${stats.point}',
                  icon: Icons.star_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: 'Qty',
                  value: '${stats.qty}',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: 'Point History',
                  value: '${stats.detail.length}',
                  icon: Icons.history,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: 'Vouchers',
                  value: '${stats.detail2.length}',
                  icon: Icons.card_giftcard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
