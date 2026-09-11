import 'package:equatable/equatable.dart';

/// A workshop/branch location, from the `Master` endpoint
/// (`Jenis: "BRANCHSHOP"`).
class WorkshopEntity extends Equatable {
  /// Branch code, e.g. "31".
  final String branch;

  /// Shop code within the branch, e.g. "01".
  final String shop;

  final String bsName;
  final String bsAddress;

  /// Raw operating-hours text as the backend formats it — contains literal
  /// tab/newline characters for column alignment, not a structured schedule.
  final String operationalHours;

  final String phoneNo;
  final bool active;
  final double lat;
  final double lng;

  const WorkshopEntity({
    required this.branch,
    required this.shop,
    required this.bsName,
    required this.bsAddress,
    required this.operationalHours,
    required this.phoneNo,
    required this.active,
    required this.lat,
    required this.lng,
  });

  /// The backend has no single ID field for a branch-shop record — [branch]
  /// and [shop] together are what identifies one. Derived here rather than
  /// stored, so there's exactly one place this composition happens.
  String get id => '$branch-$shop';

  @override
  List<Object?> get props => [
        branch, shop, bsName, bsAddress,
        operationalHours, phoneNo, active, lat, lng,
      ];
}
