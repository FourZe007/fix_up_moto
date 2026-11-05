import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:fix_up_moto/firebase_options.dart';

/// Runs when a push arrives while the app is in the background or closed.
///
/// Register it once in `main()` with `FirebaseMessaging.onBackgroundMessage`.
///
/// It must be a top-level function and carry `vm:entry-point`: Android starts a
/// separate Dart isolate for it, with none of the app's state (no GetIt, no
/// blocs), so it cannot reach anything the app built at start-up. Release
/// builds would otherwise strip it as unused.
///
/// It does nothing else on purpose. A push that carries a title and body is
/// drawn by Android/iOS themselves, with the icon and channel configured in
/// AndroidManifest.xml; the app only needs to react to the *tap*, which the
/// push service handles once the app is running.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This isolate is fresh, so Firebase is not initialised in it yet.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
