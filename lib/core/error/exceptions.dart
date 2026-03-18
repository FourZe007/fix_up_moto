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
