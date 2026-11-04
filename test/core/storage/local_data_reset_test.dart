import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/storage/local_data_reset.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

Future<SharedPreferences> prefsWith(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  return SharedPreferences.getInstance();
}

void main() {
  late MockSecureStorage secureStorage;

  /// Stand-ins for the phone's cache folder and app-support folder, so the
  /// tests never touch the real ones.
  late Directory cacheDir;
  late Directory supportDir;

  setUp(() {
    secureStorage = MockSecureStorage();
    when(() => secureStorage.deleteAll()).thenAnswer((_) async {});

    cacheDir = Directory.systemTemp.createTempSync('reset_cache_');
    supportDir = Directory.systemTemp.createTempSync('reset_support_');
    addTearDown(() {
      cacheDir.deleteSync(recursive: true);
      supportDir.deleteSync(recursive: true);
    });
  });

  Future<bool> run(SharedPreferences prefs) => LocalDataReset.runIfNeeded(
    prefs: prefs,
    secureStorage: secureStorage,
    cacheDirectory: () async => cacheDir,
    supportDirectory: () async => supportDir,
  );

  /// Writes a small file at [relative] under [root], making folders as needed.
  File put(Directory root, String relative) =>
      File('${root.path}${Platform.pathSeparator}$relative')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');

  /// What 1.0 left on a phone: a theme choice, the welcome flag and so on, and
  /// no generation, since 1.0 never wrote one.
  const oldData = <String, Object>{
    'theme_mode': 'dark',
    'welcome_seen': true,
    'something_from_1_0': 'x',
  };

  test('is stored under local_data_generation', () {
    expect(LocalDataReset.key, 'local_data_generation');
  });

  group('when no generation is stored (every 1.0 install)', () {
    test('wipes secure storage and preferences, and says so', () async {
      final prefs = await prefsWith(oldData);

      final wiped = await run(prefs);

      expect(wiped, isTrue);
      verify(() => secureStorage.deleteAll()).called(1);
      expect(prefs.getString('theme_mode'), isNull);
      expect(prefs.get('welcome_seen'), isNull);
      expect(prefs.get('something_from_1_0'), isNull);
    });

    test('leaves only the generation behind', () async {
      final prefs = await prefsWith(oldData);

      await run(prefs);

      expect(prefs.getKeys(), {LocalDataReset.key});
      expect(prefs.getInt(LocalDataReset.key), LocalDataReset.generation);
    });
  });

  test('on a fresh install it only writes the generation', () async {
    final prefs = await prefsWith({});

    final wiped = await run(prefs);

    // Still wipes secure storage: on iPhone the Keychain can outlive an
    // uninstall, so a "fresh" install may not be fresh underneath.
    expect(wiped, isTrue);
    verify(() => secureStorage.deleteAll()).called(1);
    expect(prefs.getKeys(), {LocalDataReset.key});
  });

  group('when the stored generation is current', () {
    test('touches nothing and says so', () async {
      final prefs = await prefsWith({
        ...oldData,
        LocalDataReset.key: LocalDataReset.generation,
      });

      final wiped = await run(prefs);

      expect(wiped, isFalse);
      verifyNever(() => secureStorage.deleteAll());
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.get('welcome_seen'), true);
    });

    test('a second call right after a wipe does nothing', () async {
      final prefs = await prefsWith(oldData);

      final first = await run(prefs);
      // A choice the member makes after the wipe must survive the next launch.
      await prefs.setString('theme_mode', 'light');
      final second = await run(prefs);

      expect(first, isTrue);
      expect(second, isFalse);
      verify(() => secureStorage.deleteAll()).called(1);
      expect(prefs.getString('theme_mode'), 'light');
    });
  });

  group('when the stored generation is not the current one', () {
    test('an older generation wipes', () async {
      final prefs = await prefsWith({
        ...oldData,
        LocalDataReset.key: LocalDataReset.generation - 1,
      });

      final wiped = await run(prefs);

      expect(wiped, isTrue);
      expect(prefs.getInt(LocalDataReset.key), LocalDataReset.generation);
      expect(prefs.getString('theme_mode'), isNull);
    });

    test('a value that is not a number wipes, without throwing', () async {
      final prefs = await prefsWith({...oldData, LocalDataReset.key: 'two'});

      final wiped = await run(prefs);

      expect(wiped, isTrue);
      expect(prefs.getInt(LocalDataReset.key), LocalDataReset.generation);
    });
  });

  group('when secure storage cannot be cleared', () {
    setUp(() {
      when(
        () => secureStorage.deleteAll(),
      ).thenThrow(PlatformException(code: 'keychain'));
    });

    test('does not throw, and leaves the phone as it was', () async {
      final prefs = await prefsWith(oldData);

      final wiped = await run(prefs);

      expect(wiped, isFalse);
      // No generation, so the next launch tries again; nothing half-wiped.
      expect(prefs.get(LocalDataReset.key), isNull);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('the next launch tries again, and finishes the job', () async {
      final prefs = await prefsWith(oldData);
      await run(prefs);

      // The Keychain works this time.
      when(() => secureStorage.deleteAll()).thenAnswer((_) async {});
      final wiped = await run(prefs);

      expect(wiped, isTrue);
      expect(prefs.getKeys(), {LocalDataReset.key});
    });
  });

  group('the old image cache (cached_network_image in 1.0)', () {
    test('deletes the picture folder and the database that lists it', () async {
      final picture = put(cacheDir, 'libCachedImageData/a1b2.jpg');
      final nested = put(cacheDir, 'libCachedImageData/sub/c3.png');
      final db = put(supportDir, 'libCachedImageData.db');
      final journal = put(supportDir, 'libCachedImageData.db-journal');

      await run(await prefsWith(oldData));

      expect(picture.existsSync(), isFalse);
      expect(nested.existsSync(), isFalse);
      expect(
        Directory(
          '${cacheDir.path}${Platform.pathSeparator}libCachedImageData',
        ).existsSync(),
        isFalse,
      );
      expect(db.existsSync(), isFalse);
      expect(journal.existsSync(), isFalse);
    });

    test('leaves every other file alone', () async {
      final otherCache = put(cacheDir, 'something_else/keep.txt');
      final firebase = put(supportDir, 'PersistedInstallation.abc.json');

      await run(await prefsWith(oldData));

      expect(otherCache.existsSync(), isTrue);
      expect(firebase.existsSync(), isTrue);
    });

    test('is kept when no wipe is due', () async {
      final picture = put(cacheDir, 'libCachedImageData/a1b2.jpg');
      final prefs = await prefsWith({
        LocalDataReset.key: LocalDataReset.generation,
      });

      await run(prefs);

      expect(picture.existsSync(), isTrue);
    });

    test('is kept too when secure storage could not be cleared', () async {
      when(
        () => secureStorage.deleteAll(),
      ).thenThrow(PlatformException(code: 'keychain'));
      final picture = put(cacheDir, 'libCachedImageData/a1b2.jpg');

      await run(await prefsWith(oldData));

      // Nothing half-wiped: the whole wipe is tried again next launch.
      expect(picture.existsSync(), isTrue);
    });

    test('has nothing to delete on a phone that never had it', () async {
      final prefs = await prefsWith(oldData);

      expect(await run(prefs), isTrue);
      expect(prefs.getInt(LocalDataReset.key), LocalDataReset.generation);
    });

    test('does not stop the wipe when the folders cannot be found', () async {
      final prefs = await prefsWith(oldData);

      final wiped = await LocalDataReset.runIfNeeded(
        prefs: prefs,
        secureStorage: secureStorage,
        cacheDirectory: () async => throw const FileSystemException('no cache'),
        supportDirectory: () async => throw const FileSystemException('no dir'),
      );

      // The pictures are only disk space: failing to delete them must not
      // undo, or keep repeating, the wipe that matters.
      expect(wiped, isTrue);
      expect(prefs.getKeys(), {LocalDataReset.key});
    });
  });
}
