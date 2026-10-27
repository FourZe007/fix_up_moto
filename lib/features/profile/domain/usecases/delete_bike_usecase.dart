import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/usecases/usecase.dart';
import 'package:fix_up_moto/features/profile/domain/repositories/bikes_repository.dart';

class DeleteBikeUseCase extends UseCase<void, DeleteBikeParams> {
  final BikesRepository repository;
  DeleteBikeUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteBikeParams params) {
    return repository.deleteBike(line: params.line);
  }
}

class DeleteBikeParams extends Equatable {
  /// The record's row number, as the list returned it — says which bike.
  final String line;

  const DeleteBikeParams({required this.line});

  @override
  List<Object> get props => [line];
}
