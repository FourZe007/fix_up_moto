import 'package:fix_up_moto/core/helpers/geo.dart';

/// Where the member is right now, as far as the app is allowed to know.
///
/// Used for one thing: choosing the nearest workshop as the default for a
/// booking. The position is compared once and thrown away: never stored, never
/// logged, never sent to a server.
///
/// **The contract, which every implementation keeps:**
/// - [currentPosition] never throws. Location switched off, permission refused,
///   a platform error or running out of time all answer **null**, and the caller
///   carries on without a position (here: the first open workshop).
/// - It does not make the member wait long: an implementation gives up after a
///   few seconds, so a booking can never be held up by a slow GPS.
/// - It asks the member for permission at most once per app run, and not at all
///   once the member has refused for good, so it never nags.
abstract class LocationService {
  Future<GeoPoint?> currentPosition();
}

/// A [LocationService] that knows nothing: always answers null.
///
/// What the app is wired with until a real one is (see `injection_container.dart`),
/// so everything that asks for a position already works, and falls back, without
/// one.
class NoLocationService implements LocationService {
  const NoLocationService();

  @override
  Future<GeoPoint?> currentPosition() async => null;
}
