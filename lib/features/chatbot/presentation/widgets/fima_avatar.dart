import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/constants/asset_constants.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';

/// Fima's round badge: her portrait on a soft tint of the brand colour.
///
/// The portrait is drawn wide (her laptop and desk are in the picture), so it
/// is zoomed in on her head and shoulders: shown whole, her face would be about
/// 8 px across in a bubble's 32 px badge.
class FimaAvatar extends StatelessWidget {
  final double size;

  const FimaAvatar({super.key, this.size = 32});

  /// How far the picture is enlarged inside the circle.
  static const _zoom = 1.8;

  /// Which part of the enlarged picture sits in the circle: centred across,
  /// and shifted up so her face (about a third of the way down the picture)
  /// is in the middle, with the top of her hair bun inside the rim.
  static const _focus = Alignment(0, -0.775);

  @override
  Widget build(BuildContext context) {
    final drawn = size * _zoom;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          // Lets the enlarged picture overhang the circle, which clips it.
          child: OverflowBox(
            maxWidth: drawn,
            maxHeight: drawn,
            alignment: _focus,
            child: Image.asset(
              AssetConstants.fimaAvatar,
              width: drawn,
              height: drawn,
              fit: BoxFit.cover,
              // Decoded at the size it is drawn at, not the full bitmap.
              cacheWidth: (drawn * pixelRatio).round(),
              filterQuality: FilterQuality.medium,
              // Silent, like the icon before it: her name is always beside her
              // face (the app bar, the greeting), and announcing it on every
              // bubble would only be noise.
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
