import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:fix_up_moto/core/error/exceptions.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;

/// Where a downloaded receipt is put on the phone, and how it is shown again.
abstract class ReceiptStorageDataSource {
  /// Saves [bytes] as `<name>.pdf` where the member can find it: the Download
  /// folder on Android, the app's folder in the Files app on iOS.
  ///
  /// Returns where it was saved if it can be opened again with [openPdf], else
  /// null. Only Android can: iOS has no opener yet.
  ///
  /// Throws [CacheException] when it cannot be written.
  Future<String?> savePdf({required String name, required Uint8List bytes});

  /// Shows the PDF saved at [location] (as returned by [savePdf]) in an app on
  /// the phone.
  ///
  /// Throws [CacheException] when no app can show it.
  Future<void> openPdf(String location);
}

/// Saves through the `file_saver` package and opens through a method channel
/// answered by `MainActivity`.
///
/// On Android 10+ the file goes into `Download/` through MediaStore, which
/// needs no permission and no dialog, and what comes back is the file's
/// `content://` URI. Android 9 and below would need the storage permission
/// granted at run time, which the app does not ask for, so a save there fails
/// with a message that says so. iOS has no shared Downloads folder; the file
/// goes to the app's Documents, which Info.plist shows in Files.
class FileSaverReceiptStorageDataSource implements ReceiptStorageDataSource {
  static const _viewerChannel = MethodChannel(
    'com.stsj.fixupmotoapps/receipt_viewer',
  );

  final FileSaver _fileSaver;
  final MethodChannel _viewer;

  FileSaverReceiptStorageDataSource({
    FileSaver? fileSaver,
    MethodChannel? viewer,
  }) : _fileSaver = fileSaver ?? FileSaver.instance,
       _viewer = viewer ?? _viewerChannel;

  @override
  Future<String?> savePdf({
    required String name,
    required Uint8List bytes,
  }) async {
    try {
      if (Platform.isIOS) {
        await _fileSaver.saveFile(
          name: name,
          bytes: bytes,
          fileExtension: 'pdf',
          mimeType: MimeType.pdf,
        );
        return null;
      }

      final location = await _fileSaver.saveToDownloads(
        name: name,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      // Older Androids answer with a file path, which a viewer cannot be handed
      // safely; only a content URI can be opened again.
      return location != null && location.startsWith('content://')
          ? location
          : null;
    } on PlatformException catch (e) {
      throw CacheException(
        message: e.code == 'PermissionDenied'
            ? 'Storage permission is needed to save the receipt'
            : 'The receipt could not be saved',
      );
    } on Exception {
      throw const CacheException(message: 'The receipt could not be saved');
    } on UnsupportedError {
      // A platform file_saver cannot write to.
      throw const CacheException(message: 'The receipt could not be saved');
    }
  }

  @override
  Future<void> openPdf(String location) async {
    bool? opened;
    try {
      opened = await _viewer.invokeMethod<bool>('openPdf', {
        'location': location,
      });
    } on PlatformException {
      throw const CacheException(message: 'The receipt could not be opened');
    } on MissingPluginException {
      // A platform nothing answers the channel on.
      throw const CacheException(message: 'The receipt could not be opened');
    }

    if (opened != true) {
      throw const CacheException(
        message: 'No app was found to open the receipt',
      );
    }
  }
}
