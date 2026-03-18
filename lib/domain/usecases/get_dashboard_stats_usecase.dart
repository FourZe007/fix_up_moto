import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/dashboard_stats_entity.dart';
import 'package:fix_up_moto/domain/repositories/home_repository.dart';

/// Retrieves dashboard statistics for the home screen.
class GetDashboardStatsUseCase extends NoParamsUseCase<DashboardStatsEntity> {
  final HomeRepository repository;

  GetDashboardStatsUseCase(this.repository);

  @override
  Future<Either<Failure, DashboardStatsEntity>> call() {
    return repository.getDashboardStats();
  }
}
