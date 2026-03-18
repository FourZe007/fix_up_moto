import 'package:flutter/material.dart';
import 'app.dart';
import 'core/di/injection_container.dart';

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

  // Start the widget tree. main() is done after this line —
  // all further logic is driven by the widget tree and GoRouter.
  runApp(const App());
}
