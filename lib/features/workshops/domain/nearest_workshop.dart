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

/// The workshop in [workshops] closest to [from], or null if none qualifies (or
/// [from] is not a real position).
///
/// Only active workshops count, and so do only ones with real coordinates: a
/// record with no coordinates can arrive as 0,0 and would otherwise look
/// absurdly far away rather than unknown, or, for a member abroad, closest. A
/// tie keeps the list's own order.
WorkshopEntity? nearestWorkshop(List<WorkshopEntity> workshops, GeoPoint from) {
  if (!from.isValid) return null;

  WorkshopEntity? nearest;
  var nearestKm = double.infinity;
  for (final workshop in workshops) {
    final where = GeoPoint(workshop.lat, workshop.lng);
    if (!workshop.active || !where.isValid) continue;

    final km = distanceKm(from, where);
    // Strictly closer: an equal distance keeps the earlier workshop.
    if (km < nearestKm) {
      nearest = workshop;
      nearestKm = km;
    }
  }
  return nearest;
}
