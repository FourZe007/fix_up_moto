import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, ProfileEntity>> getProfile();
  Future<Either<Failure, ProfileEntity>> updateProfile({
    required String name,
    String? phone,
  });
}
