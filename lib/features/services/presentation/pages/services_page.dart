import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fix_up_moto/core/di/injection_container.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_bloc.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_event.dart';
import 'package:fix_up_moto/features/services/presentation/bloc/services_state.dart';
import 'package:fix_up_moto/features/services/presentation/widgets/service_card.dart';

/// Lists all available repair services with optional category filtering.
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ServicesBloc>()
        ..add(const ServicesListRequested()),
      child: const _ServicesView(),
    );
  }
}

class _ServicesView extends StatelessWidget {
  const _ServicesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: BlocBuilder<ServicesBloc, ServicesState>(
        builder: (context, state) {
          return switch (state) {
            ServicesInitial() || ServicesLoading() =>
              const Center(child: CircularProgressIndicator()),
            ServicesError(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context
                          .read<ServicesBloc>()
                          .add(const ServicesListRequested()),
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
                          // Navigate to detail using the service ID
                          '${RouteNames.services}/detail/${service.id}',
                        ),
                      );
                    },
                  ),
            // ServiceDetailLoaded is handled on the detail page, not here
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}
