import 'dart:async';

import 'package:fix_up_moto/core/push/push_message.dart';
import 'package:fix_up_moto/core/push/push_messaging_client.dart';

/// A [PushMessagingClient] a test can steer: set what the phone allows, push
/// messages and token rotations through the controllers, and read how often the
/// app asked.
class FakePushMessagingClient implements PushMessagingClient {
  /// What [permission] reports right now.
  PushPermission current;

  /// What the system dialog answers when [requestPermission] is called.
  PushPermission afterRequest;

  /// What [getToken] returns; null for "no token yet".
  String? token;

  /// What [getInitialMessage] returns: the tap that started the app.
  PushMessage? initial;

  /// Makes the next call to each throw, to test that failures are contained.
  bool throwOnRequest = false;

  /// Makes [subscribeToTopic] throw, as iOS does before it has an APNs token.
  bool throwOnSubscribe = false;

  /// While set, [subscribeToTopic] does not answer until it completes: a phone
  /// that is offline leaves the real call pending.
  Completer<void>? holdSubscribe;

  int permissionRequests = 0;
  int tokenFetches = 0;
  int deletes = 0;

  /// Every topic [subscribeToTopic] was asked to join, in order.
  final List<String> subscribedTopics = [];

  final StreamController<String> tokenRefresh =
      StreamController<String>.broadcast();
  final StreamController<PushMessage> foreground =
      StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> opened =
      StreamController<PushMessage>.broadcast();

  FakePushMessagingClient({
    this.current = PushPermission.granted,
    this.afterRequest = PushPermission.granted,
    this.token = 'token-1',
    this.initial,
  });

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    if (throwOnRequest) throw StateError('permission dialog failed');
    current = afterRequest;
    return afterRequest;
  }

  @override
  Future<String?> getToken() async {
    tokenFetches++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpenedApp => opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initial;

  @override
  Future<void> subscribeToTopic(String topic) async {
    subscribedTopics.add(topic);
    if (throwOnSubscribe) throw StateError('apns-token-not-set');
    await holdSubscribe?.future;
  }

  @override
  Future<void> deleteToken() async => deletes++;
}
