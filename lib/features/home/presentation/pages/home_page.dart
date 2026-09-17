import 'dart:async';

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
import 'package:fix_up_moto/features/promos/domain/entities/promo_image_entity.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_bloc.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_event.dart';
import 'package:fix_up_moto/features/promos/presentation/bloc/promos_state.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';
import 'package:fix_up_moto/features/workshops/presentation/widgets/workshop_picker_tile.dart';

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
              HomeInitial() ||
              HomeLoading() => const Center(child: CircularProgressIndicator()),
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
          const SizedBox(height: 16),
          const _ChatWithMikaButton(),
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

/// Tappable row leading to [WorkshopListPage]. Reads/writes
/// [SelectedWorkshopCubit] — app-scoped shared state, not local — so a pick
/// made here is the same pick Create Booking's own tile shows, and vice versa.
class _WorkshopPicker extends StatelessWidget {
  const _WorkshopPicker();

  Future<void> _pickWorkshop(BuildContext context) async {
    // WorkshopListPage pops itself with the tapped WorkshopEntity — see its
    // _WorkshopCard._select. A null result means the user backed out.
    final picked = await context.push<WorkshopEntity>(RouteNames.workshops);
    if (picked != null && context.mounted) {
      context.read<SelectedWorkshopCubit>().select(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectedWorkshopCubit, WorkshopEntity?>(
      builder: (context, selected) => WorkshopPickerTile(
        selected: selected,
        onTap: () => _pickWorkshop(context),
      ),
    );
  }
}

/// Promo/discount carousel.
///
/// Banners come from `Master` (`Jenis: "IMAGEFORAPPS"`) — each record is a
/// `{Line, Base64Image}` pair, the image bytes embedded directly in the
/// response rather than a URL. Provides its own [PromosBloc] since this is
/// the only place the images are needed.
class _PromoCarousel extends StatelessWidget {
  const _PromoCarousel();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PromosBloc>()..add(const PromoImagesRequested()),
      child: const _PromoCarouselView(),
    );
  }
}

class _PromoCarouselView extends StatefulWidget {
  const _PromoCarouselView();

  @override
  State<_PromoCarouselView> createState() => _PromoCarouselViewState();
}

class _PromoCarouselViewState extends State<_PromoCarouselView> {
  static const _autoScrollInterval = Duration(seconds: 4);

  final _controller = PageController();
  final double promoHeight = 200;
  int _page = 0;
  Timer? _autoScrollTimer;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// (Re)starts the auto-scroll loop for the given image count. Called from
  /// [BlocConsumer]'s listener rather than from build, since starting a
  /// [Timer] is a side effect and build can re-run for unrelated reasons
  /// (e.g. the surrounding [HomeBloc] refreshing).
  void _restartAutoScroll(int itemCount) {
    _autoScrollTimer?.cancel();
    if (itemCount <= 1) return;

    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_controller.hasClients) return;
      _controller.animateToPage(
        (_page + 1) % itemCount,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PromosBloc, PromosState>(
      listener: (context, state) {
        if (state is PromosLoaded && state.images.isNotEmpty) {
          _restartAutoScroll(state.images.length);
        } else {
          _autoScrollTimer?.cancel();
        }
      },
      builder: (context, state) {
        return switch (state) {
          PromosInitial() || PromosLoading() => SizedBox(
            height: promoHeight,
            child: Column(
              spacing: 8,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), Text('Loading...')],
            ),
          ),
          // No promotions endpoint content to show is not worth a banner of
          // its own — the carousel just disappears rather than showing an
          // error where a placeholder used to be.
          PromosError() => const SizedBox.shrink(),
          PromosLoaded(:final images) when images.isEmpty =>
            const SizedBox.shrink(),
          PromosLoaded(:final images) => _carousel(context, images),
        };
      },
    );
  }

  Widget _carousel(BuildContext context, List<PromoImageEntity> images) {
    return Column(
      children: [
        SizedBox(
          height: promoHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: double.infinity,
                  child: Image.memory(
                    images[index].imageBytes,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _page ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == _page ? AppColors.primary : AppColors.grey400,
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

/// Full-width entry point to [ChatbotPage] — an AI-powered virtual customer
/// service chat, currently an empty placeholder (see that page's own doc
/// comment). Row layout (icon, label, chevron) rather than [_FeatureButton]'s
/// square icon-over-label shape, since it reads as a single navigation
/// action rather than one of a matched pair.
class _ChatWithMikaButton extends StatelessWidget {
  const _ChatWithMikaButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(RouteNames.chatbot),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chat with Mika',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
