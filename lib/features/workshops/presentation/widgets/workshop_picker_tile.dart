import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

/// Tappable row showing the selected workshop, or a prompt to pick one.
///
/// Shared by Home and Create Booking so both look identical — both read the
/// same [SelectedWorkshopCubit], this widget just renders whatever its
/// current state is plus whatever [onTap] should do about changing it.
class WorkshopPickerTile extends StatelessWidget {
  final WorkshopEntity? selected;
  final VoidCallback onTap;

  const WorkshopPickerTile({
    super.key,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
