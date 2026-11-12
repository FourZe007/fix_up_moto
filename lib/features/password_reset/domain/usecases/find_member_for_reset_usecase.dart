import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/password_reset/domain/entities/password_reset_member.dart';
import 'package:fix_up_moto/features/password_reset/domain/repositories/password_reset_repository.dart';

/// Looks up the member a forgotten-password reset is for, by phone number.
class FindMemberForResetUseCase
    extends UseCase<PasswordResetMember, FindMemberForResetParams> {
  final PasswordResetRepository repository;
  FindMemberForResetUseCase(this.repository);

  @override
  Future<Either<Failure, PasswordResetMember>> call(
    FindMemberForResetParams params,
  ) {
    return repository.findMember(params.phone);
  }
}

class FindMemberForResetParams extends Equatable {
  /// The phone as typed.
  final String phone;
  const FindMemberForResetParams({required this.phone});

  @override
  List<Object> get props => [phone];
}
