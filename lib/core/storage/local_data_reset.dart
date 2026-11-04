import 'dart:developer';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clears everything the app saved on the phone, once, the first time a build
/// that expects a newer [generation] starts.
///
/// **Why:** 2.0 is an update of 1.0 (same app ID), and an update keeps the old
/// app's data. Rather than guess what 1.0 left behind and whether 2.0 can read
/// it, 2.0 starts empty. 1.0 never wrote [key], so every 1.0 install counts as
/// "older" and is wiped exactly once.
///
/// What goes: secure storage, every preference, and the pictures 1.0
/// downloaded (see [_oldImageCache]), which 2.0 never reads.
///
/// A fresh install is wiped too, which is deliberate: on iPhone the Keychain
/// can outlive an uninstall (the reason `WelcomeSeen` lives in preferences), so
/// a fresh install may not be fresh underneath.
///
/// The generation is kept in [SharedPreferences], which an uninstall removes
/// but an update does not. **Bump [generation] only when a later release must
/// wipe again**; leave it alone otherwise, or every update would log everyone
/// out.
abstract final class LocalDataReset {
  /// Which wipe this build is. 2 = the one that shipped with 2.0.
  static const int generation = 2;

  static const String key = 'local_data_generation';

  /// What 1.0's image cache is called. 1.0 showed network pictures with
  /// `cached_network_image`, whose cache manager (flutter_cache_manager 3.4.2,
  /// the version 1.0 shipped) keeps the picture files in a folder of this name
  /// inside the phone's cache folder, and a small SQLite database listing them,
  /// `<name>.db`, in the app-support folder.
  static const String _oldImageCache = 'libCachedImageData';

  /// SQLite keeps its journal and write-ahead files next to the database.
  static const List<String> _databaseFiles = [
    '.db',
    '.db-journal',
    '.db-wal',
    '.db-shm',
  ];

  /// Wipes if the stored generation is not [generation]; returns `true` when it
  /// did, `false` when there was nothing to do or the wipe could not finish.
  ///
  /// Order matters: secure storage first, then preferences, then the old
  /// pictures, and the generation **last**. A launch cut short midway therefore
  /// finds no generation and wipes again, which is safe to repeat.
  ///
  /// Never throws. If secure storage cannot be cleared the phone is left as it
  /// was, the generation is not written, and the next launch tries again; the
  /// app still starts. The pictures are only disk space, so failing to delete
  /// them is logged and never undoes or repeats the wipe.
  ///
  /// [cacheDirectory] and [supportDirectory] default to the phone's real
  /// folders; tests hand in temporary ones.
  static Future<bool> runIfNeeded({
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
    Future<Directory> Function() cacheDirectory = getTemporaryDirectory,
    Future<Directory> Function() supportDirectory =
        getApplicationSupportDirectory,
  }) async {
    // `get`, not `getInt`: getInt throws on a value that is not an int, and a
    // corrupt entry should simply count as "needs a wipe".
    if (prefs.get(key) == generation) return false;

    try {
      await secureStorage.deleteAll();
      await prefs.clear();
      await _deleteOldImageCache(cacheDirectory, supportDirectory);
      await prefs.setInt(key, generation);
      return true;
    } catch (e) {
      log(
        'Could not wipe local data, will retry next launch: $e',
        name: 'LocalDataReset',
      );
      return false;
    }
  }

  /// Deletes 1.0's downloaded pictures and the database that lists them, and
  /// nothing else in those two folders. Never throws.
  static Future<void> _deleteOldImageCache(
    Future<Directory> Function() cacheDirectory,
    Future<Directory> Function() supportDirectory,
  ) async {
    await _bestEffort('the old picture folder', () async {
      final cache = await cacheDirectory();
      final pictures = Directory(_join(cache.path, _oldImageCache));
      if (await pictures.exists()) await pictures.delete(recursive: true);
    });

    await _bestEffort('the old picture database', () async {
      final support = await supportDirectory();
      for (final suffix in _databaseFiles) {
        final file = File(_join(support.path, '$_oldImageCache$suffix'));
        if (await file.exists()) await file.delete();
      }
    });
  }

  static Future<void> _bestEffort(
    String what,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      log('Could not delete $what: $e', name: 'LocalDataReset');
    }
  }

  static String _join(String folder, String name) =>
      '$folder${Platform.pathSeparator}$name';
}
