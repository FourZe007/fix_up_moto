import 'package:equatable/equatable.dart';

/// A push notification as the app sees it: just the text and the extra data,
/// with nothing of Firebase's own types, so the rest of the app (and its tests)
/// never depends on the plugin.
class PushMessage extends Equatable {
  /// What the notification says. Null when the push carried only [data].
  final String? title;
  final String? body;

  /// The extra key/value pairs the sender attached (for instance the id of the
  /// notification the push is about).
  final Map<String, Object?> data;

  const PushMessage({this.title, this.body, this.data = const {}});

  /// Whether there is anything to show the member.
  bool get hasText =>
      (title?.trim().isNotEmpty ?? false) || (body?.trim().isNotEmpty ?? false);

  @override
  List<Object?> get props => [title, body, data];
}
