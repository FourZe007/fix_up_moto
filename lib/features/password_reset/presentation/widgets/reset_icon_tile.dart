import 'package:flutter/material.dart';

/// A round tinted badge with one icon: the top of both reset screens.
class ResetIconTile extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color border;
  final Color color;

  const ResetIconTile({
    super.key,
    required this.icon,
    required this.background,
    required this.border,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: border),
      ),
      child: Icon(icon, size: 32, color: color),
    );
  }
}
