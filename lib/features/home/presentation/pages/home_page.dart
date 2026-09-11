import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_bloc.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_event.dart';
import 'package:fix_up_moto/features/home/presentation/bloc/home_state.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

/// Home / dashboard screen — the default tab after login.
///
/// Layout follows the approved wireframe: greeting header (name + points),
/// a workshop picker, a promo carousel, and quick-action buttons. Detailed
/// point history and vouchers live on the Membership tab instead — Home is
/// meant to be an action-oriented landing page, not a data dump.
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
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            return switch (state) {
              HomeInitial() || HomeLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              HomeError(:final message) => _ErrorView(
                message: message,
                onRetry: () =>
                    context.read<HomeBloc>().add(const HomeStatsRequested()),
              ),
              HomeLoaded(:final stats) => _HomeBody(stats: stats),
            };
          },
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final DashboardStatsEntity stats;
  const _HomeBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<HomeBloc>().add(const HomeStatsRequested()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GreetingHeader(name: stats.memberName, points: stats.point),
          const SizedBox(height: 16),
          const _WorkshopPicker(),
          const SizedBox(height: 20),
          const _PromoCarousel(),
          const SizedBox(height: 24),
          const _MainFeatures(),
        ],
      ),
    );
  }
}

/// "Hi, [name]" + point balance — both read straight from [DashboardStatsEntity],
/// already fetched by [HomeBloc]. No separate request for the greeting.
class _GreetingHeader extends StatelessWidget {
  final String name;
  final int points;

  const _GreetingHeader({required this.name, required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            // Falls back to a generic greeting if the record ever comes back
            // with a blank name, rather than showing "Hi, ".
            'Hi, ${name.isNotEmpty ? name : 'Member'}',
            style: theme.textTheme.headlineSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '$points pts',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tappable row leading to [WorkshopListPage]. Holds the chosen workshop
/// locally — nothing downstream (booking creation) consumes it yet, so this
/// is scoped to just remembering the pick for as long as Home stays mounted,
/// not persisting it or feeding it into a booking.
class _WorkshopPicker extends StatefulWidget {
  const _WorkshopPicker();

  @override
  State<_WorkshopPicker> createState() => _WorkshopPickerState();
}

class _WorkshopPickerState extends State<_WorkshopPicker> {
  WorkshopEntity? _selected;

  Future<void> _pickWorkshop() async {
    // WorkshopListPage pops itself with the tapped WorkshopEntity — see its
    // _WorkshopCard._select. A null result means the user backed out.
    final picked = await context.push<WorkshopEntity>(RouteNames.workshops);
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _pickWorkshop,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: selected == null
                    ? const Text('Select workshop from the existing list')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.bsName,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            selected.bsAddress,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Promo/discount carousel.
///
/// **Placeholder content.** There is no promotions endpoint or bundled promo
/// artwork in this project yet, so these are gradient cards with copy rather
/// than broken image references. Swapping in real banners later only means
/// replacing [_promos] with a fetched list — the carousel mechanics
/// (PageView + dot indicator) don't change.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  static const _promos = [
    (
      title: 'Book without waiting',
      subtitle: "Reserve your slot on FixUp Moto's fixed schedule",
      colors: [AppColors.primary, AppColors.primaryDark],
    ),
    (
      title: 'Earn points on every visit',
      subtitle: 'Collect points and redeem them for vouchers',
      colors: [AppColors.secondary, AppColors.secondaryDark],
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: _promos.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final promo = _promos[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: promo.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      promo.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promo.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _promos.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _page ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == _page
                    ? AppColors.primary
                    : AppColors.grey400,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Quick-action buttons: Booking and Bikes list.
///
/// Both reuse existing screens rather than opening new ones — Booking goes to
/// the merged Bookings tab, Bikes list goes to the motorcycles section
/// already on Profile.
class _MainFeatures extends StatelessWidget {
  const _MainFeatures();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FeatureButton(
            icon: Icons.calendar_month_outlined,
            label: 'Booking',
            onTap: () => context.go(RouteNames.bookings),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FeatureButton(
            icon: Icons.two_wheeler_outlined,
            label: 'Bikes List',
            onTap: () => context.go(RouteNames.profile),
          ),
        ),
      ],
    );
  }
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
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
