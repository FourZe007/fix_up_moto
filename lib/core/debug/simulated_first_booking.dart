import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/constants/app_constants.dart';
import 'package:fix_up_moto/core/tour/app_tour_seen.dart';
import 'package:fix_up_moto/core/tour/field_guide_seen.dart';
import 'package:fix_up_moto/features/home/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/features/home/presentation/widgets/first_booking_guide.dart';

/// A debug aid for the other half of the first-run guidance: an account that
/// **already has its bikes** but has not booked a service yet, so Home's "Buat
/// booking pertama Anda" card, the guided booking behind it and the "Lihat"
/// pointer after it can be seen without a second account.
///
/// [SimulatedNewMember] is the first half (no bike → add one → offered a
/// booking) and hides the bikes. This one leaves the bike count alone, because
/// the point is a member who has bikes: it changes what the *phone remembers*.
/// The card only shows for a member the phone noted as "new, not booked yet"
/// (see [FirstBookingGuide]), which an existing member never is; here they are.
///
/// Switched on with `--dart-define=SIMULATE_FIRST_BOOKING=true`
/// ([AppConstants.simulateFirstBooking]) and **never in a release build**:
/// [start] answers null there whatever is defined, the same rule as
/// [SimulatedNewMember].
///
/// What it does:
/// - [start], once per app launch, forgets the app tour's "seen" flag and the
///   Create Booking field guide's, so both play at every launch. A member who has a bike but still has to make a
///   first booking counts as new to the tour (see `AppTourAudience`), and its
///   last step offers "Buat booking sekarang".
/// - [prepare] (the home bloc calls it when a member's stats arrive, before they
///   are shown): the first time this launch sees a member it forgets the
///   first-booking memory on the phone and notes that member as not having
///   booked. A booking made afterwards settles them as usual and the card goes;
///   a later stats reload does **not** note them again, so the card stays gone
///   until the next launch (or the next sign-in after a sign-out, see [reset]),
///   which starts from "never booked" once more. It runs before the stats are
///   shown, so by the time the tour reads the bike count the member is already
///   noted.
class SimulatedFirstBooking {
  final SharedPreferences _prefs;
  String? _memberId;

  SimulatedFirstBooking(this._prefs);

  /// The simulation for this launch, or null when it is off (not asked for, or a
  /// release build).
  static Future<SimulatedFirstBooking?> start(
    SharedPreferences prefs, {
    bool enabled = AppConstants.simulateFirstBooking,
    bool release = kReleaseMode,
  }) async {
    if (release || !enabled) return null;

    await prefs.remove(AppTourSeen.key);
    await prefs.remove(FieldGuideSeen.keyFor(FieldGuideId.createBooking));
    debugPrint(
      '[SIMULATE_FIRST_BOOKING] on: the member is shown as not having booked '
      'yet, so the app tour, Home\'s "Buat booking pertama Anda" and the '
      'Create Booking field guide are offered at every launch.',
    );
    return SimulatedFirstBooking(prefs);
  }

  /// Makes the phone remember [stats]' member as one who has not booked yet.
  ///
  /// Does it once per member per launch (and again after [reset]); later calls
  /// for the same member are no-ops, so a reload after a booking cannot bring the
  /// card back. Never throws: a preferences failure only means no card, and must
  /// not hold up the stats.
  ///
  /// This clears the lists for **everyone** on the phone, not just this member
  /// (a debug aid on a test phone), the same way [SimulatedNewMember.start]
  /// clears them.
  Future<void> prepare(DashboardStatsEntity stats) async {
    if (_memberId == stats.memberId) return;
    // Taken before the first await, so two overlapping loads do it once.
    _memberId = stats.memberId;

    try {
      await _prefs.remove(FirstBookingGuide.pendingKey);
      await _prefs.remove(FirstBookingGuide.settledKey);
      await FirstBookingGuide.notePending(_prefs, stats.memberId);
    } catch (e) {
      // Not done: let the next load try again.
      _memberId = null;
      debugPrint('[SIMULATE_FIRST_BOOKING] could not note the member: $e');
    }
  }

  /// Forgets who was seen, so the next member to sign in (or the same one again)
  /// starts from "not booked yet" (at sign-out).
  void reset() => _memberId = null;
}
