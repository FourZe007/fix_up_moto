// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_stats_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardStatsModel _$DashboardStatsModelFromJson(Map<String, dynamic> json) =>
    DashboardStatsModel(
      totalBookings: (json['total_bookings'] as num).toInt(),
      upcomingBookings: (json['upcoming_bookings'] as num).toInt(),
      completedThisMonth: (json['completed_this_month'] as num).toInt(),
      loyaltyPoints: (json['loyalty_points'] as num).toInt(),
    );

Map<String, dynamic> _$DashboardStatsModelToJson(
  DashboardStatsModel instance,
) => <String, dynamic>{
  'total_bookings': instance.totalBookings,
  'upcoming_bookings': instance.upcomingBookings,
  'completed_this_month': instance.completedThisMonth,
  'loyalty_points': instance.loyaltyPoints,
};
