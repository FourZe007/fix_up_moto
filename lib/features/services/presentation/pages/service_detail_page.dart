import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';

/// Displays full details for a single service transaction record.
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
                  // Branch name
                  Text(
                    service.bsName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  // Transaction number and date row
                  Row(
                    children: [
                      Chip(label: Text(service.transNo)),
                      const SizedBox(width: 8),
                      Chip(label: Text(service.transDate)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mechanic: ${service.eName}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (service.detail.isNotEmpty) ...[
                    Text(
                      'Services',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...service.detail.map(
                      (line) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.serviceName),
                        subtitle: line.serviceNote.trim().isEmpty
                            ? null
                            : Text(line.serviceNote),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (service.detail2.isNotEmpty) ...[
                    Text(
                      'Parts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...service.detail2.map(
                      (part) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(part.itemName),
                        trailing: Text('x${part.qty}'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Total: ₱${(service.amountService + service.amountPart).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.push(RouteNames.createBooking),
                    child: const Text('Book Again'),
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
