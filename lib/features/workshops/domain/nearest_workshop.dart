import 'package:fix_up_moto/core/helpers/geo.dart';
import 'package:fix_up_moto/features/workshops/domain/entities/workshop_entity.dart';

/// The first workshop in [workshops] that can be picked, or null if none can.
///
/// "Can be picked" is `active`: the workshop list shows the others but does not
/// let a member choose them, so a default must not either.
WorkshopEntity? firstActiveWorkshop(List<WorkshopEntity> workshops) {
  for (final workshop in workshops) {
    if (workshop.active) return workshop;
  }
  return null;
}

/// How far [workshop] is from [from] in a straight line, or null if either end
/// is unknown: no position, or one that is not a real place.
///
/// A record with no coordinates can arrive as 0,0, which would otherwise look
/// absurdly far away rather than unknown, or, for a member abroad, closest.
double? workshopDistanceKm(WorkshopEntity workshop, GeoPoint? from) {
  final where = GeoPoint(workshop.lat, workshop.lng);
  if (from == null || !from.isValid || !where.isValid) return null;
  return distanceKm(from, where);
}

/// The workshop in [workshops] closest to [from], or null if none qualifies (or
/// [from] is not a real position).
///
/// Only active workshops count, and so do only ones that can be placed (see
/// [workshopDistanceKm]). A tie keeps the list's own order.
WorkshopEntity? nearestWorkshop(List<WorkshopEntity> workshops, GeoPoint from) {
  WorkshopEntity? nearest;
  var nearestKm = double.infinity;
  for (final workshop in workshops) {
    if (!workshop.active) continue;

    final km = workshopDistanceKm(workshop, from);
    // Strictly closer: an equal distance keeps the earlier workshop.
    if (km != null && km < nearestKm) {
      nearest = workshop;
      nearestKm = km;
    }
  }
  return nearest;
}

/// [workshops] in the order a member reads them from the top, seen from [from]:
/// the open ones nearest first, then the open ones that cannot be placed, then
/// the closed ones, which cannot be picked, in the same way. Equal places keep
/// the list's own order.
///
/// So the first card is always [nearestWorkshop], when there is one. With no
/// position (null, or not a real one) the list is returned as it came.
List<WorkshopEntity> sortByDistance(
  List<WorkshopEntity> workshops,
  GeoPoint? from,
) {
  if (from == null || !from.isValid) return workshops;

  final ranked = [
    for (final (index, workshop) in workshops.indexed)
      (
        workshop: workshop,
        closed: workshop.active ? 0 : 1,
        km: workshopDistanceKm(workshop, from) ?? double.infinity,
        // `List.sort` does not promise to keep equal items in order.
        index: index,
      ),
  ];
  ranked.sort((a, b) {
    if (a.closed != b.closed) return a.closed.compareTo(b.closed);
    if (a.km != b.km) return a.km.compareTo(b.km);
    return a.index.compareTo(b.index);
  });
  return [for (final entry in ranked) entry.workshop];
}
