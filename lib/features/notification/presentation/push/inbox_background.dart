import 'dart:developer';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:fix_up_moto/core/network/dio_client.dart';
import 'package:fix_up_moto/core/network/network_info.dart';
import 'package:fix_up_moto/core/push/local_notifier.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:fix_up_moto/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:fix_up_moto/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fix_up_moto/features/notification/data/datasources/notification_remote_data_source.dart';
import 'package:fix_up_moto/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:fix_up_moto/features/notification/domain/usecases/get_notifications_usecase.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_alert.dart';
import 'package:fix_up_moto/features/notification/presentation/push/inbox_watcher.dart';

/// Looks at the inbox on a schedule while the app is closed, so a member hears
/// about "Service Booking Confirmed" or points credited without opening the app.
abstract interface class InboxBackgroundScheduler {
  /// Starts the periodic check. Safe to call again; the existing schedule stays.
  Future<void> schedule();

  /// Stops it (sign-out).
  Future<void> cancel();
}

/// [InboxBackgroundScheduler] over Android's WorkManager.
///
/// **Android only.** iPhone offers no dependable way to run code on a timer for
/// an app that is not open (the system decides if and when, and rarely does for
/// an app that is not used daily), so there this does nothing and the inbox is
/// checked only while the app is open.
///
/// **Not instant.** WorkManager's shortest period is 15 minutes, and the phone
/// may delay it further to save battery (Doze). That is the price of doing this
/// without a server that pushes the moment something happens.
class WorkmanagerInboxScheduler implements InboxBackgroundScheduler {
  static const String uniqueName = 'fixup_moto_inbox_check';
  static const String taskName = 'inbox_check';

  /// WorkManager will not go below this for a repeating task.
  static const Duration period = Duration(minutes: 15);

  Future<void>? _ready;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _init() =>
      _ready ??= Workmanager().initialize(inboxCallbackDispatcher);

  @override
  Future<void> schedule() async {
    if (!_supported) return;
    try {
      await _init();
      await Workmanager().registerPeriodicTask(
        uniqueName,
        taskName,
        frequency: period,
        // No point waking up offline; it would only fail.
        constraints: Constraints(networkType: NetworkType.connected),
        // Keep the existing schedule (and its place in the 15-minute cycle)
        // rather than restarting it at every sign-in.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      log('Scheduling the inbox check failed: $e', name: 'InboxBackground');
    }
  }

  @override
  Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _init();
      await Workmanager().cancelByUniqueName(uniqueName);
    } catch (e) {
      log('Cancelling the inbox check failed: $e', name: 'InboxBackground');
    }
  }
}

/// One background look: if someone is signed in and notifications are allowed,
/// read the inbox and show a notification for what is new.
///
/// Separate from the WorkManager glue below so it can be tested with fakes.
class BackgroundInboxCheck {
  final Future<String?> Function() _currentMemberId;
  final InboxWatcher _watcher;
  final LocalNotifier _notifier;

  BackgroundInboxCheck({
    required Future<String?> Function() currentMemberId,
    required InboxWatcher watcher,
    required LocalNotifier notifier,
  }) : _currentMemberId = currentMemberId,
       _watcher = watcher,
       _notifier = notifier;

  Future<void> run() async {
    // Nothing can be shown, so do not spend the member's data finding out what
    // there would have been. What waits is still new at the next look.
    if (!await _notifier.canShow()) return;

    final memberId = await _currentMemberId();
    if (memberId == null) return;

    final check = await _watcher.check(memberId);
    if (check == null || check.fresh.isEmpty) return;

    for (final alert in InboxAlert.of(check.fresh)) {
      await _notifier.show(
        key: alert.key,
        title: alert.title,
        body: alert.body,
      );
    }
    // Only after they were shown: a failure above leaves them fresh.
    await check.markSeen();
  }
}

/// Where WorkManager enters the app. A top-level function with `vm:entry-point`
/// because Android runs it in its own Dart isolate, in a process that may have
/// no running app at all — so there is no GetIt, no blocs and no Firebase here.
/// Only what an inbox look needs is built, by hand: the session lives in secure
/// storage and the SAMP backend takes the member id in the request body, so no
/// token has to be fetched.
@pragma('vm:entry-point')
void inboxCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();

      final dio = DioClient().dio;
      final authRepository = AuthRepositoryImpl(
        remoteDataSource: AuthRemoteDataSourceImpl(dio),
        localDataSource: AuthLocalDataSourceImpl(const FlutterSecureStorage()),
        networkInfo: NetworkInfoImpl(),
      );
      final notificationRepository = NotificationRepositoryImpl(
        remoteDataSource: NotificationRemoteDataSourceImpl(dio),
        networkInfo: NetworkInfoImpl(),
        authRepository: authRepository,
      );

      await BackgroundInboxCheck(
        currentMemberId: () async {
          final session = await authRepository.getCurrentUser();
          return session.fold((_) => null, (user) => user?.id);
        },
        watcher: InboxWatcher(
          getNotifications: GetNotificationsUseCase(notificationRepository),
          prefs: await SharedPreferences.getInstance(),
        ),
        notifier: FlutterLocalNotifier(),
      ).run();
    } catch (e) {
      log('Background inbox check failed: $e', name: 'InboxBackground');
    }
    // Always "done": a failed look just waits for the next period. Answering
    // false would make WorkManager retry with back-off, hammering a server that
    // may be down.
    return true;
  });
}
