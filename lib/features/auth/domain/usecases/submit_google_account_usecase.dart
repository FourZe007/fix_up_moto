import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/auth/domain/entities/user_entity.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';

/// Completes a Google sign-up once the complete-profile form is submitted.
class SubmitGoogleAccountUseCase
    extends UseCase<UserEntity, SubmitGoogleAccountParams> {
  final AuthRepository repository;

  SubmitGoogleAccountUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(SubmitGoogleAccountParams params) {
    return repository.submitGoogleAccount(
      name: params.name,
      phone: params.phone,
      email: params.email,
    );
  }
}

class SubmitGoogleAccountParams extends Equatable {
  final String name;
  final String phone;
  final String email;

  const SubmitGoogleAccountParams({
    required this.name,
    required this.phone,
    required this.email,
  });

  @override
  List<Object> get props => [name, phone, email];
}
