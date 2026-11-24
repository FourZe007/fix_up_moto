import 'dart:math' as math;

/// A point on the earth, in degrees.
///
/// Deliberately has no `toString` of its own: a member's position is private, and
/// the default one prints nothing about it, so it cannot end up in a log by
/// accident.
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  /// Whether this is a real place. A workshop whose record has no coordinates
  /// can arrive as exactly 0,0 (the sea off Africa, nowhere near any branch), or
  /// as something out of range; neither may be treated as a location.
  bool get isValid =>
      lat.isFinite &&
      lng.isFinite &&
      lat.abs() <= 90 &&
      lng.abs() <= 180 &&
      !(lat == 0 && lng == 0);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// The great-circle distance between [a] and [b], in kilometres (haversine).
///
/// Good to well under a percent over the distances between branches, which is
/// all this is for: picking which of a handful of workshops is the closest.
double distanceKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0088;
  double rad(double degrees) => degrees * math.pi / 180;

  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}
