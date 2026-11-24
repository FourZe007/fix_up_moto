import 'dart:async';

import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';

/// Starts a booking for a member who is not on the Bookings tab: what "Buat
/// Booking" does after their first bike is saved, what Home's "Buat booking
/// pertama Anda" card does, and what the app tour's last step does (see
/// [FirstTaskStep]).
///
/// Opens the booking form straight away, as [FirstTaskStep.createBooking], so
/// once the booking is made it points to the Booking tab. There is no workshop
/// step in front of it: the form chooses one itself (the first open workshop in
/// the list, unless one is already chosen) and shows it, with a row to change it.
///
/// Takes the router instead of a context because it runs from a snack bar's
/// button, after the page that showed the snack bar has gone.
Future<void> startGuidedBooking({required GoRouter router}) async {
  unawaited(
    router.push<Object?>(
      RouteNames.createBooking,
      extra: FirstTaskStep.createBooking,
    ),
  );
}
