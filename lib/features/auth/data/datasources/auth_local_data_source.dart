import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fix_up_moto/core/constants/api_constants.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/auth/data/models/user_model.dart';

/// Contract for reading/writing auth data in local storage.
abstract class AuthLocalDataSource {
  /// Persists [user] as JSON in the OS keychain so it survives app restarts.
  Future<void> cacheUser(UserModel user);

  /// Reads the cached user JSON and deserialises it.
  /// Returns null if no user has been cached (first launch / after logout).
  /// Throws [CacheException] if the stored JSON is corrupted.
  Future<UserModel?> getCachedUser();

  /// Deletes the cached user and auth tokens from secure storage.
  Future<void> clearUser();
}

/// Concrete implementation backed by [FlutterSecureStorage].
///
/// FlutterSecureStorage writes to:
/// - iOS/macOS: Keychain
/// - Android:   EncryptedSharedPreferences
/// - Windows:   Windows Credential Locker
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _storage;

  AuthLocalDataSourceImpl(this._storage);

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      // Serialise the model to a JSON string before storing — secure storage
      // only accepts String values, not arbitrary objects.
      await _storage.write(
        key: ApiConstants.cachedUserKey,
        value: jsonEncode(user.toJson()),
      );
    } catch (e) {
      throw CacheException(message: 'Failed to cache user: $e');
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final jsonString = await _storage.read(key: ApiConstants.cachedUserKey);

      // null means no entry exists — not an error, just "not logged in"
      if (jsonString == null) return null;

      // Decode JSON string → Map → UserModel
      return UserModel.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } on FormatException catch (e) {
      // The stored JSON was malformed — treat as a corrupted cache
      throw CacheException(message: 'Corrupted user cache: ${e.message}');
    } catch (e) {
      throw CacheException(message: 'Failed to read cached user: $e');
    }
  }

  @override
  Future<void> clearUser() async {
    try {
      // Delete both the user profile and the auth tokens in parallel
      await Future.wait([
        _storage.delete(key: ApiConstants.cachedUserKey),
        _storage.delete(key: ApiConstants.tokenKey),
        _storage.delete(key: ApiConstants.refreshTokenKey),
      ]);
    } catch (e) {
      throw CacheException(message: 'Failed to clear user session: $e');
    }
  }
}
