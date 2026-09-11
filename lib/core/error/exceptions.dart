/// Raw exceptions thrown exclusively by the **Data layer** (datasources).
///
/// These never cross into Domain or Presentation. Repository implementations
/// catch them and convert them into [Failure] subtypes (see failures.dart).
library;

/// Thrown when the REST API returns a non-2xx status code (4xx, 5xx).
/// [statusCode] carries the HTTP status so the repository can distinguish
/// a 400 Bad Request from a 500 Internal Server Error.
class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown when a local storage read/write fails
/// (e.g. FlutterSecureStorage throws, SharedPreferences is corrupt).
class CacheException implements Exception {
  final String message;

  const CacheException({required this.message});

  @override
  String toString() => 'CacheException: $message';
}

/// Thrown when the device has no internet connectivity.
/// Raised by the data source before making a network call,
/// or by DioException with type == connectionError.
class NetworkException implements Exception {
  final String message;

  const NetworkException({required this.message});

  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown when the API returns HTTP 401 (token missing, expired, or invalid).
/// The auth interceptor clears the stored token when it sees a 401.
class UnauthorizedException implements Exception {
  const UnauthorizedException();

  @override
  String toString() => 'UnauthorizedException: session expired or invalid token';
}

/// Thrown when credentials were accepted but the membership is not permitted
/// to sign in — expired, suspended, or pending verification.
///
/// Distinct from [UnauthorizedException]: the credentials were *correct*, so
/// "wrong email or password" would be a misleading thing to tell the user.
/// [message] carries the backend's own wording (the SAMP `Status` field) so the
/// real reason reaches the screen instead of a guess.
class AccountInactiveException implements Exception {
  final String message;

  const AccountInactiveException({required this.message});

  @override
  String toString() => 'AccountInactiveException: $message';
}

/// Thrown when the user dismisses the Google account sheet.
///
/// **Not an error.** Backing out of a sign-in sheet is a normal choice, and the
/// UI must stay silent about it — no SnackBar, no red banner. It exists as a
/// distinct type purely so the repository can translate it into a failure the
/// BLoC recognises as "say nothing".
class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();

  @override
  String toString() => 'GoogleSignInCancelledException: dismissed by user';
}

/// Thrown when the API returns HTTP 403 (authenticated but lacks permission).
class ForbiddenException implements Exception {
  final String message;

  const ForbiddenException({this.message = 'Access denied'});

  @override
  String toString() => 'ForbiddenException: $message';
}

/// Thrown when the API returns HTTP 404 (requested resource does not exist).
class NotFoundException implements Exception {
  final String message;

  const NotFoundException({this.message = 'Resource not found'});

  @override
  String toString() => 'NotFoundException: $message';
}
