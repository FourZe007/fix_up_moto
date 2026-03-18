import 'package:flutter/material.dart';
import 'package:fix_up_moto/domain/entities/service_entity.dart';

/// Displays a single service in the services list.
class ServiceCard extends StatelessWidget {
  final ServiceEntity service;
  final VoidCallback? onTap;

  const ServiceCard({super.key, required this.service, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        // Service thumbnail — falls back to a generic icon if no image URL
        leading: service.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  service.imageUrl!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  // Show grey placeholder while image loads
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                ),
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.build_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
        title: Text(
          service.name,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          // Duration label: "45 min"
          '${service.durationMinutes} min',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        // Price badge aligned to the right
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₱${service.price.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            // Grey "Unavailable" label when the service is not bookable
            if (!service.isAvailable)
              Text(
                'Unavailable',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
