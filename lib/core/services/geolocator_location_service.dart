import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:geolocator/geolocator.dart';

import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/core/services/location_service.dart';

/// Whether the app may read the member's position.
enum LocationAccess {
  /// Allowed (while the app is in use is all that is asked for).
  granted,

  /// Not allowed yet, or refused this time: the system may be asked again.
  denied,

  /// Refused for good: the system will not show its prompt again, so asking is
  /// pointless and only the member can change it, in Settings.
  deniedForever,
}

/// The platform side of [GeolocatorLocationService], as small as the service
/// needs, so the service's own rules (what to ask, how often, what to do on a
/// failure) can be tested with a fake instead of a phone.
abstract class LocationGateway {
  /// Whether location is switched on for the whole phone.
  Future<bool> isServiceEnabled();

  /// The current permission, without asking.
  Future<LocationAccess> access();

  /// Asks the member (the system's own prompt) and answers what they chose.
  Future<LocationAccess> requestAccess();

  /// The last position the phone remembers, or null if it has none or it is too
  /// old to say where the member is now.
  Future<GeoPoint?> lastKnown();

  /// A fresh, low-accuracy fix, giving up after [timeLimit]. May throw.
  Future<GeoPoint?> current({required Duration timeLimit});
}

/// The real [LocationGateway], on the `geolocator` plugin.
///
/// **Low accuracy on purpose**: telling which branch is nearest needs a town, not
/// a street, it comes back sooner, and it is all the coarse-only permission
/// (Android `ACCESS_COARSE_LOCATION`, iOS when-in-use) allows anyway.
class GeolocatorGateway implements LocationGateway {
  /// A remembered position older than this is not trusted: the member may have
  /// travelled since, and the nearest branch with it.
  final Duration maxAge;

  const GeolocatorGateway({this.maxAge = const Duration(minutes: 15)});

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  LocationAccess _access(LocationPermission permission) => switch (permission) {
    LocationPermission.whileInUse ||
    LocationPermission.always => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    // `unableToDetermine` is only ever answered on the web.
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => LocationAccess.denied,
  };

  @override
  Future<LocationAccess> access() async =>
      _access(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestAccess() async =>
      _access(await Geolocator.requestPermission());

  @override
  Future<GeoPoint?> lastKnown() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    if (DateTime.now().difference(position.timestamp) > maxAge) return null;
    return GeoPoint(position.latitude, position.longitude);
  }

  @override
  Future<GeoPoint?> current({required Duration timeLimit}) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: timeLimit,
      ),
    );
    return GeoPoint(position.latitude, position.longitude);
  }
}

/// The app's [LocationService]: asks the phone where the member is, politely.
///
/// Keeps the [LocationService] contract (see there): it never throws, gives up
/// after [timeLimit] on the fix itself, and never stores, logs or sends what it
/// finds.
///
/// **Permission**, in the order that is kindest to the member:
/// 1. Location switched off for the whole phone: answer null at once and ask
///    nothing, since a prompt could not help.
/// 2. Already allowed: carry on.
/// 3. Not allowed yet: show the system prompt, **once per app run**. A member who
///    says no is not asked again until the app is restarted, and one who said
///    "never" is not asked at all.
///
/// **Position**: the phone's remembered one if it is fresh (instant), otherwise a
/// new low-accuracy fix. The time the member spends reading the prompt is theirs
/// and is not counted against [timeLimit].
class GeolocatorLocationService implements LocationService {
  final LocationGateway _gateway;

  /// How long to wait for a fix, once permission is settled.
  ///
  /// 8 s leans towards waiting: giving up too soon silently defaults the booking
  /// to the first workshop in the list instead of the nearest, while waiting only
  /// delays a default the member can pick by hand meanwhile. Not measured on a
  /// real phone; the times between the `[location]` lines are how to do that.
  final Duration timeLimit;

  /// How much longer than [timeLimit] to wait for the plugin itself to give up
  /// before this gives up on it: a plugin that never answers cannot hold anyone.
  final Duration grace;

  /// Whether the system prompt has been shown in this app run.
  bool _asked = false;

  /// One line to the console saying how far a lookup got (debug builds only), so
  /// a default that was not the nearest can be explained. **Never the position
  /// itself**, nor anything derived from it: only which step was reached.
  void _trace(String stage) {
    if (!kReleaseMode) debugPrint('[location] $stage');
  }

  GeolocatorLocationService({
    LocationGateway? gateway,
    this.timeLimit = const Duration(seconds: 8),
    this.grace = const Duration(seconds: 2),
  }) : _gateway = gateway ?? const GeolocatorGateway();

  @override
  Future<GeoPoint?> currentPosition() async {
    try {
      if (!await _gateway.isServiceEnabled()) {
        _trace('location is switched off for the phone: no position');
        return null;
      }

      var access = await _gateway.access();
      if (access == LocationAccess.denied && !_asked) {
        _asked = true;
        _trace('not allowed yet: showing the system prompt');
        access = await _gateway.requestAccess();
      }
      if (access != LocationAccess.granted) {
        _trace('permission is $access: no position');
        return null;
      }

      final position = await _remembered() ?? await _fix();
      _trace(position == null ? 'no position found' : 'position found');
      return position;
    } catch (e) {
      // Whatever went wrong (a platform error, a missing manifest entry), the
      // member just books without a default from their position.
      _trace('failed (${e.runtimeType}): no position');
      return null;
    }
  }

  /// The phone's remembered position, or null: also if asking for it fails, since
  /// a fresh fix is still worth trying.
  Future<GeoPoint?> _remembered() async {
    try {
      final remembered = await _gateway.lastKnown();
      _trace(
        remembered == null
            ? 'nothing fresh remembered: taking a new fix'
            : 'using the remembered position',
      );
      return remembered;
    } catch (e) {
      _trace('remembered position unreadable (${e.runtimeType})');
      return null;
    }
  }

  /// A fresh fix, or null if it fails or takes too long.
  Future<GeoPoint?> _fix() async {
    try {
      final fix = await _gateway
          .current(timeLimit: timeLimit)
          .timeout(timeLimit + grace, onTimeout: () => null);
      if (fix == null) _trace('the new fix did not arrive in time');
      return fix;
    } catch (e) {
      _trace('the new fix failed (${e.runtimeType})');
      return null;
    }
  }
}
