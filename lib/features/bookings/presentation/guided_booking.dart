import 'dart:async';

import 'package:go_router/go_router.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';
import 'package:fix_up_moto/features/workshops/presentation/cubit/selected_workshop_cubit.dart';

/// Starts a booking for a member who is not on the Bookings tab: what "Buat
/// Booking" does after their first bike is saved (see [FirstTaskStep]).
///
/// The same two steps as the Bookings tab's own button: a workshop first, if
/// none is chosen yet, then the booking form. Backing out of the workshop list
/// stops there and leaves the member where they were. The form is opened as
/// [FirstTaskStep.createBooking], so once the booking is made it points to the
/// Booking tab.
///
/// Takes the router and the cubit instead of a context because it runs from a
/// snack bar's button, after the page that showed the snack bar has gone.
Future<void> startGuidedBooking({
  required GoRouter router,
  required SelectedWorkshopCubit workshop,
}) async {
  if (workshop.state == null) {
    final picked = await router.push<WorkshopEntity>(RouteNames.workshops);
    if (picked == null) return;
    workshop.select(picked);
  }
  unawaited(
    router.push<Object?>(
      RouteNames.createBooking,
      extra: FirstTaskStep.createBooking,
    ),
  );
}
