import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/domain/usecases/usecase.dart';
import 'package:fix_up_moto/domain/entities/user_entity.dart';
import 'package:fix_up_moto/domain/repositories/profile_repository.dart';

class UpdateProfileUseCase extends UseCase<UserEntity, UpdateProfileParams> {
  final ProfileRepository repository;
  UpdateProfileUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(UpdateProfileParams params) {
    return repository.updateProfile(name: params.name, phone: params.phone);
  }
}

class UpdateProfileParams extends Equatable {
  final String name;
  final String? phone;
  const UpdateProfileParams({required this.name, this.phone});

  @override
  List<Object?> get props => [name, phone];
}
