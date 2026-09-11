import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';
import 'package:fix_up_moto/features/services/presentation/widgets/service_card.dart';

/// The "Browse" segment of the merged Bookings tab.
///
/// **Not its own page or route** — Services has no bottom-nav tab of its own;
/// browsing a service and booking it are one journey, not two, so this is
/// embedded directly inside [BookingsPage] as one half of a [TabBarView].
/// Provides its own [ServicesBloc] regardless, the same page-scoped-factory
/// pattern every other tab uses, so this segment's data is independent of
/// whatever the "My Bookings" segment is doing.
class ServicesBrowseView extends StatelessWidget {
  const ServicesBrowseView({super.key});

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
          ServicesLoaded(:final services) => services.isEmpty
              ? const Center(child: Text('No services available'))
              : ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return ServiceCard(
                      service: service,
                      onTap: () => context.push(
                        '${RouteNames.serviceDetail}/${service.transNo}',
                      ),
                    );
                  },
                ),
          // ServiceDetailLoaded is handled on the detail page, not here
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
