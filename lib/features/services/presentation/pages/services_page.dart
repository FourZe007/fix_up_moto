import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
/// half of a [TabBarView]. Provides its own [ServicesBloc] regardless, the
/// same page-scoped-factory pattern every other tab uses, so this segment's
/// data is independent of whatever the "My Bookings" segment is doing.
///
/// [query] and [dateRange] come from [BookingsPage]'s shared search bar and
/// filter panel — filtering happens here, client-side, the same pattern
/// [WorkshopListPage] already uses, since the backend `getServices` call has
/// no search parameter to delegate to.
class ServicesHistoryView extends StatelessWidget {
  final String query;
  final DateTimeRange? dateRange;

  const ServicesHistoryView({super.key, this.query = '', this.dateRange});

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
            child: CircularProgressIndicator(),
          ),
          ServicesError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.read<ServicesBloc>().add(
                    const ServicesListRequested(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          ServicesLoaded(:final services) => _buildList(context, services),
          // ServiceDetailLoaded is handled on the detail page, not here
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildList(BuildContext context, List<ServiceEntity> services) {
    if (services.isEmpty) {
      return const Center(child: Text('No services available'));
    }

    final filtered = _filter(services);
    if (filtered.isEmpty) {
      return const Center(child: Text('No services match your search'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final service = filtered[index];
        return ServiceCard(
          service: service,
          onTap: () =>
              context.push('${RouteNames.serviceDetail}/${service.transNo}'),
        );
      },
    );
  }
}
