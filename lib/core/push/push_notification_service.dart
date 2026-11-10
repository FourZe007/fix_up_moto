import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fix_up_moto/core/push/push_message.dart';
import 'package:fix_up_moto/core/push/push_messaging_client.dart';
import 'package:fix_up_moto/core/push/push_token_registrar.dart';

/// Push notifications for the signed-in member: asks permission, hands this
/// phone's token to the backend, and reports what arrives and what is tapped.
///
/// It has no UI. [PushBootstrap] drives it from the widget tree (sign-in →
/// [enable], sign-out → [disable]) and turns what it reports into a banner and
/// navigation.
///
/// Two lifetimes, on purpose:
/// - [init] runs for the whole process. A tap on a notification can start the
///   app long before sign-in finishes, so taps are caught from the start and
///   held in [takePendingTap] until the session is ready.
/// - [enable]/[disable] follow the session: the token exists only while a member
///   is signed in.
class PushNotificationService {
  /// Set once the member has answered our "turn on notifications?" explainer
  /// (either way), so it is never shown twice. Lives in [SharedPreferences],
  /// which an uninstall clears — a reinstall may ask again, like the OS would.
  static const String askedKey = 'push_permission_asked';

  /// The topic every signed-in member who allows notifications joins. Sending to
  /// it from the Firebase console reaches all of them with no backend involved —
  /// promos and announcements, never one member's data (anyone can join a topic).
  static const String broadcastTopic = 'all';

  final PushMessagingClient _client;
  final PushTokenRegistrar _registrar;
  final SharedPreferences _prefs;

  final StreamController<PushMessage> _foreground =
      StreamController<PushMessage>.broadcast();
  final StreamController<void> _tapRequests =
      StreamController<void>.broadcast();

  StreamSubscription<PushMessage>? _foregroundSub;
  StreamSubscription<PushMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;

  bool _initialised = false;
  bool _enabled = false;
  Future<bool>? _enabling;

  /// Bumped by [disable], so an [enable] still in flight can tell that the
  /// session it started for has ended and stop instead of switching push on for
  /// whoever signs in next.
  int _session = 0;

  PushMessage? _pendingTap;

  /// The token last handed to the registrar this session, for [unregister].
  String? _registeredToken;

  /// How long sign-out waits for the backend to forget this phone. An offline
  /// phone answers at once; this only bounds a server that hangs.
  final Duration _unregisterTimeout;

  PushNotificationService({
    required PushMessagingClient client,
    required PushTokenRegistrar registrar,
    required SharedPreferences prefs,
    Duration unregisterTimeout = const Duration(seconds: 5),
  }) : _client = client,
       _registrar = registrar,
       _prefs = prefs,
       _unregisterTimeout = unregisterTimeout;

  /// Whether push is switched on for the current session.
  bool get isEnabled => _enabled;

  /// Pushes that arrive while the app is open on screen — only while [isEnabled],
  /// so nothing shows on the login screen.
  Stream<PushMessage> get foregroundMessages => _foreground.stream;

  /// Fires when a notification was tapped and [takePendingTap] has something.
  Stream<void> get tapRequests => _tapRequests.stream;

