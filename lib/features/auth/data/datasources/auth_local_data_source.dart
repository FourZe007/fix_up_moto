import 'dart:convert';
import 'dart:developer';
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

  /// Deletes the cached member record — the whole persisted session.
  Future<void> clearUser();

  /// Remembers that the Google account [email] is linked to [phone], so a
  /// future Google sign-in with the same account can skip the
  /// complete-profile form. Survives [clearUser] — see
  /// [ApiConstants.googleAccountPhonesKey] for why.
  Future<void> rememberGooglePhone({
    required String email,
    required String phone,
  });

  /// Returns the phone number previously linked to the Google account [email]
  /// via [rememberGooglePhone], or null if this device has never completed
  /// Google sign-up for it.
  Future<String?> getRememberedGooglePhone(String email);
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
      return UserModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
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
      // The cached member record is the entire session — no tokens accompany it.
      // Deliberately does NOT touch googleAccountPhonesKey: that mapping must
      // outlive logout so the same Google account is recognised again later.
      await _storage.delete(key: ApiConstants.cachedUserKey);
    } catch (e) {
      throw CacheException(message: 'Failed to clear user session: $e');
    }
  }

  @override
  Future<void> rememberGooglePhone({
    required String email,
    required String phone,
  }) async {
    try {
      final phones = await _readGooglePhones();
      phones[email] = phone;
      await _storage.write(
        key: ApiConstants.googleAccountPhonesKey,
        value: jsonEncode(phones),
      );
    } catch (e) {
      throw CacheException(message: 'Failed to remember Google account: $e');
    }
  }

  @override
  Future<String?> getRememberedGooglePhone(String email) async {
    try {
      final phones = await _readGooglePhones();
      return phones[email];
    } catch (e) {
      throw CacheException(message: 'Failed to read Google account cache: $e');
    }
  }

  /// Reads and decodes the `{email: phone}` map, or an empty map if nothing
  /// has been stored yet. Shared by both methods above so the JSON
  /// encode/decode logic exists in exactly one place.
  Future<Map<String, String>> _readGooglePhones() async {
    final jsonString = await _storage.read(
      key: ApiConstants.googleAccountPhonesKey,
    );
    log('Read local memory, find email and phone', name: '_readGooglePhones');
    if (jsonString == null) return {};

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }
}
