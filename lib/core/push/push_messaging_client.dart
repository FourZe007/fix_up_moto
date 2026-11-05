import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:fix_up_moto/core/push/push_message.dart';

/// Whether the phone lets this app show notifications.
enum PushPermission { granted, denied, notDetermined }

/// Everything the app needs from Firebase Cloud Messaging, and nothing else.
///
/// The one seam between the app and the `firebase_messaging` plugin: the push
/// service talks to this, so tests can stand in a fake and the plugin's static
/// streams stay out of the rest of the code.
abstract interface class PushMessagingClient {
  /// The current permission, without asking.
  ///
  /// Android cannot tell "never asked" from "refused" (both read as
  /// [PushPermission.denied]); iOS can. The service therefore keeps its own
  /// "already asked" flag rather than relying on [PushPermission.notDetermined].
  Future<PushPermission> permission();

  /// Shows the system permission dialog (Android 13+ and iOS; older Android has
  /// no dialog and is already granted) and returns the answer.
  Future<PushPermission> requestPermission();

  /// This phone's FCM token, or null when there is none yet (no Google Play
  /// services, or iOS has not received its APNs token).
  Future<String?> getToken();

  /// A fresh token, whenever Firebase rotates it (or, on iOS, first has one).
  Stream<String> get onTokenRefresh;

  /// A push that arrived while the app is open on screen. Android does not draw
  /// these itself, so the app shows its own banner.
  Stream<PushMessage> get onForegroundMessage;

  /// The member tapped a notification while the app was in the background.
  Stream<PushMessage> get onMessageOpenedApp;

  /// The notification whose tap started the app from closed, if any. Read it
  /// once at start-up.
  Future<PushMessage?> getInitialMessage();

  /// Joins [topic]: a group that the Firebase console (or a server) can send one
  /// message to, with no list of tokens kept anywhere. Joining twice is harmless.
  ///
  /// There is no matching "leave" on purpose: [deleteToken] at sign-out discards
  /// the token the subscription hangs on. Topics are public — any app instance
  /// can join any name — so they are for broadcasts, never for one member's data.
  Future<void> subscribeToTopic(String topic);

  /// Forgets this phone's token, so pushes sent to it stop arriving. Used on
  /// sign-out, so the next member to sign in on this phone does not receive the
  /// previous member's notifications.
  Future<void> deleteToken();
}

/// [PushMessagingClient] over the real `firebase_messaging` plugin.
class FirebasePushMessagingClient implements PushMessagingClient {
  FirebaseMessaging? _messaging;

  /// Resolved on first use, not in the constructor, so building it never
  /// touches Firebase before `Firebase.initializeApp` has run.
  FirebaseMessaging get _fcm => _messaging ??= FirebaseMessaging.instance;

  FirebasePushMessagingClient([this._messaging]);

  static PushPermission _permissionOf(AuthorizationStatus status) =>
      switch (status) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  static PushMessage _messageOf(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: Map<String, Object?>.from(message.data),
  );

  @override
  Future<PushPermission> permission() async {
    final settings = await _fcm.getNotificationSettings();
    return _permissionOf(settings.authorizationStatus);
  }

  @override
  Future<PushPermission> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return _permissionOf(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      // No Google Play services on the phone, or iOS has no APNs token yet
      // (onTokenRefresh delivers it once it arrives). Not worth an error.
      log('getToken failed: $e', name: 'FirebasePushMessagingClient');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_messageOf);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_messageOf);

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    return message == null ? null : _messageOf(message);
  }

  @override
  Future<void> subscribeToTopic(String topic) => _fcm.subscribeToTopic(topic);

  @override
  Future<void> deleteToken() => _fcm.deleteToken();
}
