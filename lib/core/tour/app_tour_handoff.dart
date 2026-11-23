import 'package:fix_up_moto/core/router/first_task_step.dart';
import 'package:fix_up_moto/core/router/route_names.dart';

/// Where the tour's last step can send the member on to, in place of a plain
/// "Selesai": the first real task, so the tour does not end by leaving them
/// alone at the end of an explanation.
///
/// Only a description: the tour shows [message] and a button labelled
/// [acceptLabel], and on a tap closes itself and opens [route] (pushed, so back
/// returns to where they were), handing it [extra]. "Nanti saja" closes it and
/// opens nothing.
class AppTourHandoff {
  /// The route to open if the member accepts.
  final String route;

  /// What to hand that route as its `extra`, if anything.
  final Object? extra;

  /// One short sentence on the card, saying why.
  final String message;

  /// The accept button's label.
  final String acceptLabel;

  const AppTourHandoff({
    required this.route,
    this.extra,
    required this.message,
    required this.acceptLabel,
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

  /// What to offer a member who has [bikeCount] bikes: [addFirstBike] if they
  /// have none, nothing if they have some or the count is not known (the stats
  /// have not loaded), so the tour then ends the plain way rather than guessing.
  static AppTourHandoff? forBikeCount(int? bikeCount) =>
      bikeCount != null && bikeCount <= 0 ? addFirstBike : null;
}
