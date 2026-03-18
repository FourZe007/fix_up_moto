import 'package:flutter/material.dart';

/// A compact stat card used in the dashboard grid.
/// Displays a single metric with an icon and label.
class StatsCard extends StatelessWidget {
  final String label;

  /// The formatted value to display prominently (e.g. "12", "1,500 pts").
  final String value;

  final IconData icon;

  /// Optional accent colour for the icon — defaults to the theme primary colour.
  final Color? iconColor;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon in a tinted circle container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effectiveIconColor, size: 20),
            ),
            const SizedBox(height: 12),

            // Large numeric value
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),

            // Descriptive label in secondary text colour
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
