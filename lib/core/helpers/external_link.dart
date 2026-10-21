import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the app: in the app that handles it (WhatsApp,
/// Instagram, TikTok…), or in the browser when none is installed. Shows
/// [failureMessage] in a SnackBar when nothing could open it.
///
/// Used for links to other apps, which an in-app web view cannot open.
Future<void> openExternalLink(
  BuildContext context,
  String url, {
  required String failureMessage,
}) async {
  // Resolved before the await, so the context is not used across the gap.
  final messenger = ScaffoldMessenger.of(context);

  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      // Hands the link to the other app (or the browser) rather than showing it
      // in an in-app web view.
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // A malformed address or no handler: reported below, same as `false`.
  }

  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}
