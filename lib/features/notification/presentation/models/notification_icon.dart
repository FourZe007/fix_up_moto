import 'package:flutter/material.dart';

/// The icon on a message's tile, from the type the backend sent (English, e.g.
/// "Service Booking Confirmed"). A type it does not know gets a plain bell, so a
/// new kind of message still looks right before anyone has picked it an icon.
///
/// Matched loosely on a word in the type, and "booking" is checked before
/// "service" because "Service Booking Confirmed" contains both.
IconData notificationIconOf(String type) {
  final lower = type.toLowerCase();

  if (lower.contains('booking')) return Icons.calendar_month_outlined;
  if (lower.contains('point')) return Icons.card_giftcard_outlined;
  if (lower.contains('remind') || lower.contains('service')) {
    return Icons.build_outlined;
  }
  return Icons.notifications_outlined;
}
