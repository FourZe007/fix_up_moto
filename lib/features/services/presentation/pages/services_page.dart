import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/widgets/app_spinner.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';
import 'package:fix_up_moto/features/services/presentation/widgets/service_card.dart';

/// The "History" segment of the merged Bookings tab — past completed service
/// transactions (`BrowseTrans`, `SERVICEHISTORY`), not a bookable catalog.
///
/// **Not its own page or route** — Services has no bottom-nav tab of its own;
/// past visits and upcoming bookings are both about the member's relationship
/// with FixUp Moto, so this is embedded directly inside [BookingsPage] as one
/// half of a [TabBarView]. Reads the [ServicesBloc] [BookingsPage] provides (a
/// page-scoped factory, like every other tab's), so this segment's data is
/// independent of whatever the "My Bookings" segment is doing.
///
/// Pulling the loaded list down loads it again ([ServicesRefreshRequested]); the
/// old list stays on screen until the new one arrives.
///
/// The backend answers per bike, so everything here is about one [plateNo]; the
/// page decides which and asks the bloc for it, and this view only shows what
/// arrives (and asks again for the same plate on a retry).
///
/// [query] and [dateRange] come from [BookingsPage]'s search bar and Riwayat
/// filter panel — filtering happens here, client-side, the same pattern
/// [WorkshopListPage] already uses, since the backend call has no search or
/// date parameter to delegate to. A null [dateRange] shows every date.
class ServicesHistoryView extends StatelessWidget {
  final String query;
  final DateTimeRange? dateRange;

  /// The bike whose history this is.
  final String plateNo;

  const ServicesHistoryView({
    super.key,
    required this.plateNo,
    this.query = '',
    this.dateRange,
  });

  /// Matches on branch name, transaction number, or mechanic name — the
  /// things someone actually remembers about a past visit.
  List<ServiceEntity> _filter(List<ServiceEntity> services) {
    final q = query.toLowerCase();
    return services.where((s) {
      final matchesQuery =
          q.isEmpty ||
          s.bsName.toLowerCase().contains(q) ||
          s.transNo.toLowerCase().contains(q) ||
          s.eName.toLowerCase().contains(q);
      return matchesQuery && _withinRange(s.transDate);
    }).toList();
  }

  /// Inclusive on both ends. No range set, or an unparseable [transDateRaw],
  /// means the record isn't filtered out.
  bool _withinRange(String transDateRaw) {
    final range = dateRange;
    if (range == null) return true;
    final date = DateTime.tryParse(transDateRaw);
    if (date == null) return true;
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServicesBloc, ServicesState>(
      builder: (context, state) {
        return switch (state) {
          ServicesInitial() || ServicesLoading() => const Center(
            child: Column(
              spacing: 20,
              mainAxisSize: MainAxisSize.min,
              children: [AppSpinner(), Text('Loading...')],
            ),
          ),
          ServicesError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.read<ServicesBloc>().add(
                    ServicesListRequested(plateNo: plateNo),
                  ),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
          ServicesLoaded(:final services) => _buildList(context, services),
        };
      },
    );
  }

  /// Asks the bloc for the same bike's history again and resolves once the
  /// answer is in, so the pull indicator keeps spinning for exactly that long.
  ///
  /// It waits for a [ServicesLoaded] that is **not** [ServicesLoaded.refreshing]
  /// (the old list kept on screen meanwhile) or a [ServicesError].
  Future<void> _refresh(BuildContext context) {
    final bloc = context.read<ServicesBloc>();
    bloc.add(ServicesRefreshRequested(plateNo: plateNo));

    return bloc.stream
        .firstWhere(
          (state) =>
              state is ServicesError ||
              (state is ServicesLoaded && !state.refreshing),
          // The page closed meanwhile: nothing left to wait for.
          orElse: () => const ServicesInitial(),
        )
        .then<void>((_) {});
  }

  /// A message in the middle of the screen that can still be pulled. A pull
  /// needs something scrollable to start from, and a short message is not.
  Widget _pullableMessage(Widget message) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: message),
        ),
      ],
    );
  }

  /// The loaded history, pulled down to load it again — also when it is empty
  /// or the search leaves nothing, so a visit that was just paid for can be
  /// fetched without leaving the tab.
  Widget _buildList(BuildContext context, List<ServiceEntity> services) {
    return RefreshIndicator.adaptive(
      onRefresh: () => _refresh(context),
      child: _buildContent(context, services),
    );
  }

  Widget _buildContent(BuildContext context, List<ServiceEntity> services) {
    if (services.isEmpty) {
      return _pullableMessage(
        Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tidak ada riwayat service tersedia',
              style: TextStyle(fontSize: 14),
            ),

            OutlinedButton.icon(
              onPressed: () => context.read<ServicesBloc>().add(
                ServicesListRequested(plateNo: plateNo),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Muat ulang'),
              style: OutlinedButton.styleFrom(
                iconSize: 16,
                minimumSize: Size.zero,
                padding: const EdgeInsets.all(16),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    // This once emptied the whole list. The cause was the range it was given —
    // the page's upcoming-bookings default, tomorrow to a month ahead — which
    // no past visit can fall inside; Riwayat now has its own range, null (every
    // date) until the member picks one.
    final filtered = _filter(services);
    if (filtered.isEmpty) {
      return _pullableMessage(
        const Text(
          'Tidak ada riwayat yang cocok dengan pencarian atau tanggal',
        ),
      );
    }

    return ListView.builder(
      // Pullable even when the few visits fit on the screen.
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final service = filtered[index];
        return ServiceCard(
          service: service,
          // The record already holds its details, so it is handed over as it is
          // rather than looked up again by number.
          onTap: () => context.push(RouteNames.serviceDetail, extra: service),
        );
      },
    );
  }
}
