import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/otp/domain/entities/otp_request.dart';
import 'package:fix_up_moto/features/otp/domain/repositories/otp_repository.dart';

class SendOtpUseCase extends UseCase<Unit, SendOtpParams> {
  final OtpRepository _repository;

  SendOtpUseCase(this._repository);

  @override
  Future<Either<Failure, Unit>> call(SendOtpParams params) =>
      _repository.sendCode(request: params.request, code: params.code);
}

class SendOtpParams extends Equatable {
  final OtpRequest request;

  /// The code to deliver. Kept out of [toString] output on purpose.
  final String code;

  const SendOtpParams({required this.request, required this.code});

  @override
  List<Object> get props => [request, code];

  /// Never print the code, even where an Equatable would.
  @override
  bool? get stringify => false;
}
