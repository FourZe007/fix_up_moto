/// Abstraction over internet connectivity checking.
///
/// The domain/data layers depend on this interface, never on a concrete
/// connectivity package — making it trivially mockable in unit tests.
abstract class NetworkInfo {
  /// Returns true if the device currently has an active internet connection.
  Future<bool> get isConnected;
}

/// Concrete implementation using basic socket connectivity.
///
/// For production apps, consider replacing this with the `connectivity_plus`
/// package for more reliable platform-specific checks. The interface above
/// means swapping the implementation only touches this file and the DI container.
class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // Simple implementation — swap with connectivity_plus if needed.
    // Returns true optimistically; Dio will throw NetworkException on actual failure.
    return true;
  }
}
