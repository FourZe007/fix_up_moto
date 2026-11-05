import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/push/push_background_handler.dart';

/// Application entry point — intentionally kept minimal.
///
/// Responsibilities:
/// 1. Ensure Flutter engine is ready before any plugin or async call.
/// 2. Register all dependencies with GetIt via [initDependencies].
/// 3. Hand control to the widget tree via [runApp].
///
/// No widgets, business logic, or routing belong here.
/// Those live in [App], [AppRouter], and the feature layers respectively.
Future<void> main() async {
  // Required before calling any plugin or using platform channels.
  // Must be the very first call in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Wire up the entire dependency graph (data sources → repos → use cases → blocs).
  // This must complete before runApp() so that sl<T>() calls inside
  // widget constructors always resolve to a registered instance.
  await initDependencies();

  // Pushes that arrive while the app is in the background or closed. After
  // initDependencies, which initialises Firebase; the handler itself is a
  // top-level function because it runs in its own isolate.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Start the widget tree. main() is done after this line —
  // all further logic is driven by the widget tree and GoRouter.
  runApp(const App());
}