  /// Starts listening for pushes and taps. Safe to call more than once.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    _foregroundSub = _client.onForegroundMessage.listen((message) {
      if (_enabled) _foreground.add(message);
    });
    _openedSub = _client.onMessageOpenedApp.listen(_requestOpen);

    try {
      // The tap that started the app from closed, if that is what happened.
      final initial = await _client.getInitialMessage();
      if (initial != null) _requestOpen(initial);
    } catch (e) {
      log('getInitialMessage failed: $e', name: 'PushNotificationService');
    }
  }

  void _requestOpen(PushMessage message) {
    _pendingTap = message;
    _tapRequests.add(null);
  }

  /// A tap on one of the app's own notifications (the ones it draws after
  /// finding something new in the inbox) — not a Firebase push, so [init] cannot
  /// see it. Held and delivered exactly like a push tap.
  void requestOpenInbox() => _requestOpen(const PushMessage());

  /// The tapped notification waiting to be opened, once; null when none is.
  /// Whoever calls it owns showing it: a second call returns null.
  PushMessage? takePendingTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    return tap;
  }

  /// Switches push on for the signed-in member: makes sure the phone allows
  /// notifications (asking first, once, through [askMember]), then registers its
  /// token and keeps it current. Returns whether push is now on; never throws.
  ///
  /// [askMember] shows our own explainer before the system dialog and answers
  /// true (yes), false (not now) or null (could not be shown right now — nothing
  /// is remembered, so it is asked again next time). It is only called when the
  /// phone does not already allow notifications and it has not been asked before.
  Future<bool> enable({required Future<bool?> Function() askMember}) {
    if (_enabled) return Future.value(true);
    if (_enabling != null) {
      _trace('enable: an earlier attempt is still running, joining it');
    }
    return _enabling ??= _enable(
      askMember,
    ).whenComplete(() => _enabling = null);
  }

  Future<bool> _enable(Future<bool?> Function() askMember) async {
    final session = _session;
    bool stale() => session != _session;

    try {
      _trace('enable: reading the notification permission');
      var granted = await _client.permission() == PushPermission.granted;
      if (stale()) {
        _trace('enable: stopped, the session ended');
        return false;
      }

      final asked = _prefs.get(askedKey) == true;
      _trace('enable: allowed by the phone=$granted, explainer answered=$asked');
      if (!granted && !asked) {
        final answer = await askMember();
        _trace('enable: explainer answer=$answer (null = could not be shown)');
        if (stale() || answer == null) return false;

        await _prefs.setBool(askedKey, true);
        if (answer) {
          granted = await _client.requestPermission() == PushPermission.granted;
          _trace('enable: system dialog answered, allowed=$granted');
          if (stale()) return false;
        }
      }
      if (!granted) {
        _trace('enable: stopped, notifications are not allowed');
        return false;
      }

      _enabled = true;
      _tokenSub = _client.onTokenRefresh.listen(_register);
      final token = await _client.getToken();
      _trace('enable: getToken returned ${token == null ? 'null' : 'a token'}');
      if (token != null && !stale()) await _register(token);
      return true;
    } catch (e) {
      log('enable failed: $e', name: 'PushNotificationService');
      _trace('enable: FAILED with $e');
      return false;
    }
  }

  /// A breadcrumb on the debug console, `[PUSH] …`. Push on an iPhone can stop in
  /// silence at several points (no sign-in seen, permission already answered, the
  /// screen not ready for the explainer); this shows which one. Nothing in a
  /// release build.
  static void _trace(String message) {
    if (kDebugMode) debugPrint('[PUSH] $message');
  }

  /// Joins [broadcastTopic]. Not awaited by [_register]: offline, the real call
  /// stays pending, and the backend registration must not wait behind it.
  /// Called again for every token, so a first token that only arrives later (iOS
  /// waits for APNs) still joins; joining twice is harmless.
  Future<void> _joinBroadcastTopic() async {
    try {
      await _client.subscribeToTopic(broadcastTopic);
    } catch (e) {
      log(
        'Joining the "$broadcastTopic" topic failed: $e',
        name: 'PushNotificationService',
      );
    }
  }

  Future<void> _register(String token) async {
    // Debug only: a token is an address anyone could push to.
    if (kDebugMode) log('FCM token: $token', name: 'PushNotificationService');
    _trace('FCM token: $token');
    unawaited(_joinBroadcastTopic());
    // Remembered before the call, not after: even if the backend did not
    // answer, it may have the token, and sign-out should still ask it to forget.
    _registeredToken = token;
    try {
      await _registrar.register(token);
    } catch (e) {
      log('Registering the token failed: $e', name: 'PushNotificationService');
    }
  }

  /// Asks the backend to stop pushing to this phone. Call it **before** the
  /// session is cleared (the call is made under the member's id), then let
  /// [disable] run as the sign-out lands. Gives up after the timeout given to
  /// the constructor (5 seconds by default);
  /// never throws, so it can never keep a member from signing out.
  ///
  /// A session that ends some other way (it expired) cannot do this: the call
  /// would be refused. [disable] still deletes the phone's token, which stops
  /// the old pushes arriving; the server's leftover record just stops working.
  Future<void> unregister() async {
    final token = _registeredToken;
    if (token == null) return;
    _registeredToken = null;

    try {
      await _registrar.unregister(token).timeout(_unregisterTimeout);
    } catch (e) {
      log(
        'Unregistering the token failed: $e',
        name: 'PushNotificationService',
      );
    }
  }

  /// Switches push off at sign-out: stops listening for token changes, forgets
  /// any tap that was waiting, and deletes this phone's token so pushes meant
  /// for the member who just left stop reaching the next one. Never throws.
  Future<void> disable() async {
    _pendingTap = null;
    if (!_enabled && _enabling == null) return;

    _session++;
    _enabled = false;
    _registeredToken = null;
    // Not awaited: nothing depends on it, and the delete below must not wait.
    unawaited(_tokenSub?.cancel());
    _tokenSub = null;
    try {
      await _client.deleteToken();
    } catch (e) {
      log('deleteToken failed: $e', name: 'PushNotificationService');
    }
  }

  /// Stops listening and closes the streams. The service lives for the whole
  /// process, so only tests need this.
  @visibleForTesting
  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
    await _foreground.close();
    await _tapRequests.close();
  }
}
