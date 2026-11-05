import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:fix_up_moto/core/theme/app_colors.dart';

/// A notification the app draws itself, as opposed to one Firebase delivers.
///
/// The seam between the app and the `flutter_local_notifications` plugin, like
/// [PushMessagingClient] is for Firebase: the inbox code talks to this, so tests
/// can stand in a fake.
///
/// Used for messages the app learns about by *asking its own server* (the inbox),
/// which is the only way to tell a member "your booking is confirmed" without a
/// backend that sends pushes.
abstract interface class LocalNotifier {
  /// Prepares the plugin. Safe to call more than once, and in a background
  /// isolate.
  Future<void> init();

  /// Whether a notification could be shown right now. False off Android (only
  /// Android has a background check; elsewhere the app is open and uses its own
  /// banner) and when the member turned notifications off.
  Future<bool> canShow();

  /// Shows one notification. [key] makes the same message replace itself rather
  /// than stack if it is shown twice.
  Future<void> show({
    required String key,
    required String title,
    required String body,
  });

  /// Fires when the member taps one of these notifications while the app lives.
  Stream<void> get taps;

  /// Whether a tap on one of these notifications is what started the app.
  Future<bool> launchedByTap();
}

/// [LocalNotifier] over the real plugin.
class FlutterLocalNotifier implements LocalNotifier {
  /// Same id as `default_notification_channel_id` in AndroidManifest.xml and
  /// `PUSH_CHANNEL_ID` in MainActivity, so every notification the app shows,
  /// pushed or local, is one channel in the system settings.
  static const String channelId = 'fixup_moto_default';
  static const String _channelName = 'Notifikasi FixUp Moto';
  static const String _channelDescription =
      'Info booking, servis, dan promo dari FixUp Moto';

  /// The status-bar silhouette (res/drawable-*/ic_stat_notification.png) — the
  /// full-colour launcher icon would show as a flat white square.
  static const String _statusBarIcon = 'ic_stat_notification';

  /// What the notification carries, so a tap on it can be told from any other.
  static const String _tapPayload = 'inbox';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<void> _taps = StreamController<void>.broadcast();
  Future<void>? _ready;

  FlutterLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_statusBarIcon),
        // Initialised so the plugin is complete, but never asked for
        // permission and never shown on: the permission belongs to
        // PushNotificationService, and iPhone has no background check.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _tapPayload) _taps.add(null);
      },
    );
  }

  @override
  Future<bool> canShow() async {
    if (!_isAndroid) return false;
    try {
      await init();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (e) {
      log('canShow failed: $e', name: 'FlutterLocalNotifier');
      return false;
    }
  }

  @override
  Future<void> show({
    required String key,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.show(
      // Positive, as Android wants; a clash only means one replaces the other.
      id: key.hashCode & 0x7fffffff,
      title: title,
      body: body,
      payload: _tapPayload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: _statusBarIcon,
          color: AppColors.primary,
          // The whole text on expanding, line breaks included.
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  @override
  Stream<void> get taps => _taps.stream;

  @override
  Future<bool> launchedByTap() async {
    try {
      await init();
      final details = await _plugin.getNotificationAppLaunchDetails();
      return details?.didNotificationLaunchApp == true &&
          details?.notificationResponse?.payload == _tapPayload;
    } catch (e) {
      log('launchedByTap failed: $e', name: 'FlutterLocalNotifier');
      return false;
    }
  }
}
