import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// What the backend files a push token under — the `SerialNumber` of its
/// `FBTOKEN` record. Behind an interface so the registrar can be tested without
/// the plugin.
abstract interface class DeviceNameSource {
  /// The phone's name, or an empty string when it cannot be read.
  Future<String> deviceName();
}

/// The same value 1.0 sent: the Android model (e.g. "SM-A546E"), or the name the
/// iPhone reports for itself.
///
/// Matching 1.0 matters: if the server keys a member's tokens by this value, a
/// phone updating from 1.0 replaces its old record instead of adding a second.
class PlatformDeviceNameSource implements DeviceNameSource {
  DeviceInfoPlugin? _plugin;

  PlatformDeviceNameSource([this._plugin]);

  DeviceInfoPlugin get _info => _plugin ??= DeviceInfoPlugin();

  @override
  Future<String> deviceName() async {
    try {
      if (Platform.isAndroid) return (await _info.androidInfo).model;
      if (Platform.isIOS) return (await _info.iosInfo).name;
    } catch (e) {
      log('Could not read the device name: $e', name: 'DeviceNameSource');
    }
    return '';
  }
}
