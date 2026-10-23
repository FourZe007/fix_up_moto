import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';
import 'package:fix_up_moto/core/widgets/light_surface_scope.dart';

/// A group's title, sitting on the page above its [SectionCard].
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Dark red, not the brand orange: orange text is only 3.8:1 on the light
    // page and fails for small text, the dark red is 6.7:1. On the dark theme's
    // black page the dark red would fail instead (2.9:1), so it uses the light
    // orange there.
    final color = theme.brightness == Brightness.dark
        ? AppColors.primaryLight
        : AppColors.primaryDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      // Read as a heading by screen readers, so they can jump between groups.
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// One rounded card holding a group's rows ([ActionRow]), split by hairlines.
/// White (light grey in dark mode, via [LightSurfaceScope]), like the cards on
/// the other tabs.
class SectionCard extends StatelessWidget {
  final List<Widget> children;

  const SectionCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // On a white (light grey in dark) surface, so in dark mode the text inside
    // needs the light theme's dark colours too.
    return LightSurfaceScope(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Material(
            color: theme.colorScheme.surface,
            // Keeps each row's ripple inside the rounded corners.
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              // A warm hairline rather than grey, to sit with the peach tiles.
              side: const BorderSide(color: AppColors.peachHairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  // Starts under the label, not under the icon tile: 12 px of
                  // padding, the 36 px tile, 12 px of gap.
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 60,
                      color: AppColors.peachHairline,
                    ),
                  children[i],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A full-width shortcut row inside a [SectionCard]: an [icon], the [name], an
/// optional [value] (a count or a balance) and [trailing] widget (e.g. an
/// unread badge), and a chevron — the whole row is the tap target.
///
/// It draws no card of its own, so it must sit in a [SectionCard], which is
/// also what lets it read the light theme in dark mode.
class ActionRow extends StatelessWidget {
  final String name;
  final Icon icon;
  final VoidCallback onPressed;

  /// Plain text shown before the chevron, e.g. "4" or "80 pts".
  final String? value;

  /// Shown between the name and the chevron; nothing by default.
  final Widget? trailing;

  /// Marks an action that ends something (Hapus Profile): red label, and no
  /// chevron since it does not lead on to another page.
  final bool destructive;

  const ActionRow({
    super.key,
    required this.name,
    required this.icon,
    required this.onPressed,
    this.value,
    this.trailing,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 12,
          children: [
            // The icon on a soft 36 px tile (red-tinted for a destructive row).
            // Inside it, one fixed 20 px slot for every icon: the Font Awesome
            // logos are narrower than Material's icons, and without it the
            // labels of rows with different kinds of icon start at different x.
            Container(
              key: const Key('row-icon-tile'),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: destructive
                    ? AppColors.errorBackground
                    : AppColors.peachMist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SizedBox.square(dimension: 20, child: Center(child: icon)),
            ),
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: destructive ? AppColors.error : null,
                ),
              ),
            ),
            ?trailing,
            if (value != null)
              Text(
                value!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700,
                ),
              ),
            if (!destructive)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.grey400,
              ),
          ],
        ),
      ),
    );
  }
}
