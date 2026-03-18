import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/entities/dashboard_stats_entity.dart';

/// Abstract contract for home/dashboard data operations.
abstract class HomeRepository {
  /// Fetches aggregated stats for the dashboard (booking counts, loyalty points).
  Future<Either<Failure, DashboardStatsEntity>> getDashboardStats();
}
