import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';

/// A debug aid that makes an account that already has bikes look like a new
/// member, so the first-run guidance (the app tour, its hand-off, Home's bike and
/// booking cards, the offers after the first bike and booking) can be seen
/// without a second account.
///
/// Switched on with `--dart-define=SIMULATE_NEW_MEMBER=true`
/// ([AppConstants.simulateNewMember]) and **never in a release build**:
/// [start] answers null there whatever is defined, the same rule as
/// `applyPreviewPlatform`, so a stray define cannot change what members get.
///
/// What it does:
/// - [start], once per app launch, forgets the guidance's memory on the phone
///   (the tour's "seen" flag, the Add Bike and Create Booking field guides', and
///   the first-booking card's lists), so every launch is a first run: the tour,
///   then Add Bike's guide to each field, then Create Booking's.
/// - [apply] shows the member's stats with the bikes they already had when this
///   launch first saw them taken off the bike count. Adding a bike really saves
///   it and counts, so the chain carries on (bike card → add a bike → "Buat
///   booking sekarang?" → booking card). Only the count is changed: the bike
///   list, the bike picker and every request are the real ones. The Profile tab's
///   bike count reads the same number, so it shows the changed count too.
///
/// A fresh launch counts whatever bikes exist then as the ones to hide, so it
/// starts from "no bike" again, which is the point.
class SimulatedNewMember {
  String? _memberId;
  int _hidden = 0;

  /// The simulation for this launch, or null when it is off (not asked for, or a
  /// release build). When on, also forgets the guidance's memory in [prefs].
  static Future<SimulatedNewMember?> start(
    SharedPreferences prefs, {
    bool enabled = AppConstants.simulateNewMember,
    bool release = kReleaseMode,
  }) async {
    if (release || !enabled) return null;

    await prefs.remove(AppTourSeen.key);
    await prefs.remove(FieldGuideSeen.keyFor(FieldGuideId.addBike));
    await prefs.remove(FieldGuideSeen.keyFor(FieldGuideId.createBooking));
    await prefs.remove(FirstBookingGuide.pendingKey);
    await prefs.remove(FirstBookingGuide.settledKey);
    debugPrint(
      '[SIMULATE_NEW_MEMBER] on: the bikes this account already has are hidden '
      'from the bike count, and the app tour, the Add Bike and Create Booking '
      'field guides and the first-booking memory were cleared.',
    );
    return SimulatedNewMember();
  }

  /// [stats] with the bikes that were already there taken off the bike count.
  DashboardStatsEntity apply(DashboardStatsEntity stats) {
    if (_memberId != stats.memberId) {
      _memberId = stats.memberId;
      _hidden = stats.qty;
    }
    // A bike deleted since lowers what there is to hide, so adding one after
    // that still counts instead of vanishing into the old number.
    if (stats.qty < _hidden) _hidden = stats.qty;

    return DashboardStatsEntity(
      status: stats.status,
      memberId: stats.memberId,
      memberName: stats.memberName,
      emailAddress: stats.emailAddress,
      phoneNo: stats.phoneNo,
      active: stats.active,
      qty: stats.qty - _hidden,
      point: stats.point,
      detail: stats.detail,
      detail2: stats.detail2,
    );
  }

  /// Forgets who was seen, so the next stats start from "no bike" again (at
  /// sign-out).
  void reset() {
    _memberId = null;
    _hidden = 0;
  }
}
