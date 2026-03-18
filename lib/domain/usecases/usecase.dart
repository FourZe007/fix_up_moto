import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:fix_up_moto/core/error/failures.dart';

/// Base contract for all use cases that require input parameters.
///
/// Type parameters:
/// - [T] — the success return value (e.g. [UserEntity], [List<ServiceEntity>])
/// - [P] — the input parameter object (e.g. [LoginParams], [NoParams])
///
/// The [call] method lets callers invoke a use case like a plain function:
///   `final result = await loginUseCase(LoginParams(email: ..., password: ...));`
///
/// Returns `Either<Failure, T>`:
/// - `Left(failure)` — something went wrong; the caller handles it
/// - `Right(value)`  — success; the caller uses the value
///
/// This signature forces every use case caller to handle both paths
/// without relying on try/catch bleeding across layer boundaries.
abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

/// Base contract for use cases that need **no** input parameters.
///
/// Example: `GetCurrentUserUseCase` reads from local cache with no arguments.
///   `final result = await getCurrentUserUseCase();`
abstract class NoParamsUseCase<T> {
  Future<Either<Failure, T>> call();
}

/// Sentinel parameter type passed to [UseCase] when no input is needed.
///
/// Usage:
/// ```dart
/// class LogoutUseCase extends UseCase<void, NoParams> { ... }
/// await logoutUseCase(const NoParams());
/// ```
/// [Equatable] support allows [NoParams] to be compared in bloc_test expectations.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object> get props => [];
}
