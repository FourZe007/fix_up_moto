import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:fix_up_moto/features/invoices/data/datasources/receipt_storage_data_source.dart';

class MockFileSaver extends Mock implements FileSaver {}

// The iOS branch (saveFile into the app's Documents) is picked by
// Platform.isIOS, which a test on this machine cannot change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewerChannel = MethodChannel('com.stsj.fixupmotoapps/receipt_viewer');
  const tContentUri = 'content://media/external/downloads/42';

  late MockFileSaver fileSaver;
  late ReceiptStorageDataSource dataSource;

  final tPdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]);

  setUpAll(() {
    registerFallbackValue(MimeType.pdf);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    fileSaver = MockFileSaver();
    dataSource = FileSaverReceiptStorageDataSource(
      fileSaver: fileSaver,
      viewer: viewerChannel,
    );
  });

  When<Future<String?>> whenSaving() => when(
    () => fileSaver.saveToDownloads(
      name: any(named: 'name'),
      bytes: any(named: 'bytes'),
      fileExtension: any(named: 'fileExtension'),
      mimeType: any(named: 'mimeType'),
    ),
  );

  Future<String?> save() =>
      dataSource.savePdf(name: '3101SNT26100001', bytes: tPdf);

  group('savePdf', () {
    test(
      'saves the bytes as a PDF in Downloads, named after the invoice',
      () async {
        whenSaving().thenAnswer((_) async => tContentUri);

        await save();

        verify(
          () => fileSaver.saveToDownloads(
            name: '3101SNT26100001',
            bytes: tPdf,
            fileExtension: 'pdf',
            mimeType: MimeType.pdf,
          ),
        ).called(1);
      },
    );

    test('answers with where it was saved, a content URI', () async {
      whenSaving().thenAnswer((_) async => tContentUri);

      expect(await save(), tContentUri);
    });

    test(
      'a plain file path (Android 9 and below) cannot be opened again',
      () async {
        whenSaving().thenAnswer(
          (_) async => '/storage/emulated/0/Download/3101SNT26100001.pdf',
        );

        expect(await save(), isNull);
      },
    );

    test('a save that says nowhere cannot be opened again', () async {
      whenSaving().thenAnswer((_) async => null);

      expect(await save(), isNull);
    });

    test('a refused permission is a CacheException that says so', () async {
      whenSaving().thenThrow(PlatformException(code: 'PermissionDenied'));

      await expectLater(
        save(),
        throwsA(
          isA<CacheException>().having(
            (e) => e.message,
            'message',
            'Storage permission is needed to save the receipt',
          ),
        ),
      );
    });

    test('any other platform error is a CacheException', () async {
      whenSaving().thenThrow(PlatformException(code: 'WriteFailed'));

      await expectLater(
        save(),
        throwsA(
          isA<CacheException>().having(
            (e) => e.message,
            'message',
            'The receipt could not be saved',
          ),
        ),
      );
    });

    test('a platform that cannot save is a CacheException', () async {
      whenSaving().thenThrow(UnsupportedError('no downloads folder'));

      expect(save(), throwsA(isA<CacheException>()));
    });
  });

  group('openPdf', () {
    void answerChannel(Future<Object?>? Function(MethodCall call) handler) {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(viewerChannel, handler);
      addTearDown(
        () => messenger.setMockMethodCallHandler(viewerChannel, null),
      );
    }

    Matcher cacheException(String message) => throwsA(
      isA<CacheException>().having((e) => e.message, 'message', message),
    );

    test('asks the phone to show the PDF at that location', () async {
      final calls = <MethodCall>[];
      answerChannel((call) async {
        calls.add(call);
        return true;
      });

      await dataSource.openPdf(tContentUri);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'openPdf');
      expect(calls.single.arguments, {'location': tContentUri});
    });

    test('no app to show it is a CacheException that says so', () async {
      answerChannel((call) async => false);

      await expectLater(
        dataSource.openPdf(tContentUri),
        cacheException('No app was found to open the receipt'),
      );
    });

    test('an answer of nothing counts as not opened', () async {
      answerChannel((call) async => null);

      await expectLater(
        dataSource.openPdf(tContentUri),
        cacheException('No app was found to open the receipt'),
      );
    });

    test('a platform error is a CacheException', () async {
      answerChannel((call) async => throw PlatformException(code: 'error'));

      await expectLater(
        dataSource.openPdf(tContentUri),
        cacheException('The receipt could not be opened'),
      );
    });

    test('a platform nothing answers on is a CacheException', () async {
      // No handler on the channel: what iOS and the desktop look like.
      await expectLater(
        dataSource.openPdf(tContentUri),
        cacheException('The receipt could not be opened'),
      );
    });
  });
}
