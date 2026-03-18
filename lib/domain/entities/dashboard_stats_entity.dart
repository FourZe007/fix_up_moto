import 'package:equatable/equatable.dart';

/// Aggregated statistics shown on the home dashboard.
/// Assembled server-side from bookings and service data.
class DashboardStatsEntity extends Equatable {
  /// Total number of bookings the user has ever made.
  final int totalBookings;

  /// Number of bookings with status "upcoming" (scheduled but not yet done).
  final int upcomingBookings;

  /// Number of bookings completed in the current calendar month.
  final int completedThisMonth;

  /// Loyalty points the user has accumulated (if the app has a rewards system).
  final int loyaltyPoints;

  const DashboardStatsEntity({
    required this.totalBookings,
    required this.upcomingBookings,
    required this.completedThisMonth,
    required this.loyaltyPoints,
  });

  @override
  List<Object> get props => [
        totalBookings,
        upcomingBookings,
        completedThisMonth,
        loyaltyPoints,
      ];
}
