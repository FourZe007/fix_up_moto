import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';

/// The peach card on Home that points a new member at their next first task
/// (add a bike, make a booking): an icon, a title, one line saying why, and a
/// chevron. The whole card is the tap target.
///
/// Peach rather than the white of the cards around it, so it reads as something
/// to do, not another shortcut. It only draws; Home decides when a card is there
/// and what a tap does.
class FirstTaskCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  const FirstTaskCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // On a light surface in dark mode too, so the text inside keeps its dark
    // colours (the scope has to sit above the Builder that reads the theme).
    return LightSurfaceScope(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Material(
            color: AppColors.peachMist,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.peachHairline),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 22),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: 2,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.grey400,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
