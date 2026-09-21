import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserEntity>> getProfile();
  Future<Either<Failure, UserEntity>> updateProfile({
    required String name,
    String? phone,
  });
}
