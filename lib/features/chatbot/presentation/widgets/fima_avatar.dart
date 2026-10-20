import 'package:flutter/material.dart';
import 'package:fix_up_moto/core/theme/app_colors.dart';

/// Fima's round badge: a robot in the brand colour on a soft tint of it.
class FimaAvatar extends StatelessWidget {
  final double size;

  const FimaAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          Icons.smart_toy_outlined,
          size: size * 0.55,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
