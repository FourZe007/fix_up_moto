import 'package:flutter/material.dart';

import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';

/// What the member is taken to when they accept the tour's last-step offer.
enum AppTourHandoffTask {
  /// Opens Add Bike ([AppTourHandoff.route]) as the guidance's bike step.
  addBike,

  /// Starts a booking: the workshop list if none is chosen, then Create Booking
  /// (see `startGuidedBooking`). Not a plain route, because of the workshop step.
  bookService,
}

/// Where the tour's last step can send the member on to, in place of a plain
/// "Selesai": the next real task, so the tour does not end by leaving them
/// alone at the end of an explanation.
///
/// Only a description: the tour shows [message] and a button labelled
/// [acceptLabel], and on a tap closes itself and runs [task] (a page opened on
/// top, so back returns to where they were). "Nanti saja" closes it and opens
/// nothing.
class AppTourHandoff {
  /// What accepting does.
  final AppTourHandoffTask task;

  /// The route to open if the member accepts, for [AppTourHandoffTask.addBike].
  /// Null for a task that is not a plain route.
  final String? route;

  /// What to hand that route as its `extra`, if anything.
  final Object? extra;

  /// One short sentence on the card, saying why.
  final String message;

  /// The accept button's label.
  final String acceptLabel;

  /// The icon beside [message]: the task's own.
  final IconData icon;

  const AppTourHandoff({
    this.task = AppTourHandoffTask.addBike,
    this.route,
    this.extra,
    required this.message,
    required this.acceptLabel,
    this.icon = Icons.two_wheeler_outlined,
  });

  /// A booking needs a bike, so for a member with none the first task is
  /// registering one. Opened as the guidance's bike step, so once the bike is
  /// saved the member is offered a booking straight away.
  static const AppTourHandoff addFirstBike = AppTourHandoff(
    route: RouteNames.addBike,
    extra: FirstTaskStep.addBike,
    message:
        'Langkah pertama: daftarkan motor Anda agar bisa membuat booking '
        'servis.',
    acceptLabel: 'Tambah motor sekarang',
  );

  /// For a member who has a bike but has not booked yet: the booking itself,
  /// started the way Home's "Buat booking pertama Anda" card starts it, so it
  /// ends in the same pointer to the Booking tab.
  static const AppTourHandoff bookFirstService = AppTourHandoff(
    task: AppTourHandoffTask.bookService,
    message:
        'Langkah berikutnya: buat booking servis pertama untuk motor Anda.',
    acceptLabel: 'Buat booking sekarang',
    icon: Icons.event_available_outlined,
  );

  /// What to offer a member who has [bikeCount] bikes: [addFirstBike] if they
  /// have none (a booking needs a bike, so that comes first), [bookFirstService]
  /// if they have one and are still to make their first booking
  /// ([bookingPending]), nothing otherwise, and nothing while the count is not
  /// known (the stats have not loaded), so the tour then ends the plain way
  /// rather than guessing.
  static AppTourHandoff? forBikeCount(
    int? bikeCount, {
    bool bookingPending = false,
  }) {
    if (bikeCount == null) return null;
    if (bikeCount <= 0) return addFirstBike;
    return bookingPending ? bookFirstService : null;
  }
}
