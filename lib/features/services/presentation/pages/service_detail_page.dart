import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';

/// Displays full details for a single service and provides a "Book Now" button.
class ServiceDetailPage extends StatelessWidget {
  final String serviceId;

  const ServiceDetailPage({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ServicesBloc>()
        ..add(ServiceDetailRequested(serviceId)),
      child: const _ServiceDetailView(),
    );
  }
}

class _ServiceDetailView extends StatelessWidget {
  const _ServiceDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Detail')),
      body: BlocBuilder<ServicesBloc, ServicesState>(
        builder: (context, state) {
          return switch (state) {
            ServicesInitial() || ServicesLoading() =>
              const Center(child: CircularProgressIndicator()),
            ServicesError(:final message) => Center(child: Text(message)),
            ServiceDetailLoaded(:final service) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Service name
                  Text(
                    service.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  // Price and duration row
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          '₱${service.price.toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${service.durationMinutes} min'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    service.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  // Book Now button navigates to create booking with pre-selected service
                  ElevatedButton(
                    onPressed: service.isAvailable
                        ? () => context.push(RouteNames.createBooking)
                        : null,
                    child: const Text('Book Now'),
                  ),
                ],
              ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}
