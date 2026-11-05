/// Tells the backend which phone to send the signed-in member's pushes to.
///
/// The real one is `RemotePushTokenRegistrar` (notification feature), over the
/// `FBTOKEN` record of the `Modify` endpoint. Neither method may throw to its
/// caller for an ordinary failure (offline, refused): the push service never
/// depends on the answer, so implementations log and return.
abstract interface class PushTokenRegistrar {
  /// Sends [token] to the backend for the signed-in member. Called after
  /// sign-in (so on every start with a saved session, as 1.0 did on every Home
  /// load) and again whenever Firebase rotates the token.
  Future<void> register(String token);

  /// Makes the backend forget [token] for the signed-in member. Must run while
  /// the session still exists — i.e. before logout clears it.
  Future<void> unregister(String token);
}
