import 'package:flutter/material.dart';

import 'package:fix_up_moto/features/home/presentation/widgets/first_task_card.dart';

/// The nudge on Home for a member who has no bike registered yet: the first
/// thing a new member needs, since a booking cannot be made without one.
///
/// It only draws the card. Home decides when it is there (while the member's
/// bike count is 0, so it goes by itself once a bike is saved and the stats
/// reload) and what a tap does ([onTap] opens Add Bike).
class FirstBikeCard extends StatelessWidget {
  final VoidCallback onTap;

  const FirstBikeCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FirstTaskCard(
      icon: Icons.two_wheeler_outlined,
      title: 'Tambah motor pertama Anda',
      message: 'Daftarkan motor Anda agar bisa membuat booking servis.',
      onTap: onTap,
    );
  }
}
