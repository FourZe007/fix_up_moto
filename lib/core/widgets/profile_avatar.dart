import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';

/// The member's avatar: their initial on an orange gradient disc.
///
/// The stats record the Profile and Edit Profile pages read has no photo, so
/// the initial is all there is. The white ring and soft orange shadow lift it
/// off the warm wash behind it ([WarmWash]).
class ProfileAvatar extends StatelessWidget {
  /// The member's name; its first letter is shown, or `?` when it is empty.
  final String name;

  final double size;

  const ProfileAvatar({super.key, required this.name, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primary],
        ),
        border: Border.all(color: AppColors.surfaceLight, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
