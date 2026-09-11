import 'package:flutter/material.dart';
import 'package:fix_up_moto/features/services/domain/entities/service_entity.dart';

/// Displays a single service transaction/history record in the list.
class ServiceCard extends StatelessWidget {
  final ServiceEntity service;
  final VoidCallback? onTap;

  const ServiceCard({super.key, required this.service, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
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
          service.bsName,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          service.transDate,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        // Total amount badge aligned to the right
        trailing: Text(
          '₱${(service.amountService + service.amountPart).toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
