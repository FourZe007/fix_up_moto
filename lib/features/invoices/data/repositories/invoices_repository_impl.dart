import 'package:dartz/dartz.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/core/error/failures.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/features/auth/domain/repositories/auth_repository.dart';
import 'package:fix_up_moto/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:fix_up_moto/features/invoices/domain/entities/invoice_entity.dart';
import 'package:fix_up_moto/features/invoices/domain/repositories/invoices_repository.dart';

class InvoicesRepositoryImpl implements InvoicesRepository {
  final InvoicesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  /// The invoices belong to one member, and the backend has no "who am I"
  /// endpoint — the caller supplies MemberID itself. The cached session, read
  /// through Auth's own repository (see HomeRepositoryImpl for why not a use
  /// case), is the only place it exists on the client.
  final AuthRepository authRepository;

  const InvoicesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.authRepository,
  });

  @override
  Future<Either<Failure, List<InvoiceEntity>>> getInvoices({
    required InvoiceType type,
    required DateTime beginDate,
    required DateTime endDate,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    final currentUserResult = await authRepository.getCurrentUser();

    return currentUserResult.fold((failure) async => Left(failure), (
      user,
    ) async {
      if (user == null) {
        return const Left(AuthFailure('No signed-in member found'));
      }

      try {
        final models = await remoteDataSource.getInvoices(
          memberId: user.id,
          kode: type.wireValue,
          beginDate: beginDate,
          endDate: endDate,
        );

        // In the order the backend sent them.
        return Right(models.map((m) => m.toEntity()).toList());
      } on UnauthorizedException {
        return const Left(
          AuthFailure('Session expired. Please sign in again.'),
        );
      } on ForbiddenException catch (e) {
        return Left(PermissionFailure(e.message));
      } on NotFoundException catch (e) {
        return Left(NotFoundFailure(e.message));
      } on ServerException catch (e) {
        return Left(ServerFailure(e.message, statusCode: e.statusCode));
      }
    });
  }
}
