import 'package:equatable/equatable.dart';

/// Domain-safe representations of errors.
///
/// **Rule:** nothing in the Domain or Presentation layers throws or catches
/// raw exceptions. Instead, repository implementations convert exceptions into
/// [Failure] subtypes and return them as `Left(failure)` via `Either`.
///
/// Extending [Equatable] ensures that two Failure instances with the same
/// message and subtype compare as equal — important for BLoC state comparison
/// and `BlocBuilder` rebuild decisions.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  /// Equatable uses [props] to compute == and hashCode.
  /// Subclasses override this if they carry additional fields (e.g. statusCode).
  @override
  List<Object> get props => [message];
}

/// API returned a non-2xx response. [statusCode] is optional but helpful for
/// displaying different UX for 404 (not found) vs 500 (server down).
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object> get props => [message, statusCode ?? 0];
}

/// Local storage (SharedPreferences / FlutterSecureStorage) read/write failed.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Device has no internet connection — raised before making a network call.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Authentication failed — wrong credentials, expired token, or missing session.
/// Maps to [UnauthorizedException] from the data layer.
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// The user backed out of an authentication flow they started.
///
/// Carries a message only for logging — **the UI must not display it**. A user
/// who dismisses the Google sheet has not hit an error and should simply be
/// returned to the form. [AuthBloc] checks for this type and emits
/// [AuthUnauthenticated] rather than [AuthError].
class AuthCancelledFailure extends Failure {
  const AuthCancelledFailure([super.message = 'Sign-in cancelled']);
}

/// Authenticated user does not have the required permission.
/// Maps to [ForbiddenException] from the data layer.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Requested resource could not be found (HTTP 404 equivalent).
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Form or business rule validation error.
/// [fieldErrors] maps field names to their individual error messages so the UI
/// can highlight specific inputs (e.g. {'email': 'Invalid format'}).
class ValidationFailure extends Failure {
  final Map<String, String> fieldErrors;

  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  @override
  List<Object> get props => [message, fieldErrors];
}
