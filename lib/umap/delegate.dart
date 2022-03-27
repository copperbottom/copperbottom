abstract class UmapDelegate {
  /// Authenticates a user with the specified [username] and [password] for the
  /// connection represented by this delegate.
  authenticate({
    required String username,
    required String password,
  });
}
