import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/profile/domain/entities/profile_entity.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/profile_repository.dart';

class GetProfileUseCase extends NoParamsUseCase<ProfileEntity> {
  final ProfileRepository repository;
  GetProfileUseCase(this.repository);

  @override
  Future<Either<Failure, ProfileEntity>> call() => repository.getProfile();
}
