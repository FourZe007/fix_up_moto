import 'package:json_annotation/json_annotation.dart';
import 'package:fix_up_moto/domain/entities/dashboard_stats_entity.dart';

part 'dashboard_stats_model.g.dart';

/// JSON model for the dashboard stats API response.
@JsonSerializable()
class DashboardStatsModel {
  @JsonKey(name: 'total_bookings')
  final int totalBookings;

  @JsonKey(name: 'upcoming_bookings')
  final int upcomingBookings;

  @JsonKey(name: 'completed_this_month')
  final int completedThisMonth;

  @JsonKey(name: 'loyalty_points')
  final int loyaltyPoints;

  const DashboardStatsModel({
    required this.totalBookings,
    required this.upcomingBookings,
    required this.completedThisMonth,
    required this.loyaltyPoints,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsModelFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardStatsModelToJson(this);

  /// Converts to the Domain entity returned to callers.
  DashboardStatsEntity toEntity() => DashboardStatsEntity(
        totalBookings: totalBookings,
        upcomingBookings: upcomingBookings,
        completedThisMonth: completedThisMonth,
        loyaltyPoints: loyaltyPoints,
      );
}
