import 'package:fix_up_moto/features/profile/domain/entities/bike_entity.dart';

/// How a bike is named where the member picks one for Riwayat: the plate, then
/// the model, e.g. "B 1234 XY · YAMAHA R25". A bike with no model is just its
/// plate.
extension BikePlateLabel on BikeEntity {
  String get plateLabel =>
      unitId.trim().isEmpty ? plateNo : '$plateNo · $unitId';
}
