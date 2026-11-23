import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/refresh/data_refresh_cubit.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_task_card.dart';

/// Home's "Buat booking pertama Anda" nudge, for a member who has a bike but has
/// not booked yet. Draws nothing for anyone else.
///
/// Home gives it the member's id and bike count and what a tap does; the slot
/// itself keeps three things, all on this phone (see [FirstBookingGuide]):
/// - a member found with **no bike** is noted as new (so Home's bike card and
///   this card are never both there: this one needs a bike);
/// - once they have a bike, and are still noted and unsettled, the card shows;
/// - a booking made anywhere in the app (it signals [DataKind.bookings])
///   settles them, and the card goes by itself, for good.
class FirstBookingSlot extends StatefulWidget {
  final SharedPreferences prefs;

  /// The signed-in member, as the stats record names them.
  final String memberId;

  /// How many bikes they have right now.
  final int bikes;

  /// What a tap on the card does: start a booking.
  final VoidCallback onTap;

  const FirstBookingSlot({
    super.key,
    required this.prefs,
    required this.memberId,
    required this.bikes,
    required this.onTap,
  });

  @override
  State<FirstBookingSlot> createState() => _FirstBookingSlotState();
}

class _FirstBookingSlotState extends State<FirstBookingSlot> {
  @override
  void initState() {
    super.initState();
    _noteIfNew();
  }

  @override
  void didUpdateWidget(FirstBookingSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberId != widget.memberId ||
        oldWidget.bikes != widget.bikes) {
      _noteIfNew();
    }
  }

  /// Seeing a member with no bike is what makes them "new" to this card.
  void _noteIfNew() {
    if (widget.bikes > 0) return;
    // Failing to remember only means no card for this member: the safe side.
    unawaited(
      FirstBookingGuide.notePending(
        widget.prefs,
        widget.memberId,
      ).catchError((Object _) {}),
    );
  }

  void _onBooked(BuildContext context, DataRefresh _) {
    unawaited(
      FirstBookingGuide.settle(
        widget.prefs,
        widget.memberId,
      ).catchError((Object _) {}).whenComplete(() {
        if (mounted) setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final show =
        widget.bikes > 0 &&
        FirstBookingGuide.isPending(widget.prefs, widget.memberId);

    return BlocListener<DataRefreshCubit, DataRefresh>(
      listenWhen: (_, current) => current.kind == DataKind.bookings,
      listener: _onBooked,
      child: show
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FirstTaskCard(
                key: const Key('first-booking-card'),
                icon: Icons.event_available_outlined,
                title: 'Buat booking pertama Anda',
                message:
                    'Pilih bengkel, tanggal, dan jam servis untuk motor '
                    'Anda.',
                onTap: widget.onTap,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
